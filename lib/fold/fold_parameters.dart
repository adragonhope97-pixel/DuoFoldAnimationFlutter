/// Physical parameters of the frosted-glass fold. Mirrors `FoldParameters`
/// in FoldEffect.swift (elijah-semyonov/DuoLikeAnimation) field for field.
///
/// Immutable; derive variants with [copyWith].
class FoldParameters {
  const FoldParameters({
    this.eyeDistanceMm = 320,
    this.pointsPerMm = 6,
    this.blurSpread = 0.12,
    this.darkening = 0.015,
  });

  /// Distance from the viewer's eyes to the untilted screen, looking at it
  /// head-on. The eye stays there while the device tilts. A typical
  /// hand-held distance is about 30 cm. (Swift: `eyeDistanceMillimeters`.)
  final double eyeDistanceMm;

  /// Approximate density of logical px (iOS points) on current iPhone panels:
  /// about 460 ppi at 3x and 326 ppi at 2x, both close to 6 pt/mm.
  /// (Swift: `pointsPerMillimeter`.) Deliberately not devicePixelRatio.
  final double pointsPerMm;

  /// Blur radius gained per logical px of separation between the glass and
  /// the interface plane — the tangent of the frosted glass's scattering
  /// half-angle. The shader uses `radius = blurSpread · gap`, both in logical
  /// px. (Swift: `blurSpread`.) Uniform slot 4.
  final double blurSpread;

  /// Fraction of light lost per logical px of blur radius, so the frostier
  /// the glass the darker it gets: `rgb *= max(1 − darkening · radius, 0)`.
  /// (Swift: `darkening`.) Uniform slot 5.
  final double darkening;

  /// [eyeDistanceMm] in logical px — the value the shader receives as
  /// `uEyeDistPx`. 320 mm × 6 px/mm = 1920 px, as in the original.
  double get eyeDistancePx => eyeDistanceMm * pointsPerMm;

  FoldParameters copyWith({
    double? eyeDistanceMm,
    double? pointsPerMm,
    double? blurSpread,
    double? darkening,
  }) {
    return FoldParameters(
      eyeDistanceMm: eyeDistanceMm ?? this.eyeDistanceMm,
      pointsPerMm: pointsPerMm ?? this.pointsPerMm,
      blurSpread: blurSpread ?? this.blurSpread,
      darkening: darkening ?? this.darkening,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoldParameters &&
        other.eyeDistanceMm == eyeDistanceMm &&
        other.pointsPerMm == pointsPerMm &&
        other.blurSpread == blurSpread &&
        other.darkening == darkening;
  }

  @override
  int get hashCode =>
      Object.hash(eyeDistanceMm, pointsPerMm, blurSpread, darkening);

  @override
  String toString() {
    return 'FoldParameters(eyeDistanceMm: $eyeDistanceMm, '
        'pointsPerMm: $pointsPerMm, blurSpread: $blurSpread, '
        'darkening: $darkening)';
  }
}
