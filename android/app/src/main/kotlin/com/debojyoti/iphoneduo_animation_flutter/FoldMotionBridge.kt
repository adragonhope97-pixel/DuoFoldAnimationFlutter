package com.debojyoti.iphoneduo_animation_flutter

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import kotlin.math.atan2

/**
 * Port of FoldMotionModel.swift (elijah-semyonov/DuoLikeAnimation) — the same algorithm as
 * `FoldMotionBridge` in ios/Runner/AppDelegate.swift, fed by SensorManager instead of Core
 * Motion. The result is streamed to Dart, which only chooses between this stream and the
 * manual slider.
 *
 * Channels (identical to iOS):
 *   duo_fold/motion       method   isAvailable → Boolean,  recalibrate → null
 *   duo_fold/motion/tilt  event    Double, radians, positive = the right edge is the hinge;
 *                                  smoothed and gyro-predicted; one event per attitude
 *                                  sample (120 Hz requested) while listened to and resumed.
 *
 * Sensors: TYPE_GAME_ROTATION_VECTOR — gyroscope + accelerometer fusion with no magnetometer,
 * the Android counterpart of CMAttitudeReferenceFrame.xArbitraryZVertical — for the attitude,
 * and TYPE_GYROSCOPE (bias-compensated, like CMDeviceMotion.rotationRate) for the prediction.
 *
 * Unlike the Swift there is no matrix-handedness latch: SensorManager documents its rotation
 * matrix as device → world ("[0 0 g] = R * gravity"), row-major, so `deviceToReference` is
 * the matrix as returned. The latched reference is logged once per calibration so the
 * convention can be checked on the device (plan 008, acceptance H2).
 *
 * Everything runs on the main thread: the sensor listener is registered with the main
 * Looper's Handler, and Flutter requires EventSink / MethodChannel.Result calls there.
 */
class FoldMotionBridge(context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler, SensorEventListener {

    private companion object {
        const val TAG = "FoldMotion"

        /**
         * 1 s / 120, what the iOS bridge asks Core Motion for. Below Android 12's 200 Hz
         * cap, so HIGH_SAMPLING_RATE_SENSORS is not needed. A hint: the sensor picks the
         * nearest rate it supports.
         */
        const val SAMPLING_PERIOD_US = 8_333
    }

    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationSensor: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
    private val gyroscope: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    private val display: Display? =
        (context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager)
            .getDisplay(Display.DEFAULT_DISPLAY)
    private val mainHandler = Handler(Looper.getMainLooper())

    private val methods = MethodChannel(messenger, "duo_fold/motion")
    private val events = EventChannel(messenger, "duo_fold/motion/tilt")
    private var sink: EventChannel.EventSink? = null

    /** Dart is subscribed (between onListen and onCancel). */
    private var listening = false

    /** The Activity is between onResume and onPause. */
    private var resumed = false

    /** The sensor listeners are registered (listening && resumed && sensors present). */
    private var registered = false

    /**
     * `deviceToReference` of the calibrated zero pose: row-major 3x3, device → world.
     * Null until the first attitude sample after start or recalibrate. Survives
     * stop/start, pause/resume and a Dart hot restart, as on iOS.
     */
    private var reference: DoubleArray? = null

    /**
     * Fraction of the remaining error closed per sample. Kept high: the attitude is
     * already fused, and every extra frame of filtering is visible as lag between the
     * hand and the screen.
     */
    private val smoothing = 0.7

    /** How far ahead to extrapolate with the gyroscope, to cover sensor and display latency. */
    private val predictionInterval = 0.04
    private var motionTilt = 0.0

    /** Latest attitude, row-major 3x3, device → world (getRotationMatrixFromVector). */
    private val current = FloatArray(9)

    /** Latest calibrated rotation rate, device frame, rad/s, right-hand rule. */
    private val rate = DoubleArray(3)

    /** Screen-space X (right) and Y (up) axes of the interface, in device coordinates. */
    private class Axes(val x: DoubleArray, val y: DoubleArray)

    private val portrait =
        Axes(doubleArrayOf(1.0, 0.0, 0.0), doubleArrayOf(0.0, 1.0, 0.0))
    private val portraitUpsideDown =
        Axes(doubleArrayOf(-1.0, 0.0, 0.0), doubleArrayOf(0.0, -1.0, 0.0))

    /** ROTATION_90: device turned counter-clockwise, its bottom edge at the user's right. */
    private val landscapeRight =
        Axes(doubleArrayOf(0.0, -1.0, 0.0), doubleArrayOf(1.0, 0.0, 0.0))

    /** ROTATION_270: device turned clockwise, its bottom edge at the user's left. */
    private val landscapeLeft =
        Axes(doubleArrayOf(0.0, 1.0, 0.0), doubleArrayOf(-1.0, 0.0, 0.0))

    private val isAvailable: Boolean
        get() = rotationSensor != null && gyroscope != null

    init {
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(isAvailable)
                "recalibrate" -> {
                    recalibrate()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ---- EventChannel.StreamHandler ---------------------------------------------------

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        listening = true
        updateRegistration()
    }

    override fun onCancel(arguments: Any?) {
        listening = false
        updateRegistration()
        sink = null
    }

    // ---- Activity lifecycle, forwarded by MainActivity ---------------------------------

    fun onResume() {
        resumed = true
        updateRegistration()
    }

    fun onPause() {
        resumed = false
        updateRegistration()
    }

    fun onDestroy() {
        listening = false
        resumed = false
        updateRegistration()
        sink = null
        events.setStreamHandler(null)
        methods.setMethodCallHandler(null)
    }

    // ---- FoldMotionModel (verbatim logic) ---------------------------------------------

    private fun updateRegistration() {
        val rotation = rotationSensor ?: return
        val gyro = gyroscope ?: return
        val wanted = listening && resumed
        if (wanted == registered) return
        registered = wanted
        if (wanted) {
            sensorManager.registerListener(this, rotation, SAMPLING_PERIOD_US, mainHandler)
            sensorManager.registerListener(this, gyro, SAMPLING_PERIOD_US, mainHandler)
        } else {
            sensorManager.unregisterListener(this)
        }
    }

    /** Makes the current pose the zero-tilt pose: the plane the UI stays in. */
    private fun recalibrate() {
        reference = null
        motionTilt = 0.0
        sink?.success(0.0)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_GYROSCOPE -> {
                rate[0] = event.values[0].toDouble()
                rate[1] = event.values[1].toDouble()
                rate[2] = event.values[2].toDouble()
            }
            Sensor.TYPE_GAME_ROTATION_VECTOR -> {
                SensorManager.getRotationMatrixFromVector(current, event.values)
                process()
            }
        }
    }

    private fun process() {
        val ref = reference
        if (ref == null) {
            val latched = DoubleArray(9) { current[it].toDouble() }
            reference = latched
            Log.i(
                TAG,
                "reference latched: rotation=${displayRotation()} R=[" +
                    latched.joinToString(" ") { "%.2f".format(Locale.US, it) } + "]",
            )
            return
        }

        // Current screen normal (device +Z) in world coordinates: column 2 of `current`.
        val nx = current[2].toDouble()
        val ny = current[5].toDouble()
        val nz = current[8].toDouble()
        // The same normal in the calibrated device frame: column 2 of relative = refᵀ · current.
        val normalX = ref[0] * nx + ref[3] * ny + ref[6] * nz
        val normalY = ref[1] * nx + ref[4] * ny + ref[7] * nz
        val normalZ = ref[2] * nx + ref[5] * ny + ref[8] * nz

        val axes = screenAxesInDeviceSpace()
        val measured = atan2(
            normalX * axes.x[0] + normalY * axes.x[1] + normalZ * axes.x[2],
            normalZ,
        )

        // Extrapolate along the rotation rate around the screen's Y axis.
        val rateAboutScreenY = rate[0] * axes.y[0] + rate[1] * axes.y[1] + rate[2] * axes.y[2]
        val predicted = measured + rateAboutScreenY * predictionInterval

        motionTilt += (predicted - motionTilt) * smoothing
        sink?.success(motionTilt)
    }

    private fun displayRotation(): Int = display?.rotation ?: Surface.ROTATION_0

    private fun screenAxesInDeviceSpace(): Axes = when (displayRotation()) {
        Surface.ROTATION_90 -> landscapeRight
        Surface.ROTATION_180 -> portraitUpsideDown
        Surface.ROTATION_270 -> landscapeLeft
        else -> portrait
    }
}
