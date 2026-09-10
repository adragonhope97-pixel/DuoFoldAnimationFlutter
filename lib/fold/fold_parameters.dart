import 'dart:math' as math;

/// Tunables for the fold effect. Mirrors `FoldParameters` in the Swift source.
///
/// Immutable; derive variants with [copyWith]. Defaults come from
/// context.md → "Tunables".
class FoldParameters {
  const FoldParameters({
    this.eyeDistanceMm = 320,
    this.maxBlurPx = 24,
    this.dimStrength = 0.6,
    this.maxTiltDeg = 35,
  });

  /// Eye-to-interface distance in millimetres (Swift default: 320).
  final double eyeDistanceMm;

  /// Disk-blur radius in logical px at the far edge (g = 1).
  final double maxBlurPx;

  /// Fraction of brightness removed at the far edge (g = 1). Range 0..1.
  final double dimStrength;

  /// Clamp on |θ| in degrees. Every tilt source applies it before notifying.
  final double maxTiltDeg;

  /// Blur tap count. A compile-time constant in `shaders/duo_fold.frag`
  /// (ceiling 24), recorded here for display only — it is not a uniform.
  static const int blurTaps = 16;

  /// Logical px per millimetre: Flutter logical px are 1/160 in by
  /// definition and there are 25.4 mm per inch. Deliberately not
  /// devicePixelRatio (context.md → coordinate conventions).
  static const double pxPerMm = 160 / 25.4;

  /// [eyeDistanceMm] in logical px — the value the shader receives
  /// as `uEyeDistPx`.
  double get eyeDistancePx => eyeDistanceMm * pxPerMm;

  /// [maxTiltDeg] in radians.
  double get maxTiltRad => maxTiltDeg * math.pi / 180;

  FoldParameters copyWith({
    double? eyeDistanceMm,
    double? maxBlurPx,
    double? dimStrength,
    double? maxTiltDeg,
  }) {
    return FoldParameters(
      eyeDistanceMm: eyeDistanceMm ?? this.eyeDistanceMm,
      maxBlurPx: maxBlurPx ?? this.maxBlurPx,
      dimStrength: dimStrength ?? this.dimStrength,
      maxTiltDeg: maxTiltDeg ?? this.maxTiltDeg,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoldParameters &&
        other.eyeDistanceMm == eyeDistanceMm &&
        other.maxBlurPx == maxBlurPx &&
        other.dimStrength == dimStrength &&
        other.maxTiltDeg == maxTiltDeg;
  }

  @override
  int get hashCode =>
      Object.hash(eyeDistanceMm, maxBlurPx, dimStrength, maxTiltDeg);

  @override
  String toString() {
    return 'FoldParameters(eyeDistanceMm: $eyeDistanceMm, '
        'maxBlurPx: $maxBlurPx, dimStrength: $dimStrength, '
        'maxTiltDeg: $maxTiltDeg)';
  }
}
