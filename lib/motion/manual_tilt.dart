import 'dart:math' as math;

import 'tilt_source.dart';

/// Slider-driven [TiltSource]: degrees in, radians out, clamped to ±[maxDeg].
///
/// This is the default source whenever no sensor stream exists (desktop,
/// simulator, tests) and the only source in phase 001.
class ManualTilt extends TiltSource {
  ManualTilt({required this.maxDeg, double initialDeg = 0})
    : _degrees = _clamp(initialDeg, maxDeg);

  /// Clamp on |θ| in degrees (FoldParameters.maxTiltDeg).
  final double maxDeg;

  double _degrees;

  static double _clamp(double deg, double maxDeg) =>
      deg.clamp(-maxDeg, maxDeg).toDouble();

  /// θ in degrees, the slider's unit. Positive → hinge on the right edge.
  double get degrees => _degrees;

  set degrees(double value) {
    final double next = _clamp(value, maxDeg);
    if (next == _degrees) {
      return;
    }
    _degrees = next;
    notifyListeners();
  }

  @override
  double get theta => _degrees * math.pi / 180;

  @override
  bool get isLive => false;

  /// Back to θ = 0.
  void reset() => degrees = 0;
}
