# 008 android-motion

## Goal

The Android build behaves exactly as the iOS build: `MainActivity` hosts a `FoldMotionBridge` that answers `duo_fold/motion` (`isAvailable`, `recalibrate`) and streams θ on `duo_fold/motion/tilt` in the same sign convention, with the same reference-pose latch, smoothing 0.7, prediction 0.04 s, ~120 Hz request, hot-restart survival and Recalibrate-emits-0.0 behaviour, fed by `TYPE_GAME_ROTATION_VECTOR` + `TYPE_GYROSCOPE` instead of Core Motion. The Flutter view is edge-to-edge under transparent system bars so the sampled area is the whole screen, the window is pinned to the light appearance, and the launcher label reads `DuoLikeAnimation`. Nothing in `shaders/`, `lib/fold/`, `lib/motion/` or `ios/` changes; `lib/main.dart` gains only the system-UI setup. `flutter analyze` is clean, `dart format --set-exit-if-changed` exits 0, `flutter test` passes, `flutter build ios --debug --no-codesign` still succeeds and `flutter build apk --debug` succeeds (compiling the Kotlin and the GLES/Vulkan shader stages).

## Decisions

1. **Bridge lives in the Activity, registered in `configureFlutterEngine`.** `FlutterActivity.configureFlutterEngine` runs once per engine attach, before the first Dart frame, on the main thread; the bridge outlives Dart hot restarts (Android `EventChannel` calls `onCancel` then `onListen` on a repeated listen — verified in `EventChannel.java`), so `reference` persists across a hot restart exactly as on iOS. No plugin, no package.
2. **Sensors: `TYPE_GAME_ROTATION_VECTOR` for attitude, `TYPE_GYROSCOPE` for the rate.** Game rotation vector is gyro+accelerometer fusion with no magnetometer — the documented Android counterpart of `.xArbitraryZVertical` (Z up, X/Y arbitrary). `TYPE_GYROSCOPE` is bias-compensated, like `CMDeviceMotion.rotationRate`; `TYPE_GYROSCOPE_UNCALIBRATED` is not used.
3. **No fallback fusion. `isAvailable = (GRV != null && gyroscope != null)`.** `TYPE_ROTATION_VECTOR` is rejected for the reason the Swift gives (magnetometer yaw correction adds latency on exactly the axis we track); a hand-rolled gyro+accel filter would be a new algorithm, not a port. A device with no gyroscope has no game rotation vector and no `isDeviceMotionAvailable` on iOS either — both fall to the manual slider. Emulators expose virtual sensors and will report available (static θ ≈ 0); use Manual tilt there.
4. **Sampling period `8_333` µs (120 Hz), no batching, no `HIGH_SAMPLING_RATE_SENSORS`.** Android 12+ only needs that permission above 200 Hz; 120 Hz is a hint and the sensor picks its nearest supported rate (100–200 Hz in practice). The 0.7-per-sample filter settles in 3 samples regardless: 25 ms at 120 Hz, 15 ms at 200 Hz — accepted, not compensated.
5. **The empirical handedness latch is replaced by the documented Android convention.** `SensorManager.getRotationMatrix`'s contract is normative and open-source: "R is the identity matrix when the device is aligned with the world's coordinate system … [0 0 g] = R · gravity", i.e. `R` maps device-frame vectors to world-frame vectors, row-major. `getRotationMatrixFromVector` fills `R` with the standard active rotation `R(q)` (source quoted in `## Math`), same convention. The Swift latch exists because `CMRotationMatrix`'s docs are ambiguous; Android's are not, and keeping the latch would need a second (gravity) listener for nothing. The sign is still proven on the device: the bridge logs the latched reference matrix once per calibration, and H2 checks the off-diagonal element that distinguishes `R` from `Rᵀ`.
6. **Screen axes from `Display.getRotation()` per sample**, mirroring the Swift's per-sample `interfaceOrientation` read. The `Display` is fetched once via `DisplayManager.getDisplay(DEFAULT_DISPLAY)` (API 17+, not deprecated). Android's sensor frame is defined by the *natural* screen orientation, and `Display.rotation` is measured from the same natural orientation, so the table holds for landscape-natural tablets too; only phones are judged in acceptance.
7. **Main thread everywhere.** Both sensors are registered with `Handler(Looper.getMainLooper())`, so `onSensorChanged` runs on the platform thread, where Flutter requires `EventSink`/`MethodChannel.Result` calls. The per-sample work is nine multiplies and an `atan2`; this is the same thread Core Motion delivers to (`to: .main`).
8. **One emit per attitude sample.** Gyro samples only update the cached `rate`; the rotation-vector callback computes and emits, as `process(_:)` does per `CMDeviceMotion`.
9. **Lifecycle: sensors run only while `listening && resumed`.** iOS stops delivering Core Motion in the background implicitly; Android does not, so `onPause` unregisters and `onResume` re-registers. `reference` and `motionTilt` are kept, matching 003's M6 ("leave the app, come back: still follows the hand"). `onDestroy` unregisters and detaches both channels.
10. **`recalibrate` clears `reference`, zeroes `motionTilt`, emits `0.0` immediately** — identical to the iOS bridge (003 decision 5).
11. **Edge-to-edge and transparent bars from Dart, unconditionally.** targetSdk 36 makes Android 15+ edge-to-edge already; on Android ≤ 14 the template theme insets the Flutter view under an opaque status bar and a black navigation bar (and `SystemUiOverlayStyle.dark`, currently used, sets `systemNavigationBarColor = 0xFF000000`). `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` + a transparent-bars `SystemUiOverlayStyle` make the sampled area the whole screen on every version. On iOS `edgeToEdge` only sets `prefersStatusBarHidden = false` (verified in `FlutterPlatformPlugin.mm`), i.e. no change; Flutter ignores the bar colours on API ≥ 35 and on iOS. No platform gating in Dart.
12. **Light pin: delete `values-night/styles.xml`.** It only changes the window background (and the `drawable-v21` launch colour) to black in dark mode; the iOS runner is `UIUserInterfaceStyle = Light`. `MaterialApp` has no `darkTheme`, so Dart is already pinned.
13. **No display-mode forcing.** `CADisableMinimumFrameDurationOnPhone` lifts an iOS-only 60 Hz cap on third-party apps; Android has no such cap — Flutter's `VsyncWaiter` follows whatever refresh rate the OEM's policy grants. `preferredDisplayModeId` would override the user's battery setting, which the iOS key does not do.
14. **App label `DuoLikeAnimation`** in the manifest, matching `CFBundleDisplayName`.
15. **Fractional-dpr resample is accepted as a documented deviation.** `AnimatedSampler` allocates `ceil(dpr·W)` texels, and on Android `W = physicalW/dpr`, so `dpr·W` is integral up to one ulp; the stretch is < 1 texel at the far edge and 0 at the origin (`## Math` §8). Not fixed; `context.md` already forbids dividing by the texture size.
16. **Shader and `fold_effect.dart` untouched.** `FlutterFragCoord()` is backend-correct in 3.47 (no GLES flip), `precision highp float` is declared, the loop bound is constant, `texture()` is used; `FilterQuality.low` maps to linear sampling on Vulkan and GLES. `flutter build apk --debug` is the compile proof for the `gles`/`gles3`/`vulkan` runtime stages; H1 is the on-screen proof.
17. **README's platform table is a real edit in this phase** (it is documentation of shipped behaviour); the `context.md` hunks are proposed only, per the two-agent rule.

### Proposed `context.md` hunks (main session routes; do not apply here)

    - | `CMMotionManager` attitude | `FoldMotionModel.swift` ported verbatim into `ios/Runner/AppDelegate.swift` (`FoldMotionBridge`), streamed over `EventChannel` `duo_fold/motion/tilt`; `MethodChannel` `duo_fold/motion` for `isAvailable`/`recalibrate`. Dart `FoldMotionModel` only switches between the stream and the slider. iOS only; chosen in 003 for exact fidelity. |
    + | `CMMotionManager` attitude | `FoldMotionModel.swift` ported verbatim into `ios/Runner/AppDelegate.swift` (`FoldMotionBridge`, 003) and into `android/.../FoldMotionBridge.kt` (008, `TYPE_GAME_ROTATION_VECTOR` + `TYPE_GYROSCOPE`), both streaming over `EventChannel` `duo_fold/motion/tilt`; `MethodChannel` `duo_fold/motion` for `isAvailable`/`recalibrate`. Dart `FoldMotionModel` only switches between the stream and the slider and has no platform gating. |

    - # No sensor package: motion is the original Swift in ios/Runner (003).
    + # No sensor package: motion is the original Swift in ios/Runner (003) and
    + # its Kotlin twin in android/app (008).

    - ios/Runner/AppDelegate.swift # FoldMotionBridge: FoldMotionModel.swift verbatim + channels
    + ios/Runner/AppDelegate.swift # FoldMotionBridge: FoldMotionModel.swift verbatim + channels
    + android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/
    +   MainActivity.kt            # hosts the bridge; forwards onResume/onPause/onDestroy
    +   FoldMotionBridge.kt        # same algorithm on SensorManager; no handedness latch (008)

    + - Android (008): `SensorManager.getRotationMatrixFromVector` returns device→world,
    +   row-major, by documented contract (`[0 0 g] = R · gravity`), so there is no
    +   handedness latch; `deviceToReference = R` directly. The bridge logs the
    +   latched reference matrix once per calibration (`FoldMotion: reference
    +   latched …`); upright portrait must show `r7 ≈ 1, |r5| small`. Sensors are
    +   unregistered in `onPause` and re-registered in `onResume`; `reference`
    +   survives both and a hot restart, so Recalibrate after either if the pose
    +   moved.
    + - Android logical sizes are fractional (e.g. 411.43 × 914.29 @ 2.625) but
    +   `dpr·W` is the physical width to one ulp, so `ceil(dpr·W) − dpr·W < 1`
    +   texel: the bilinear identity deviation is < 1 physical px at the far edge.
    +   Accepted; do not "fix".
    + - The Flutter view is edge-to-edge with transparent bars on Android
    +   (`SystemUiMode.edgeToEdge` + `kSystemUiOverlayStyle` in `main.dart`) so the
    +   sampled area is the whole screen, as on iOS. `SystemUiOverlayStyle.dark`
    +   would paint the navigation bar opaque black — do not reintroduce it.
    + - `flutter build apk --debug` is the compile proof for the GLES/Vulkan
    +   runtime stages of the shader; run it whenever the GLSL changes.

## Files

### 1. `android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/FoldMotionBridge.kt` — new

```kotlin
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
```

### 2. `android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/MainActivity.kt` — full replacement

```kotlin
package com.debojyoti.iphoneduo_animation_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts [FoldMotionBridge]. The bridge lives in the Activity, not in Dart, so the calibrated
 * reference pose survives a Dart hot restart, and the sensors stop while the Activity is
 * paused (Android, unlike Core Motion, keeps delivering in the background otherwise).
 */
class MainActivity : FlutterActivity() {
    private var motionBridge: FoldMotionBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        motionBridge = FoldMotionBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onResume() {
        super.onResume()
        motionBridge?.onResume()
    }

    override fun onPause() {
        motionBridge?.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        motionBridge?.onDestroy()
        motionBridge = null
        super.onDestroy()
    }
}
```

### 3. `android/app/src/main/AndroidManifest.xml` — edit

Before:
```xml
    <application
        android:label="iphoneduo_animation_flutter"
```
After:
```xml
    <application
        android:label="DuoLikeAnimation"
```
Nothing else in the manifest changes. No `<uses-permission>` is added (120 Hz is under the 200 Hz cap).

### 4. `android/app/src/main/res/values-night/styles.xml` — delete

`git rm android/app/src/main/res/values-night/styles.xml`. `@style/LaunchTheme` and `@style/NormalTheme` then resolve from `values/styles.xml` (`Theme.Light.NoTitleBar`) in every appearance, and `drawable-v21/launch_background.xml`'s `?android:colorBackground` becomes light in dark mode too. The directory is removed with the file.

### 5. `lib/main.dart` — three hunks

Hunk A (imports):

Before:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
```
After:
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
```

Hunk B (`main()` and a new top-level constant):

Before:
```dart
/// The `MANUAL_TILT` dart-define; false when absent.
bool launchManualTilt() => _manualTiltDefine;

void main() {
  runApp(const FoldApp());
}
```
After:
```dart
/// The `MANUAL_TILT` dart-define; false when absent.
bool launchManualTilt() => _manualTiltDefine;

/// Dark glyphs over the light page, and transparent bars on Android so the
/// Flutter view — and with it the area the shader samples — is the whole
/// screen, as the iOS window is under the status bar and home indicator.
/// `SystemUiOverlayStyle.dark` would paint the Android navigation bar opaque
/// black (its `systemNavigationBarColor` is `0xFF000000`). On iOS only
/// `statusBarBrightness` applies, and it is what `.dark` set there too.
const SystemUiOverlayStyle kSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw under the status and navigation bars so the sampled area is the
  // whole screen on every Android version (15+ enforces this; older versions
  // inset the view by default). On iOS this only re-asserts the visible
  // status bar and home indicator.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  runApp(const FoldApp());
}
```

Hunk C (`FoldScreen.build`):

Before:
```dart
    // Dark status-bar glyphs over the light demo content. `.dark` names the
    // icon brightness, not the background's.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
```
After:
```dart
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOverlayStyle,
```

### 6. `README.md` — four hunks

Hunk A (How it works table):

Before:
```
| Device attitude | `CMMotionManager` | Same Core Motion model, ported to Swift in the iOS runner and streamed over an `EventChannel` |
```
After:
```
| Device attitude | `CMMotionManager` | Same motion model, ported to Swift in the iOS runner and to Kotlin in the Android runner (`TYPE_GAME_ROTATION_VECTOR` + gyroscope), both streamed over the same `EventChannel` |
```

Hunk B (Layout):

Before:
```
ios/Runner/AppDelegate.swift FoldMotionBridge (Core Motion → EventChannel)
```
After:
```
ios/Runner/AppDelegate.swift FoldMotionBridge (Core Motion → EventChannel)
android/app/src/main/kotlin/…/FoldMotionBridge.kt
                             FoldMotionBridge (SensorManager → EventChannel)
```

Hunk C (Running it):

Before:
```
flutter pub get
flutter run -d <your-iphone>
```

Run it on a physical iPhone: the effect is driven by the device's attitude,
which the simulator cannot provide. The floating panel at the bottom has:
```
After:
```
flutter pub get
flutter run -d <your-iphone-or-android-phone>
```

Run it on a physical phone: the effect is driven by the device's attitude,
which the simulator and emulator cannot provide. The floating panel at the
bottom has:
```

Hunk D (Platform support):

Before:
```
| iOS | ✅ | ✅ Core Motion |
| Android | ✅ Impeller | ⏳ manual slider only — sensor bridge not yet written |
| macOS | ✅ | manual slider only (no attitude sensor) |

The shader itself has no platform-specific code; only the tilt source does.
Adding Android motion means a `SensorManager` rotation-vector bridge on the
same `duo_fold/motion/tilt` event channel — contributions welcome.
```
After:
```
| iOS | ✅ | ✅ Core Motion (`ios/Runner/AppDelegate.swift`) |
| Android | ✅ Impeller (Vulkan, GLES fallback) | ✅ `TYPE_GAME_ROTATION_VECTOR` + `TYPE_GYROSCOPE` (`android/app/src/main/kotlin/…/FoldMotionBridge.kt`); falls back to the slider on devices without a gyroscope |
| macOS | ✅ | manual slider only (no attitude sensor) |

The shader and the Dart code have no platform-specific paths; the two native
bridges implement the same `duo_fold/motion` channels with the same model
(reference pose latched on the first sample, 0.7 smoothing, 40 ms gyro
prediction, θ > 0 ⇔ right edge is the hinge).
```

## Math

Variable names are those of `FoldMotionBridge.kt`.

1. **Frames.** Device frame (Android sensor frame = iOS device frame): X right, Y up, Z out of the screen toward the viewer, all in the device's *natural* orientation. World frame of `TYPE_GAME_ROTATION_VECTOR`: Z up (opposite gravity), X/Y arbitrary but fixed — the same freedom `.xArbitraryZVertical` has. θ's convention (context.md, unchanged): θ > 0 ⇒ right edge is the hinge, left edge lifts toward the viewer.

2. **`getRotationMatrixFromVector` returns device → world.** With the rotation vector `(q1, q2, q3, q0)` = `(x, y, z, w)`, the AOSP source fills the 9-array as
   ```
   R[0] = 1 − 2(q2² + q3²)   R[1] = 2(q1q2 − q3q0)    R[2] = 2(q1q3 + q2q0)
   R[3] = 2(q1q2 + q3q0)     R[4] = 1 − 2(q1² + q3²)  R[5] = 2(q2q3 − q1q0)
   R[6] = 2(q1q3 − q2q0)     R[7] = 2(q2q3 + q1q0)    R[8] = 1 − 2(q1² + q2²)
   ```
   which is the active rotation `R(q)`; the rotation vector is "the rotation the device has undergone" from world alignment, so the columns of `R` are the device axes in world coordinates and `R · v_device = v_world` (row-major, `R[3·i + j]` = row i, column j). This is the same contract `getRotationMatrix` states as `[0 0 g] = R · gravity`. Hence `deviceToReference = R` with no transpose and no latch. The Swift's `rowsAreDeviceAxes` branch ends in the same object (a device → Z-up-world matrix); the world's X/Y heading differs between platforms and cancels in step 3.

3. **Relative rotation and θ** (identical to the Swift): `reference = R_ref`, `current = R_cur`,
   `relative = R_refᵀ · R_cur` maps current-device vectors into the calibrated-device frame.
   `normal = relative · (0,0,1) = R_refᵀ · (R_cur column 2) = R_refᵀ · (R[2], R[5], R[8])`, computed as
   `normalX = ref[0]·nx + ref[3]·ny + ref[6]·nz`, `normalY = ref[1]·nx + ref[4]·ny + ref[7]·nz`, `normalZ = ref[2]·nx + ref[5]·ny + ref[8]·nz` (the transpose is the `ref[3·j + i]` indexing).
   `measured = atan2(normal · screenX, normalZ)`.

4. **Sign proof.** A rotation by +φ about the device up-axis (right-hand rule) sends the normal `(0,0,1) → (sin φ, 0, cos φ)`, so `measured = atan2(sin φ, cos φ) = φ`, and sends the left edge `(−1,0,0) → (−cos φ, 0, +sin φ)`: z > 0, i.e. the left edge moves **toward** the viewer while the right edge moves away. So φ > 0 ⇔ left edge lifts ⇔ right edge is the hinge ⇔ θ > 0 ⇔ shader `xh = uSize.x`. Same as 003 review §A. Physically: turning the phone so its **left edge comes toward your face** must make θ positive (H3).

5. **Gyroscope.** `TYPE_GYROSCOPE` is device-frame angular velocity in rad/s, "positive in the counter-clockwise direction" viewed from the positive end of each axis — the right-hand rule, identical to `CMRotationRate`; both are bias-compensated. `rateAboutScreenY = rate · screenY = dφ/dt` for the rotation in step 4, so `predicted = measured + rateAboutScreenY · 0.04` extrapolates in the same direction. `motionTilt += (predicted − motionTilt) · 0.7`.

6. **Screen axes by `Display.rotation`.** `ROTATION_n` is the rotation of the *drawn graphics*, opposite to the physical turn: a device turned 90° counter-clockwise reports `ROTATION_90`. The user's screen-right and screen-up in device (natural) coordinates:

   | `Display.rotation` | physical turn | screenX | screenY | Swift case |
   |---|---|---|---|---|
   | `ROTATION_0` | none | (1, 0, 0) | (0, 1, 0) | `.portrait` |
   | `ROTATION_90` | 90° CCW, bottom edge at user's right | (0, −1, 0) | (1, 0, 0) | `.landscapeRight` |
   | `ROTATION_180` | 180° | (−1, 0, 0) | (0, −1, 0) | `.portraitUpsideDown` |
   | `ROTATION_270` | 90° CW, bottom edge at user's left | (0, 1, 0) | (−1, 0, 0) | `.landscapeLeft` |

   Landscape-natural tablets: both the sensor frame and `Display.rotation` are relative to the natural orientation, so the same table applies; not judged this phase.

7. **Convention check on device (H2).** For `R` device → world, world-Z component of the device-Y axis is `R[7]` (row 2, column 1); for the transposed convention it would be `R[5]`. Holding the phone upright in portrait (device +Y up) at calibration therefore logs `r7 ≈ +1.00, |r5| ≤ 0.2`; the transposed convention would log the reverse. Flat face-up logs `r8 ≈ +1.00` under either, so the check must be done upright.

8. **Fractional dpr bound.** `AnimatedSampler` allocates `T = ceil(dpr·W)` texels; the shader maps `uv = q/uSize`, so physical column i lands on texel `i·T/(dpr·W) = i·(1 + ε)` with `ε = (T − dpr·W)/(dpr·W)`. On Android `W = physicalW/dpr`, so `dpr·W = physicalW` to one ulp and `T − dpr·W ∈ {0, 1}` ⇒ `ε ≤ 1/physicalW ≤ 1/1080`; the resample offset `i·ε < 1` texel everywhere, 0 at the left edge. Sub-pixel, monotone, invisible under the blur; accepted.

9. **Sampling.** Request `SAMPLING_PERIOD_US = 8_333` (= 1e6/120). Android 12+ caps `SensorEventListener` delivery at 200 Hz without `HIGH_SAMPLING_RATE_SENSORS`; 120 Hz is under the cap, so no permission and no manifest entry. Emission rate to Dart = the GRV sensor's actual rate.

## Commands

From the repository root, in order:

```
git rm android/app/src/main/res/values-night/styles.xml
dart format lib test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
flutter build ios --debug --no-codesign
flutter build apk --debug
unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep -c 'flutter_assets/shaders/duo_fold.frag'
unzip -p build/app/outputs/flutter-apk/app-debug.apk 'classes*.dex' | strings | grep -c 'duo_fold/motion'
aapt dump badging build/app/outputs/flutter-apk/app-debug.apk 2>/dev/null | grep "application-label:" || unzip -p build/app/outputs/flutter-apk/app-debug.apk AndroidManifest.xml | strings | grep -c DuoLikeAnimation
```

The implementer may not touch `shaders/`, `ios/`, `pubspec.yaml`, `pubspec.lock`, `test/`, or anything under `lib/` other than `lib/main.dart` (hunks A–C only). No `flutter run`, no `flutter pub add`. `flutter build apk --debug` may take several minutes on first run (Gradle downloads); do not change `android/settings.gradle.kts`, `android/gradle.properties` or `android/app/build.gradle.kts` to make it faster.

Then a human runs `flutter devices`, then `flutter run -d <android-serial>` on a physical Android phone with a gyroscope, and separately `flutter run -d 00008120-000278980AE3601E` on the iPhone for the side-by-side items, working `## Acceptance`. For H2, run `adb logcat -s FoldMotion` in a second terminal.

## Acceptance

Automated:

- A1. `flutter analyze` prints `No issues found!`.
- A2. `dart format --output=none --set-exit-if-changed lib test` exits 0.
- A3. `flutter test` passes with the same test count as at HEAD (no test file changed).
- A4. `flutter build ios --debug --no-codesign` succeeds (regression: `main.dart` hunks compile and change nothing on iOS).
- A5. `flutter build apk --debug` ends with `✓ Built build/app/outputs/flutter-apk/app-debug.apk`; no `impellerc` error lines (this is the GLES/GLES3/Vulkan compile proof for `duo_fold.frag`), no Kotlin compile warnings about unresolved references.
- A6. The `grep -c` for `flutter_assets/shaders/duo_fold.frag` prints `1`; the `grep -c 'duo_fold/motion'` prints ≥ 2 (both channel names are in the dex); the label check prints `application-label:'DuoLikeAnimation'` or `1`.
- A7. `git status --short` shows exactly: `M android/app/src/main/AndroidManifest.xml`, `M android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/MainActivity.kt`, `?? android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/FoldMotionBridge.kt`, `D android/app/src/main/res/values-night/styles.xml`, `M lib/main.dart`, `M README.md`, `?? docs/plans/008-android-motion.md` (plus `M` once the report is appended). Nothing under `shaders/`, `ios/`, `lib/fold/`, `lib/motion/`, `lib/demo/`, `test/`.
- A8. `git diff lib/main.dart` contains no `Platform.`, `defaultTargetPlatform` or `kIsWeb` — no platform gating in Dart.

On the Android device (record PASS/FAIL per line in `## Review`):

```
H0  flutter run -d <android-serial>. The launcher icon is labelled
    "DuoLikeAnimation". First frame: the white portfolio page fills the
    screen edge to edge — the page is visible behind the status-bar glyphs
    (dark glyphs) and behind the gesture/navigation bar, with no opaque
    black band at the bottom and no black band at the top. Panel readout
    near 0.0°, "Manual tilt" OFF, Recalibrate enabled, slider greyed.
    (On an emulator the switch may also be OFF with θ pinned at 0.0°: the
    virtual sensors are static. Use Manual tilt there; judge nothing else.)

H1  [Impeller provenance, 002 item 0 / 003 H1]  Drag the slider at Manual
    tilt ON to −20 and back to 0, then OFF: at 0° the page is undistorted,
    not shrunk into a corner, not mirrored, not upside down; at −20° black
    wedges appear at the top-RIGHT and bottom-RIGHT corners with the left
    border unchanged. FAIL = the effect appears at the wrong scale, flipped
    vertically, or with the wedges on the wrong side. If FAIL, stop and
    report the device model, Android version and whether `flutter run`
    printed "Using the Impeller rendering backend (Vulkan)" or "(OpenGLES)".

H2  [convention proof]  With `adb logcat -s FoldMotion` open, hold the
    phone UPRIGHT in portrait, screen facing you, and tap Recalibrate. One
    line "FoldMotion: reference latched: rotation=0 R=[r0 … r8]" appears.
    PASS = r7 ≥ 0.9 and |r5| ≤ 0.2 (and r8 ≈ 0). FAIL = r5 ≥ 0.9 with
    |r7| ≤ 0.2: that is the transposed convention — report it; the fix is
    a plan revision (transpose in `process`), not an ad-hoc edit.
    Then lay the phone flat face-up and tap Recalibrate: r8 ≥ 0.9.

H3  [sign, at rest]  Hold upright, tap Recalibrate. Slowly turn the phone
    about its vertical axis so the LEFT edge comes toward your face (right
    edge moves away) and hold still: readout POSITIVE; the right border and
    the content along the right edge stay put; black wedges grow at the
    top-LEFT and bottom-LEFT corners and the left half is blurred and
    dimmed. Turn the RIGHT edge toward you: readout NEGATIVE, wedges at the
    right. Compare with the iPhone held the same way: same side, same
    readout sign, similar magnitude.

H4  [tracking]  Rock the phone gently ±20°: the picture follows the hand
    with no visible lag and no jitter when you hold still. Hold at ~20°:
    wedges ≈ 30 lpx tall at the lifted edge; at 45° ≈ 60 lpx. Readout
    update is visibly continuous (not stepping at a few Hz).

H5  [recalibrate]  Hold tilted ~20°, tap Recalibrate: readout snaps to
    0.0° and the picture flattens; turn back to upright: readout ≈ −20°.

H6  [manual switch]  Toggle "Manual tilt" ON: slider enabled, Recalibrate
    greyed; slider to −20: readout −20.0°, wedges at the right. Toggle OFF:
    motion resumes immediately from the live pose.

H7  [stability]  Hold still 10 s at ~15°: readout drifts < 0.5°.

H8  [pause/resume]  Press Home, wait 5 s, return: the effect follows the
    hand again within one frame; `adb logcat -s FoldMotion` shows no new
    "reference latched" line (the pose was kept). Rotate the phone ~20°
    while on the home screen, return: readout reflects the new pose.

H9  [cold relaunch in a different attitude]  Kill the app. Lay the phone
    flat on a desk, launch it, pick it up to upright: the readout is a
    large angle and atan2 may sit near ±90° (the known flat-calibration
    degeneracy) — tap Recalibrate upright and repeat H3. The sign must be
    the same as in H3. Kill again, launch holding it in landscape, tap
    Recalibrate, tilt about the now-vertical axis: same sign rule (the
    edge that comes toward you lifts).

H10 [hot restart]  Press `R` in the flutter run console. After the
    restart the stream resumes (readout moves), no MissingPluginException,
    no "Failed to open event stream" in logcat. Tap Recalibrate; H3 holds.

H11 [rendering parity]  Side by side with the iPhone at the same manual
    tilt of −20°: same wedge geometry, same blur growth toward the lifted
    edge, same dimming, no seam or offset band at the interface border
    (the < 1 px fractional-dpr stretch of Math §8 must not be visible).

H12 Console/logcat: no exception, no RangeError, no impellerc line, no
    MissingPluginException, no "Sensor … not found", no ANR.
```

## Out of scope

- `shaders/duo_fold.frag`, `lib/fold/**`, `lib/motion/**`, `lib/demo/**`, `test/**`, the uniform table. No uniform is added, no test is changed.
- `ios/**` and `macos/**`. The iOS bridge keeps its handedness latch; it is not "aligned" with the Android decision.
- `pubspec.yaml`, `pubspec.lock`, `android/settings.gradle.kts`, `android/gradle.properties`, `android/app/build.gradle.kts` (SDK levels, AGP/Kotlin versions, signing). `minSdk` stays `flutter.minSdkVersion` (24).
- `context.md` and `CLAUDE.md`. The hunks in `## Decisions` are for the main session to route.
- A `TYPE_ROTATION_VECTOR` or accelerometer+gyro fallback for devices without `TYPE_GAME_ROTATION_VECTOR` (decision 3).
- `HIGH_SAMPLING_RATE_SENSORS`, `<uses-feature android.hardware.sensor.gyroscope>`, batching/`maxReportLatencyUs`.
- Forcing a display mode or frame rate (`preferredDisplayModeId`, `Surface.setFrameRate`) (decision 13).
- `windowLayoutInDisplayCutoutMode` overrides, a `values-v28`/`values-v35` styles split, or an AppCompat theme. Android 15+ handles the cutout under enforced edge-to-edge; older versions get Flutter's own edge-to-edge handling.
- Landscape and tablet acceptance (the axis table is ported and reasoned; only portrait on a phone is judged), Android emulator acceptance, background sensor use, multi-window/foldable posture changes.
- Any change to the iOS `Info.plist`, launch screen, or icon; Android launcher icon artwork.
- Committing or pushing.

## Implementation report
STATUS: DONE
Files written:
- android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/FoldMotionBridge.kt (new, verbatim from plan)

Files edited:
- android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/MainActivity.kt — full replacement per plan, hosts `FoldMotionBridge` and forwards `onResume`/`onPause`/`onDestroy`.
- android/app/src/main/AndroidManifest.xml — `android:label` changed to `DuoLikeAnimation`.
- android/app/src/main/res/values-night/styles.xml — deleted via `git rm` (light-appearance pin).
- lib/main.dart — three hunks: `dart:async` import, `kSystemUiOverlayStyle` constant + edge-to-edge `SystemChrome` call in `main()`, and `FoldScreen.build` now uses `kSystemUiOverlayStyle` instead of `SystemUiOverlayStyle.dark`.
- README.md — four hunks: How-it-works table, Layout tree, Running-it instructions, Platform-support table.

Deviations from plan: none.

Self-fixes applied: none (no compile/analyzer errors; the transient "unused import" warning after hunk A alone was expected and resolved by hunk B in the same edit sequence).

Command results:
  flutter analyze — clean (`No issues found!`)
  dart format --output=none --set-exit-if-changed lib test — exit 0
  flutter test — all tests passed (20 tests; no test file touched)
  flutter build ios --debug --no-codesign — ok (`✓ Built build/ios/iphoneos/Runner.app`)
  flutter build apk --debug — ok (`✓ Built build/app/outputs/flutter-apk/app-debug.apk`), no impellerc error lines, no Kotlin warnings
  unzip -l … grep -c 'flutter_assets/shaders/duo_fold.frag' — 1
  unzip -p 'classes*.dex' | strings | grep -c 'duo_fold/motion' — the exact piped form intermittently returned no output in this sandboxed shell (a pipe/SIGPIPE quirk, not a build issue); redirecting the same unzip output to a file first and then piping through `strings | grep -c` gives 2, matching acceptance (A6 requires ≥ 2). Verified per-dex: the two channel-name strings (`duo_fold/motion`, `duo_fold/motion/tilt`) both live in `classes4.dex`.
  label check — `aapt` is not installed in this environment, so the `aapt dump badging` branch fails and the shell falls through to the `unzip | strings | grep -c DuoLikeAnimation` fallback; that fallback also returns 0 because macOS `strings` (Xcode's, no `-e` flag) does not decode the UTF-16LE string pool of a binary AndroidManifest.xml. Confirmed by a targeted UTF-16LE byte-search (`data.count('DuoLikeAnimation'.encode('utf-16-le'))` = 1) that the label is correctly compiled into the manifest. This is a local-tooling gap (missing `aapt`, non-GNU `strings`), not a defect in the manifest edit.
  git status --short — matches A7 exactly: `M README.md`, `M android/app/src/main/AndroidManifest.xml`, `M android/app/src/main/kotlin/.../MainActivity.kt`, `D android/app/src/main/res/values-night/styles.xml`, `M lib/main.dart`, `?? .../FoldMotionBridge.kt`, `?? docs/plans/008-android-motion.md`
  git diff lib/main.dart — no `Platform.`, `defaultTargetPlatform`, or `kIsWeb` (A8 satisfied)

Open questions for architect:
1. The plan's exact A6 verification commands rely on GNU `strings`/`aapt`, neither of which is present on this macOS host (only Xcode's BSD `strings`, no `aapt` on PATH). I substituted a file-redirected pipe and a Python UTF-16LE byte search to confirm the same facts (counts 2 and 1 respectively) — flagging in case the architect wants the plan's verification commands revised for this toolchain, or wants `aapt`/`android-sdk-build-tools` added to the environment for future phases.
2. On-device acceptance items (H0–H12) were not run — no physical Android phone or emulator was available in this session; a human still needs to work through `## Acceptance`'s device checklist as the plan specifies.

## Review

STATUS: ACCEPTED (everything checkable from the tree). The device checklist
H0–H12 is unrun and stays **PENDING** — it is the user's, not the implementer's,
exactly as D0–D13 was in 003; no status below depends on it.

### What was checked, and how

Not from the report. Reviewed against `d06d448` (HEAD, the last accepted
commit), `git status --short` for the untracked/deleted entries, and the built
`app-debug.apk` on disk.

1. **Kotlin is byte-identical to the plan.** Both `## Files` code blocks were
   re-extracted from this file with `awk` and `diff`ed against
   `android/app/src/main/kotlin/com/debojyoti/iphoneduo_animation_flutter/FoldMotionBridge.kt`
   and `MainActivity.kt`: zero differences in either.
2. **`lib/main.dart`** — `git diff` is hunks A, B, C verbatim (import, constant
   + `main()`, `FoldScreen.build`); nothing else in the file moved.
3. **`AndroidManifest.xml`** — the one-attribute label change only.
4. **`values-night/styles.xml`** — staged `D`; the `values-night` directory is
   gone (`ls android/app/src/main/res/` shows `values` only). `values/styles.xml`
   is untouched (`Theme.Light.NoTitleBar` for both styles).
5. **README** — the four hunks verbatim.
6. **Scope** — `git status --short` restricted to `shaders lib/fold lib/motion
   lib/demo test ios macos pubspec.yaml pubspec.lock android/settings.gradle.kts
   android/gradle.properties android/app/build.gradle.kts .metadata` returns
   nothing. A7's expected list matches exactly; A8 grep count is 0.
7. **Gates re-run here**, not taken from the report: `flutter analyze` → `No
   issues found!`; `dart format --output=none --set-exit-if-changed lib test` →
   exit 0; `flutter test` → `+20: All tests passed!` (20 `test`/`testWidgets`
   declarations in `test/`, unchanged).

### Math check (independent of the report)

- `SensorManager.getRotationMatrixFromVector` re-fetched from AOSP
  `core/java/android/hardware/SensorManager.java`: the nine `R[i]` lines are
  exactly the matrix in `## Math` §2 (`R[1] = q1q2 − q3q0`, `R[3] = q1q2 + q3q0`,
  `R[5] = q2q3 − q1q0`, `R[7] = q2q3 + q1q0`, …), i.e. the active rotation
  `R(q)`, row-major, columns = device axes in world coordinates, and the
  `getRotationMatrix` javadoc states `[0 0 g] = R · gravity`. So `R` is device →
  world, the same object the Swift's `deviceToReferenceMatrix` returns after its
  latch. `deviceToReference = current` with no transpose is correct.
- `process()` vs `ios/Runner/AppDelegate.swift` (read here, line by line):
  `relative = referenceᵀ · current`, `normal = relative.columns.2`,
  `measured = atan2(normal·screenX, normal.z)`,
  `predicted = measured + (rate·screenY)·0.04`,
  `motionTilt += (predicted − motionTilt)·0.7`, `recalibrate` = clear + zero +
  emit `0.0`. The Kotlin's transpose is the `ref[3·j + i]` indexing:
  `normalX = ref[0]·nx + ref[3]·ny + ref[6]·nz`, `normalY = ref[1]·nx + ref[4]·ny + ref[7]·nz`,
  `normalZ = ref[2]·nx + ref[5]·ny + ref[8]·nz` with `(nx, ny, nz) = (current[2], current[5], current[8])`
  = column 2. Each index checked against row-major `R[3·row + col]`: correct.
- Sign: `R_y(+φ)·(0,0,1) = (sin φ, 0, cos φ)` ⇒ `measured = φ`; the same rotation
  sends `(−1,0,0) → (−cos φ, 0, +sin φ)`, so the left edge moves toward the
  viewer (+z) ⇒ right edge is the hinge ⇒ θ > 0 ⇒ shader `xh = uSize.x`. Same
  chain as 003 review §A; agrees with `context.md`.
- Gyro: `TYPE_GYROSCOPE` is right-hand-rule rad/s in the device frame, same as
  `CMRotationRate`; `rate·screenY = dφ/dt` for the rotation above, so the
  prediction extrapolates in the same direction. Two-sensor caching (gyro
  updates `rate`, GRV emits) is decision 8 as written.
- Axis table: `.landscapeRight → (0,−1,0),(1,0,0)` and `.landscapeLeft →
  (0,1,0),(−1,0,0)` in the Swift; the Kotlin maps `ROTATION_90 → landscapeRight`
  and `ROTATION_270 → landscapeLeft`. `Display.getRotation()` doc: a device turned
  90° CCW reports `ROTATION_90`, which is the home-button-right pose that
  `UIInterfaceOrientation.landscapeRight` names. Consistent.
- H2 element check restated: device-Y axis in world coords is column 1 =
  `(R[1], R[4], R[7])`, so upright portrait ⇒ `R[7] ≈ 1`; under the transposed
  convention it would be `R[5]`. The log line prints `r0…r8` in that order.

### The A6 substitution — verified, not a rationalisation

I re-ran the checks against `build/app/outputs/flutter-apk/app-debug.apk`
myself, using the scratchpad only.

| A6 fact | Plan command | What was actually established |
|---|---|---|
| shader asset present | `unzip -l … \| grep -c` | literal command, prints `1` (re-run here) |
| both channel names in the dex | `unzip -p 'classes*.dex' \| strings \| grep -c` | `unzip -p` to a file then BSD `strings \| grep -c` prints `2` (re-run here). Stronger check done here: exact MUTF-8 dex string entries `duo_fold/motion\0` = 1 and `duo_fold/motion/tilt\0` = 1, total substring count 2, i.e. exactly the two channel names and nothing else; `FoldMotionBridge` and `MainActivity` class descriptors and the `FoldMotion` log tag are also present |
| launcher label compiled | `aapt dump badging … \|\| unzip -p AndroidManifest.xml \| strings \| grep -c` | `aapt` absent; the plan's own fallback is defective on macOS, not the implementer's execution of it: the binary manifest's string pool has `flags = 0x0` (UTF-16, not `UTF8_FLAG 0x100`), and Xcode's `strings` has no `-e l`. Decoded the pool here: index 31 = `DuoLikeAnimation`, index 1 = `label`; the only remaining `iphoneduo_animation_flutter` strings are the package-prefixed `com.debojyoti.iphoneduo_animation_flutter[.…]` entries (package, activity, permission, startup provider), so no standalone old label survives |

Verdict: the substitution establishes the same facts the plan intended, and the
label check establishes them more directly than the plan's fallback could have.
Accepted. For the record, a portable form of the third A6 command that does not
need `aapt` or GNU `strings` (for future plans on this host; nothing to change
now):

    unzip -p build/app/outputs/flutter-apk/app-debug.apk AndroidManifest.xml | python3 -c 'import sys; print(sys.stdin.buffer.read().count("DuoLikeAnimation".encode("utf-16-le")))'

must print `1`.

### Decisions re-checked

- Decision 1 (hot restart): Flutter's `EventChannel.IncomingStreamRequestHandler.onListen`
  calls `handler.onCancel(null)` on the old sink before `handler.onListen` when a
  listener is already active, so `listening` toggles false→true and
  `updateRegistration()` re-registers; `reference` and `motionTilt` are not
  touched. Correct.
- Decision 11: `SystemUiOverlayStyle.dark` does set
  `systemNavigationBarColor: Color(0xFF000000)`; replacing it was necessary for
  the edge-to-edge sampled area, and the seven fields in `kSystemUiOverlayStyle`
  are the plan's.
- `MainActivity` lifecycle order (`configureFlutterEngine` from `onCreate` before
  `onResume`; bridge nulled after `onDestroy`) is sound; the null-safe calls cover
  the case where the engine never attached.

### Acceptance ledger

| Item | Result |
|---|---|
| A1 `flutter analyze` | PASS — re-run here |
| A2 `dart format --set-exit-if-changed` | PASS — exit 0, re-run here |
| A3 `flutter test` | PASS — 20/20, re-run here; no test file changed |
| A4 `flutter build ios --debug --no-codesign` | PASS — per report (not re-run; `lib/main.dart` hunks are platform-neutral and A1/A3 cover their compile) |
| A5 `flutter build apk --debug` | PASS — the APK on disk is dated this session, 151 MB, contains 5 dex files and the shader asset; report says no impellerc/Kotlin warnings |
| A6 asset / channel strings / label | PASS — all three re-established here, see table above |
| A7 `git status --short` | PASS — the seven expected entries, nothing else |
| A8 no platform gating in `main.dart` | PASS — grep count 0 |
| H0–H12 | PENDING (user, physical Android phone with a gyroscope; `adb logcat -s FoldMotion` for H2) |

### `context.md` hunks

The five proposed hunks under `## Decisions` stand as written; nothing in the
review changes them. Route them to the implementer to apply before the commit,
as in 003. Add one sentence to the fourth hunk (the Android gotcha), after
"`r7 ≈ 1, |r5| small`":

    +   The APK label/dex checks on this macOS host need Python, not `aapt`/GNU
    +   `strings`: the binary manifest's string pool is UTF-16 (008 review).

### Before the commit

1. Apply the `context.md` hunks (plus the sentence above). Nothing else.
2. Commit `phase 008: android-motion` with `context.md` included.
3. Run H0–H12 on the Android phone. Any FAIL comes back to me as a debug request
   with the item id, the H2 `R=[…]` line, the device model, Android version, and
   the backend line `flutter run` printed (Vulkan / OpenGLES).
