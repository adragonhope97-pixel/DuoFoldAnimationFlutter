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
