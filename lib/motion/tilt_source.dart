import 'package:flutter/foundation.dart';

/// A source of the tilt angle θ.
///
/// θ is in radians and signed per context.md: θ > 0 means the RIGHT edge is
/// the hinge (the left edge lifts toward the viewer). Implementations clamp
/// |θ| to the configured maximum before notifying listeners.
///
/// Phase 001 provides `ManualTilt`; phase 004 adds the sensor-driven model
/// behind the same interface so main.dart's composition does not change.
abstract class TiltSource extends ChangeNotifier {
  /// Current θ in radians.
  double get theta;

  /// True when θ comes from device sensors, false for slider control.
  bool get isLive;
}
