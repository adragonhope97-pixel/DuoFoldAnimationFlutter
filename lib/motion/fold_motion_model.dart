import 'dart:async';
import 'dart:math' as math;

import 'fold_motion_channel.dart';
import 'tilt_source.dart';

/// Dart half of FoldMotionModel.swift: chooses between the native motion
/// stream and the manual slider, and exposes the same surface the original
/// control panel binds to (`tiltAngle`, `usesManualTilt`, `manualDegrees`,
/// `isMotionAvailable`, `start`, `stop`, `recalibrate`).
///
/// Filtering and prediction live on the native side; the stream is used as is.
class FoldMotionModel extends TiltSource {
  FoldMotionModel({
    this._channel = const PlatformMotionChannel(),
    double initialManualDegrees = 0,
    this._forceManual = false,
  }) : _manualDegrees = _clampDegrees(initialManualDegrees);

  /// Slider range in ContentView.swift: −45…45° in 0.5° steps.
  static const double maxManualDegrees = 45;

  final MotionChannel _channel;
  final bool _forceManual;

  bool _started = false;
  bool _isMotionAvailable = false;
  bool _usesManualTilt = true;
  double _manualDegrees;
  double _motionTilt = 0;
  StreamSubscription<double>? _subscription;

  static double _clampDegrees(double degrees) =>
      degrees.clamp(-maxManualDegrees, maxManualDegrees).toDouble();

  /// Tilt fed to the shader, radians. Positive: the right edge is the hinge.
  double get tiltAngle =>
      _usesManualTilt ? _manualDegrees * math.pi / 180 : _motionTilt;

  @override
  double get theta => tiltAngle;

  @override
  bool get isLive => !_usesManualTilt && _isMotionAvailable;

  bool get isMotionAvailable => _isMotionAvailable;

  /// Latest native tilt, radians (0 until the first sample after calibration).
  double get motionTilt => _motionTilt;

  bool get usesManualTilt => _usesManualTilt;

  set usesManualTilt(bool value) {
    final bool next = value || !_isMotionAvailable;
    if (next == _usesManualTilt) {
      return;
    }
    _usesManualTilt = next;
    notifyListeners();
  }

  double get manualDegrees => _manualDegrees;

  set manualDegrees(double value) {
    final double next = _clampDegrees(value);
    if (next == _manualDegrees) {
      return;
    }
    _manualDegrees = next;
    notifyListeners();
  }

  /// Queries availability, picks the initial mode (manual when motion is
  /// missing or [forceManual]), and subscribes to the native stream. The
  /// stream runs even in manual mode, as in the original, so switching back
  /// is instant.
  Future<void> start() async {
    _started = true;
    final bool available = await _channel.isAvailable();
    if (!_started) {
      return; // stopped while awaiting
    }
    _isMotionAvailable = available;
    _usesManualTilt = _forceManual || !available;
    notifyListeners();
    if (available && _subscription == null) {
      _subscription = _channel.tiltStream().listen(
        _onTilt,
        onError: _onStreamError,
      );
    }
  }

  void stop() {
    _started = false;
    _subscription?.cancel();
    _subscription = null;
  }

  /// Makes the current pose the zero-tilt pose: the plane the UI stays in.
  Future<void> recalibrate() async {
    _motionTilt = 0;
    notifyListeners();
    await _channel.recalibrate();
  }

  void _onTilt(double radians) {
    _motionTilt = radians;
    if (!_usesManualTilt) {
      notifyListeners();
    }
  }

  /// A platform error ends the stream's usefulness: cancel it — which stops
  /// Core Motion through the bridge's `onCancel` — and fall back to the
  /// slider for good. Cancelling from inside `onError` is legal.
  void _onStreamError(Object error, StackTrace stackTrace) {
    _subscription?.cancel();
    _subscription = null;
    _isMotionAvailable = false;
    _usesManualTilt = true;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
