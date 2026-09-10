/// Physical parameters of the frosted-glass fold. Mirrors `FoldParameters`
/// in FoldEffect.swift (elijah-semyonov/DuoLikeAnimation) field for field.
///
/// Immutable; derive variants with [copyWith].
class FoldParameters {
  const FoldParameters({
    this.eyeDistanceMm = 320,
    this.pointsPerMm = 6,
    this.maxBlurPx = 24,
    this.dimStrength = 0.6,
  });

  /// Distance from the viewer's eyes to the untilted screen, looking at it
  /// head-on. The eye stays there while the device tilts. A typical
  /// hand-held distance is about 30 cm. (Swift: `eyeDistanceMillimeters`.)
  final double eyeDistanceMm;

  /// Approximate density of logical px (iOS points) on current iPhone panels:
  /// about 460 ppi at 3x and 326 ppi at 2x, both close to 6 pt/mm.
  /// (Swift: `pointsPerMillimeter`.) Deliberately not devicePixelRatio.
  final double pointsPerMm;

  /// Placeholder for uniform slot 4 until the blur phase adopts the
  /// original's `blurSpread`. Unused by the shader before then.
  final double maxBlurPx;

  /// Placeholder for uniform slot 5 until the blur phase adopts the
  /// original's `darkening`. Range 0..1. Unused by the shader before then.
  final double dimStrength;

  /// [eyeDistanceMm] in logical px — the value the shader receives as
  /// `uEyeDistPx`. 320 mm × 6 px/mm = 1920 px, as in the original.
  double get eyeDistancePx => eyeDistanceMm * pointsPerMm;

  FoldParameters copyWith({
    double? eyeDistanceMm,
    double? pointsPerMm,
    double? maxBlurPx,
    double? dimStrength,
  }) {
    return FoldParameters(
      eyeDistanceMm: eyeDistanceMm ?? this.eyeDistanceMm,
      pointsPerMm: pointsPerMm ?? this.pointsPerMm,
      maxBlurPx: maxBlurPx ?? this.maxBlurPx,
      dimStrength: dimStrength ?? this.dimStrength,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoldParameters &&
        other.eyeDistanceMm == eyeDistanceMm &&
        other.pointsPerMm == pointsPerMm &&
        other.maxBlurPx == maxBlurPx &&
        other.dimStrength == dimStrength;
  }

  @override
  int get hashCode =>
      Object.hash(eyeDistanceMm, pointsPerMm, maxBlurPx, dimStrength);

  @override
  String toString() {
    return 'FoldParameters(eyeDistanceMm: $eyeDistanceMm, '
        'pointsPerMm: $pointsPerMm, maxBlurPx: $maxBlurPx, '
        'dimStrength: $dimStrength)';
  }
}
