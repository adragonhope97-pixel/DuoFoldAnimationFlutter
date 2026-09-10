import 'package:flutter/foundation.dart';

/// A source of the tilt angle θ.
///
/// θ is in radians and signed per context.md: θ > 0 means the RIGHT edge is
/// the hinge (the left edge lifts toward the viewer). θ is NOT clamped: the
/// original clamps nothing, and only the manual slider is bounded (±45°).
///
/// `FoldMotionModel` is the only implementation: it switches between the
/// native Core Motion stream and the manual slider behind this interface,
/// so main.dart's composition does not change.
abstract class TiltSource extends ChangeNotifier {
  /// Current θ in radians.
  double get theta;

  /// True when θ comes from device sensors, false for slider control.
  bool get isLive;
}
