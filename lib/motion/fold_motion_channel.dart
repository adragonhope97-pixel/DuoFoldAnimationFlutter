import 'package:flutter/services.dart';

/// The native Core Motion bridge (ios/Runner/AppDelegate.swift).
///
/// The Swift side runs the original FoldMotionModel algorithm — reference
/// pose, gravity-resolved matrix handedness, gyro prediction, smoothing —
/// and streams the resulting tilt in radians. Dart only chooses between that
/// stream and the manual slider. Abstract so tests can inject a fake.
abstract class MotionChannel {
  /// Whether device motion exists on this platform.
  Future<bool> isAvailable();

  /// Tilt in radians, signed per context.md (positive: right edge is the
  /// hinge), already smoothed and predicted, ~120 Hz while listened to.
  Stream<double> tiltStream();

  /// Makes the current pose the zero-tilt pose.
  Future<void> recalibrate();
}

/// [MotionChannel] over the real platform channels. Reports "unavailable"
/// wherever the bridge is not registered (macOS, tests, web).
class PlatformMotionChannel implements MotionChannel {
  const PlatformMotionChannel();

  static const MethodChannel _methods = MethodChannel('duo_fold/motion');
  static const EventChannel _events = EventChannel('duo_fold/motion/tilt');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _methods.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<double> tiltStream() {
    return _events.receiveBroadcastStream().map(
      (Object? event) => (event! as num).toDouble(),
    );
  }

  @override
  Future<void> recalibrate() async {
    try {
      await _methods.invokeMethod<void>('recalibrate');
    } on MissingPluginException {
      // No bridge on this platform; nothing to reset.
    }
  }
}
