# 005 blur-dim

## Goal

`shaders/duo_fold.frag` becomes the complete `duoFold` Metal kernel: after the
reprojection of 002, each pixel samples the interface with a golden-angle
(Vogel) disk whose radius is `blurSpread · gap` in logical px, with
`clamp(int(radius·2), 6, 32)` taps under a constant loop bound of 32, a
per-pixel hash rotation, a single-sample fast path below radius 0.5, taps that
leave the interface contributing black, an early-out to black when the whole
kernel misses the interface, and `attenuation = max(1 − darkening · radius, 0)`
applied to every path. `FoldParameters.maxBlurPx`/`dimStrength` are replaced by
the original's `blurSpread = 0.12` and `darkening = 0.015`, which is what
uniform slots 4 and 5 now carry. When this phase is done the screen shows
frosted glass — sharp and bright at the hinge, progressively soft and dark
toward the lifted edge, with a feathered rather than a hard black wedge — and
the 002 reprojection probes still pass, verbatim, because that suite now runs
with `blurSpread = darkening = 0`, for which the new kernel reduces exactly to
002's single bounds-checked sample.

## Decisions

1. **The Metal kernel is transcribed, not re-derived.** `DuoFold.metal` was
   re-fetched for this plan and every constant below is read off it:
   `kBlurTaps = 32`, `kGoldenAngle = 2.39996322972865332`,
   `kTwoPi = 6.28318530717958648`,
   `hash21(p) = fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453)`,
   `taps = clamp(int(radius * 2.0), 6, kBlurTaps)`,
   `r_i = radius * sqrt((i + 0.5) / taps)`,
   `a_i = i * kGoldenAngle + rotation`,
   `attenuation = max(1.0 - darkening * radius, 0.0)`, single sample when
   `radius < 0.5`. `FoldEffect.swift` was re-fetched too and fixes the
   defaults: `blurSpread = 0.12`, `darkening = 0.015`.
2. **The bounds test changes shape, and this is a correction to `context.md`.**
   The Metal kernel has exactly one bounds test —
   `any(hit < -radius) || any(hit > size + radius)` → black — plus the implicit
   "a tap outside the layer reads transparent" of
   `layerEffect(maxSampleOffset: .zero)`. `context.md`'s "black if
   P.xy ∉ [0,W]×[0,H]" is the `radius = 0` special case of that, which is why
   002 was right and is still right at `blurSpread = 0`. With blur on, pixels
   whose hit lies within `radius` of the border are a partial average, i.e. the
   black wedge gets a feathered edge. See `## Math`, correction 1.
3. **Out-of-bounds taps read black, branchlessly.** `sampleRgb(q)` always
   performs the texture fetch and then selects `vec3(0.0)` when `q` is outside
   `[0, uSize]`. Reason: no early return, no divergent fetch, no reliance on
   sampler clamping (which would smear the border), and it keeps the GLSL
   inside the dialect subset every backend accepts.
4. **Constant loop bound 32 with `if (i >= taps) break;`.** Impeller/SkSL
   require a compile-time loop bound; `break` inside such a loop is permitted
   and keeps the cost proportional to the live tap count. A predicated fallback
   with no `break` is given in `## Files` and is to be applied *only* if the
   shader compiler rejects the `break`; the implementer must say so in the
   report.
5. **`taps` is computed in float and converted once.** `int` overloads of
   `clamp` are not guaranteed across the dialects this asset is compiled for,
   so: `float tapsF = clamp(floor(radius * 2.0), 6.0, 32.0); int taps = int(tapsF);`
   For `radius ≥ 0.5` this is bit-identical to Metal's `int(radius * 2.0)`
   truncation (the value is positive, so `floor == trunc`). `tapsF` is used for
   every float division so no `float(taps)` conversion appears in the inner
   loop.
6. **The hash is fed `FlutterFragCoord().xy`.** Metal hashes `position`, the
   view-space coordinate; ours is the same value because the effect's
   `bounds.xy` is the origin. Even if it were not, the hash is decorrelation
   noise, so an origin shift changes nothing perceptible.
7. **Slots 4 and 5 are renamed, not appended.** `uMaxBlurPx → uBlurSpread`,
   `uDimStrength → uDarkening`; the uniform *order* and *count* are unchanged,
   so `fold_effect.dart` changes only in which `FoldParameters` field feeds
   each `setFloat`. `context.md`'s uniform table and tunables table are updated
   by the hunks in `## Files`; those placeholders were always earmarked for
   this phase.
8. **The magenta sentinel stays, with new predicates.**
   `uEyeDistPx <= 0 || uBlurSpread < 0 || uDarkening < 0` → magenta. The old
   `uDimStrength > 1.0` predicate is dropped: `darkening` is not a 0..1 knob,
   it is a per-px coefficient. The sentinel is no longer needed to keep the
   uniforms live (both are read now) but it still catches a mis-wired slot.
9. **`FilterQuality.none` on the sampler is kept.** The reprojection is close
   to 1:1 in sampling density (`cos|θ|·t ≈ 0.98` at 20°), the blur averages
   6–32 taps anyway, and nearest keeps the pixel probes deterministic. If the
   human sees stair-stepping on the gradient hero card at high tilt (checklist
   H7), that becomes a 006 item; the implementer does not change it here.
10. **The 002 suite is preserved by disabling blur in it, not by moving its
    probes.** `radius = 0` makes the new kernel reduce to 002's exact code path
    (single sample, `hit ∉ [0,uSize] → black`, attenuation 1), so every probe
    keeps its literal expected colour. Blur and dim get their own suite,
    `test/blur_dim_test.dart`, on a 400×900 canvas — 400×300 is too squat for
    any pixel's whole kernel to miss the interface, so the black early-out
    could not be pinned there (see `## Math`).
11. **The new suite probes raw 8-bit channels, not `Color`.** Blur results are
    non-exact, so the probes are `closeTo` on ints from the RGBA buffer;
    `Color`'s 0..1 doubles would add float fuzz to an already tolerant check.
12. **Acceptance stays independent of the motion sign.** Every human check is
    made with Manual tilt on and the slider at a stated value; nothing below
    asks which edge is the hinge. 003's device checklist is still owed and is
    not folded in here.

## Files

### 1. `shaders/duo_fold.frag` — replace the whole file

```glsl
#version 320 es
// duo_fold.frag — phase 005: perspective reprojection (002) + variable-radius
// Vogel-disk blur and dimming. A transcription of duoFold in DuoFold.metal
// (elijah-semyonov/DuoLikeAnimation); every constant here is that file's.
//
// Model (context.md): the interface lies on z = 0; the eye E sits on the plane
// normal through the screen centre at uEyeDistPx; the glass rotates by |θ|
// around the hinge edge (right edge when θ > 0, left when θ < 0), rising toward
// the eye. Each pixel is placed on the rotated glass, a ray from E through it
// is continued to z = 0, and the interface is sampled around the hit point with
// a disk whose radius grows with the glass-to-plane gap. Frosted glass also
// absorbs, so the same radius dims the result.

precision highp float;

#include <flutter/runtime_effect.glsl>

// Uniform layout is fixed by context.md. Float slots (Dart setFloat index):
//   uSize.x       0
//   uSize.y       1
//   uAngle        2
//   uEyeDistPx    3
//   uBlurSpread   4
//   uDarkening    5
// Sampler slots (Dart setImageSampler index):
//   uTex          0
uniform vec2 uSize;         // logical px size of the sampled child
uniform float uAngle;       // tilt θ, radians; θ > 0 → hinge on the RIGHT edge
uniform float uEyeDistPx;   // eye distance D, logical px
uniform float uBlurSpread;  // blur radius per logical px of gap (0.12)
uniform float uDarkening;   // light lost per logical px of blur radius (0.015)
uniform sampler2D uTex;     // the rasterised child

out vec4 fragColor;

const int kBlurTaps = 32;                          // Metal kBlurTaps
const float kGoldenAngle = 2.39996322972865332;    // Vogel disk spacing, radians
const float kTwoPi = 6.28318530717958648;
const vec4 kBlack = vec4(0.0, 0.0, 0.0, 1.0);

// Metal's hash21: a per-pixel value in [0,1) used to rotate the disk so the
// Vogel banding becomes frosted-glass grain.
float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Interface colour at logical position q; black outside the interface, as
// SwiftUI's layer.sample is transparent outside the layer (maxSampleOffset is
// .zero in FoldEffect.swift). Branchless: the fetch is unconditional and the
// result is selected, so no tap relies on sampler clamping, which would smear
// the border.
vec3 sampleRgb(vec2 q) {
  vec3 rgb = texture(uTex, q / uSize).rgb;
  bool inside = all(greaterThanEqual(q, vec2(0.0))) &&
                all(lessThanEqual(q, uSize));
  return inside ? rgb : vec3(0.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;   // logical px, origin top-left
  float tilt = abs(uAngle);

  vec4 color;
  if (tilt < 1e-5) {
    color = vec4(sampleRgb(p), 1.0);           // untilted glass: identity
  } else {
    float xh = uAngle > 0.0 ? uSize.x : 0.0;   // hinge x
    float u = p.x - xh;                        // signed distance from hinge
    // Pixel on the rotated glass: foreshortened toward the hinge, lifted by
    // |u|·sin(tilt) toward the eye.
    vec3 G = vec3(xh + u * cos(tilt), p.y, abs(u) * sin(tilt));
    vec3 E = vec3(uSize * 0.5, uEyeDistPx);
    float depth = E.z - G.z;
    if (depth <= 1e-3) {
      color = kBlack;                          // glass at/behind the eye
    } else {
      float t = E.z / depth;                   // ray E→G continued to z = 0
      vec2 hit = E.xy + (G.xy - E.xy) * t;     // hit point on the interface
      float gap = G.z;                         // glass-to-plane separation
      float radius = uBlurSpread * gap;        // blur radius, logical px
      if (any(lessThan(hit, vec2(-radius))) ||
          any(greaterThan(hit, uSize + vec2(radius)))) {
        color = kBlack;                        // the whole kernel misses the UI
      } else {
        float attenuation = max(1.0 - uDarkening * radius, 0.0);
        if (radius < 0.5) {
          color = vec4(sampleRgb(hit) * attenuation, 1.0);   // one tap
        } else {
          // Vogel disk, area-uniform in i, rotated per pixel. Small kernels
          // need few taps; the loop bound is the constant kBlurTaps and the
          // live count is honoured by the break.
          float tapsF = clamp(floor(radius * 2.0), 6.0, float(kBlurTaps));
          int taps = int(tapsF);
          float rotation = hash21(p) * kTwoPi;
          vec3 sum = vec3(0.0);
          for (int i = 0; i < kBlurTaps; ++i) {
            if (i >= taps) {
              break;
            }
            float ri = radius * sqrt((float(i) + 0.5) / tapsF);
            float ai = float(i) * kGoldenAngle + rotation;
            sum += sampleRgb(hit + ri * vec2(cos(ai), sin(ai)));
          }
          color = vec4(sum / tapsF * attenuation, 1.0);
        }
      }
    }
  }

  // Parameter sentinel: makes a mis-wired uniform slot visible instead of
  // subtle. darkening is a per-px coefficient, not a 0..1 knob.
  if (uEyeDistPx <= 0.0 || uBlurSpread < 0.0 || uDarkening < 0.0) {
    color = vec4(1.0, 0.0, 1.0, 1.0);          // magenta = invalid FoldParameters
  }

  fragColor = color;
}
```

**Fallback, only if the shader compiler rejects the `break`** (apply verbatim,
change nothing else, and record it in the report):

before
```glsl
          for (int i = 0; i < kBlurTaps; ++i) {
            if (i >= taps) {
              break;
            }
            float ri = radius * sqrt((float(i) + 0.5) / tapsF);
            float ai = float(i) * kGoldenAngle + rotation;
            sum += sampleRgb(hit + ri * vec2(cos(ai), sin(ai)));
          }
```
after
```glsl
          for (int i = 0; i < kBlurTaps; ++i) {
            if (i < taps) {
              float ri = radius * sqrt((float(i) + 0.5) / tapsF);
              float ai = float(i) * kGoldenAngle + rotation;
              sum += sampleRgb(hit + ri * vec2(cos(ai), sin(ai)));
            }
          }
```

### 2. `lib/fold/fold_parameters.dart` — replace the whole file

```dart
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
```

### 3. `lib/fold/fold_effect.dart` — one hunk (lines 77–78)

before
```dart
      ..setFloat(4, p.maxBlurPx) // uMaxBlurPx
      ..setFloat(5, p.dimStrength) // uDimStrength
```
after
```dart
      ..setFloat(4, p.blurSpread) // uBlurSpread
      ..setFloat(5, p.darkening) // uDarkening
```

### 4. `test/reprojection_test.dart` — two hunks

Hunk 4a, the file's header comment (line 19):

before
```dart
// Every probe is ≥ 9 px from a predicted boundary.
```
after
```dart
// Every probe is ≥ 9 px from a predicted boundary.
//
// Blur and dim are switched off here (blurSpread = darkening = 0). With
// radius = 0 the 005 kernel reduces exactly to 002's path — one bounds-checked
// sample, attenuation 1, black iff hit ∉ [0,uSize] — so these probes keep
// their literal colours and stay a pure test of the reprojection geometry.
// Blur and dimming are pinned by test/blur_dim_test.dart.
```

Hunk 4b, `_render` (lines 60–64):

before
```dart
        child: FoldEffect(
          angle: degrees * math.pi / 180,
          params: const FoldParameters(),
          child: const _SplitChild(),
        ),
```
after
```dart
        child: FoldEffect(
          angle: degrees * math.pi / 180,
          params: const FoldParameters(blurSpread: 0, darkening: 0),
          child: const _SplitChild(),
        ),
```

### 5. `test/widget_test.dart` — two hunks

Hunk 5a (lines 35–40):

before
```dart
    test('defaults mirror FoldEffect.swift', () {
      const FoldParameters p = FoldParameters();
      expect(p.eyeDistanceMm, 320);
      expect(p.pointsPerMm, 6);
      expect(p.eyeDistancePx, 1920);
    });
```
after
```dart
    test('defaults mirror FoldEffect.swift', () {
      const FoldParameters p = FoldParameters();
      expect(p.eyeDistanceMm, 320);
      expect(p.pointsPerMm, 6);
      expect(p.eyeDistancePx, 1920);
      expect(p.blurSpread, 0.12);
      expect(p.darkening, 0.015);
    });
```

Hunk 5b (lines 42–47):

before
```dart
    test('copyWith and equality', () {
      const FoldParameters p = FoldParameters();
      expect(p.copyWith(), p);
      expect(p.copyWith(pointsPerMm: 6.3), isNot(p));
      expect(p.copyWith(eyeDistanceMm: 400).eyeDistancePx, 2400);
    });
```
after
```dart
    test('copyWith and equality', () {
      const FoldParameters p = FoldParameters();
      expect(p.copyWith(), p);
      expect(p.copyWith(pointsPerMm: 6.3), isNot(p));
      expect(p.copyWith(eyeDistanceMm: 400).eyeDistancePx, 2400);
      expect(p.copyWith(blurSpread: 0, darkening: 0), isNot(p));
      expect(p.copyWith(blurSpread: 0).darkening, 0.015);
    });
```

### 6. `test/blur_dim_test.dart` — new file

```dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_effect.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_parameters.dart';

// Pixel probes for the blur and dimming of docs/plans/005-blur-dim.md, Math.
// Geometry: W = 400, H = 900 logical px (tall enough that a whole kernel can
// miss the interface, which 400×300 is not), D = 1920 px, default parameters
// blurSpread = 0.12, darkening = 0.015. At |θ| = 20°, for a pixel at distance
// d from the hinge:
//   gap = d·sin20°, radius = 0.12·gap, attenuation = 1 − 0.015·radius
//   d =   5.5 → radius  0.226 → single-sample path, attenuation 0.9966 → 254
//   d =  99.5 → radius  4.084 →  8 taps,            attenuation 0.9387 → 239
//   d = 212.5 → radius  8.722 → 17 taps,            attenuation 0.8692
//   d = 300.5 → radius 12.333 → 24 taps,            attenuation 0.8150 → 208
//   d = 399.5 → radius 16.396 → 32 taps,            attenuation 0.7541
// Every colour probe below sits far enough from the red/blue seam and from the
// interface border that its whole kernel reads one flat colour; the seam probe
// at d = 212.5 and the fringe probe at the wedge edge are the two deliberate
// exceptions.
const double _w = 400;
const double _h = 900;
const int _stride = 400;

/// Left half red, right half blue, split exactly at x = W / 2.
class _SplitChild extends StatelessWidget {
  const _SplitChild();

  @override
  Widget build(BuildContext context) {
    return const Row(
      // A childless ColoredBox lays out at height 0 under a Row's loose
      // cross-axis constraints; stretch so the halves fill the height.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: ColoredBox(color: Color(0xFFFF0000))),
        Expanded(child: ColoredBox(color: Color(0xFF0000FF))),
      ],
    );
  }
}

/// Renders FoldEffect at 400×900 logical px, dpr 1, with the default
/// (blurring, dimming) parameters. Returns the raw RGBA bytes.
Future<ByteData> _render(WidgetTester tester, double degrees) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_w, _h);
  addTearDown(tester.view.reset);

  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: FoldEffect(
          angle: degrees * math.pi / 180,
          params: const FoldParameters(),
          child: const _SplitChild(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  final AnimatedSampler sampler = tester.widget<AnimatedSampler>(
    find.byType(AnimatedSampler),
  );
  expect(sampler.enabled, isTrue, reason: 'shader must be loaded first');

  ByteData? bytes;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    expect(image.width, _w.round());
    bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();
  });
  return bytes!;
}

/// The (r, g, b) channels of a pixel as 0..255 ints.
(int, int, int) _rgb(ByteData bytes, int x, int y) {
  final int i = (y * _stride + x) * 4;
  return (bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
}

int _alpha(ByteData bytes, int x, int y) =>
    bytes.getUint8((y * _stride + x) * 4 + 3);

void main() {
  testWidgets('θ = -20°: dimming grows with the distance from the hinge', (
    WidgetTester tester,
  ) async {
    final ByteData px = await _render(tester, -20);

    // d = 5.5: radius 0.226 < 0.5, the single-sample path, barely dimmed.
    final (int hingeR, int hingeG, int hingeB) = _rgb(px, 5, 450);
    expect(_alpha(px, 5, 450), 255);
    expect(hingeG, 0);
    expect(hingeB, 0);
    expect(hingeR, closeTo(254, 3));

    // d = 99.5: 8 taps, all of them red, attenuation 0.9387.
    final (int nearR, int nearG, int nearB) = _rgb(px, 99, 450);
    expect(nearG, 0);
    expect(nearB, 0);
    expect(nearR, closeTo(239, 3));

    // d = 300.5: 24 taps, all of them blue, attenuation 0.8150.
    final (int farR, int farG, int farB) = _rgb(px, 300, 450);
    expect(farR, 0);
    expect(farG, 0);
    expect(farB, closeTo(208, 3));

    // Monotone: the farther from the hinge, the darker.
    expect(hingeR, greaterThan(nearR));
    expect(nearR, greaterThan(farB));
  });

  testWidgets('θ = -20°: the disk mixes the two halves across the seam', (
    WidgetTester tester,
  ) async {
    final ByteData px = await _render(tester, -20);
    // d = 212.5 puts the hit at x ≈ 199.7 with radius 8.7: the 17 taps straddle
    // the red/blue seam and every one of them is inside the interface.
    final (int r, int g, int b) = _rgb(px, 212, 450);
    expect(g, 0);
    expect(r, greaterThan(40));
    expect(b, greaterThan(40));
    // No tap is lost off the interface, so the two channels sum to the full
    // attenuated white: 255 × 0.8692 ≈ 222.
    expect(r + b, closeTo(222, 6));
  });

  testWidgets(
    'θ = -20°: the wedge is black inside and feathered at its edge',
    (WidgetTester tester) async {
      final ByteData px = await _render(tester, -20);
      // hit.y ≈ -33.9 and -23.2: the whole 16.4 px kernel is off the interface.
      expect(_rgb(px, 399, 0), (0, 0, 0));
      expect(_rgb(px, 399, 10), (0, 0, 0));
      // hit.y ≈ 933.9 and 923.2: the same at the bottom.
      expect(_rgb(px, 399, 899), (0, 0, 0));
      expect(_rgb(px, 399, 889), (0, 0, 0));
      // hit.y ≈ -1.7: the kernel straddles the top border, so this pixel is a
      // partial average — dark, but neither black nor full brightness.
      final (int r, int g, int b) = _rgb(px, 399, 30);
      expect(r, 0);
      expect(g, 0);
      expect(b, greaterThan(15));
      expect(b, lessThan(150));
    },
  );

  testWidgets('θ = +20°: the hinge is on the other edge, same magnitudes', (
    WidgetTester tester,
  ) async {
    final ByteData px = await _render(tester, 20);

    // Mirror of x = 5: d = 5.5, single-sample path, hit ≈ 395 (blue).
    final (int hingeR, int hingeG, int hingeB) = _rgb(px, 394, 450);
    expect(hingeR, 0);
    expect(hingeG, 0);
    expect(hingeB, closeTo(254, 3));

    // Mirror of x = 300: d = 300.5, hit ≈ 113 (red), attenuation 0.8150.
    final (int farR, int farG, int farB) = _rgb(px, 99, 450);
    expect(farG, 0);
    expect(farB, 0);
    expect(farR, closeTo(208, 3));

    // Mirror of the wedge.
    expect(_rgb(px, 0, 0), (0, 0, 0));
    expect(_rgb(px, 0, 899), (0, 0, 0));
  });
}
```

### 7. `context.md` — four hunks

Hunk 7a, the reference-math section (lines 67–95: the heading, the fenced block
and the three bullets after it). The fences in the before/after below are the
file's own triple backticks.

before
```
## Reference math (verified against DuoFold.metal in 002; implementer never alters)

For pixel p = (px, py):

<fence>
if |θ| < 1e-5 → sample p directly (identity); skip the rest
u   = px - xh                       // signed distance from hinge along x
G   = (xh + u·cos|θ|, py, |u|·sin|θ|)   // pixel's position on the rotated glass
if E.z - G.z ≤ 1e-3 → black         // glass at/behind the eye (Metal guard)
t   = E.z / (E.z - G.z)             // ray E→G extended to z = 0
P   = E + t·(G - E)                 // hit point on interface plane
uv  = P.xy / uSize                  // sample coordinate; black if P.xy ∉ [0,W]×[0,H]
gap = G.z                           // 0 at hinge, W·sin|θ| at far edge
r   = blurSpread · gap              // blur radius in logical px; blurSpread = 0.12.
                                    // The ABSOLUTE gap, as in DuoFold.metal: no
                                    // normalisation, because there is no maximum tilt
                                    // any more — 003 deleted maxTiltDeg/maxTiltRad.
                                    // Settled in the 003 review; 005 implements it.
<fence>

- If `uv` is outside [0,1]² → output black (alpha 1). Do not rely on
  sampler clamping; it smears the border.
- Blur: golden-angle (Vogel) disk of radius `r`, tap count
  `clamp(int(r·2), 6, 32)` evaluated under a constant GLSL loop bound; the
  005 plan fixes the bound and the offset schedule. Taps that land outside
  [0,1]² contribute black, not clamped edge.
- Dim: `rgb *= max(1 − darkening · r, 0)` with `darkening = 0.015` (Metal's
  `attenuation`). Slots 4 and 5 carry `blurSpread` and `darkening` from 005;
  the uniform table is renamed by that plan, not before it.
```

after
```
## Reference math (verified against DuoFold.metal in 002 and 005; implementer never alters)

For pixel p = (px, py), with S(q) = the interface sample at logical position q:
`texture(uTex, q/uSize).rgb` when q ∈ [0,uSize]², else black. Outside the
interface the sample is black, never the clamped edge — SwiftUI's `layer.sample`
is transparent outside the layer (`layerEffect(maxSampleOffset: .zero)`), and
clamping smears the border.

<fence>
if |θ| < 1e-5 → S(p), alpha 1 (identity); skip the rest
u   = px - xh                       // signed distance from hinge along x
G   = (xh + u·cos|θ|, py, |u|·sin|θ|)   // pixel's position on the rotated glass
if E.z - G.z ≤ 1e-3 → black         // glass at/behind the eye (Metal guard)
t   = E.z / (E.z - G.z)             // ray E→G extended to z = 0
P   = E + t·(G - E)                 // hit point on interface plane
gap = G.z                           // 0 at hinge, W·sin|θ| at far edge
r   = blurSpread · gap              // blur radius in logical px; blurSpread = 0.12.
                                    // The ABSOLUTE gap, as in DuoFold.metal: no
                                    // normalisation, because there is no maximum tilt
                                    // any more — 003 deleted maxTiltDeg/maxTiltRad.
if P.xy < -r or P.xy > uSize + r → black    // the WHOLE kernel misses the
                                    // interface. This is DuoFold.metal's only
                                    // bounds test; "black iff P ∉ [0,uSize]" is
                                    // its r = 0 case, which is why the wedge
                                    // acquires an r-wide feathered edge in 005.
a   = max(1 - darkening · r, 0)     // attenuation; darkening = 0.015
if r < 0.5 → rgb = a · S(P)         // one tap, no kernel
else         n  = clamp(int(r·2), 6, 32)          // taps
             φ  = hash21(p) · 2π
             hash21(q) = fract(sin(dot(q, (12.9898, 78.233))) · 43758.5453)
             rᵢ = r · sqrt((i + 0.5) / n)         // area-uniform in i
             αᵢ = i · 2.39996322972865332 + φ     // golden angle
             rgb = a · (1/n) · Σᵢ₌₀ⁿ⁻¹ S(P + rᵢ·(cos αᵢ, sin αᵢ))
alpha is always 1
<fence>

- Everything is in logical px, including `gap`, `r` and the tap offsets; the
  blur is therefore `r · devicePixelRatio` physical px wide, exactly as the
  original's points-based radius is at 3×.
- The tap loop's bound must be the compile-time constant 32 (Impeller/SkSL);
  the live count `n` is honoured with `if (i >= n) break;` inside it. `n` is
  computed in float (`clamp(floor(r·2), 6, 32)`) because integer `clamp` is not
  safe across the dialects the asset is compiled for.
- Attenuation applies to the single-sample path and the blur path alike, and is
  1 in the identity path (r = 0 there).
```

Hunk 7b, the uniform table (lines 103–104).

before
```
uniform float uMaxBlurPx;      // 4
uniform float uDimStrength;    // 5    0..1
```
after
```
uniform float uBlurSpread;     // 4    blur radius per px of gap (0.12)
uniform float uDarkening;      // 5    light lost per px of radius (0.015)
```

Hunk 7c, the tunables table (lines 116–118).

before
```
| maxBlurPx | 24 | placeholder holding uniform slot 4 since 003. In 005 the slot becomes `blurSpread = 0.12` with the Metal semantics: `radius = blurSpread · gap`. |
| dimStrength | 0.6 | placeholder holding uniform slot 5 since 003. 005 adopts `attenuation = max(1 − darkening · radius, 0)`, `darkening = 0.015`. |
| (blur taps) | — | the blur phase uses the original's `clamp(int(radius·2), 6, 32)` under a constant loop bound; no Dart tunable |
```
after
```
| blurSpread | 0.12 | Swift `blurSpread`; uniform slot 4 since 005. `radius = blurSpread · gap`, both logical px |
| darkening | 0.015 | Swift `darkening`; uniform slot 5 since 005. `attenuation = max(1 − darkening · radius, 0)` |
| (blur taps) | — | `clamp(int(radius·2), 6, 32)`, Vogel disk, per-pixel hash rotation, one tap below radius 0.5; loop bound is the constant 32; no Dart tunable |
```

Hunk 7d, two new bullets at the end of `## Gotchas already known`.

before
```
- SwiftUI `Text` boxes come from the font's line height (~1.163 em), not from
  the HIG "line height" column; leave `TextStyle.height` null in the demo.
```
after
```
- SwiftUI `Text` boxes come from the font's line height (~1.163 em), not from
  the HIG "line height" column; leave `TextStyle.height` null in the demo.
- The blur costs up to 32 texture fetches per *physical* fragment (≈95 M/frame
  at 1170×2532). That is what the original does at 3×; do not raise the cap, and
  do not add a second blur pass.
- A 400×300 test canvas cannot produce a fully black pixel under blur: a pixel
  is black only where the ray misses by more than `r`, i.e. where
  `D − gap < (H/2)/blurSpread`. Blur probes need a tall canvas (400×900 in
  `test/blur_dim_test.dart`); the phone at 390×844 satisfies it everywhere.
```

## Math

Conventions restated: logical px throughout; x right, y down, z toward the
viewer; interface plane z = 0; `E = (W/2, H/2, D)` with `D = uEyeDistPx = 1920`;
θ > 0 ⇒ hinge on the **right** edge, `xh = θ > 0 ? W : 0`;
`p = FlutterFragCoord().xy` is the pixel *centre*, so column `x` has
`p.x = x + 0.5`.

**Equivalence of the glass placement with Metal's.** Metal writes
`side = hingeRight ? -1 : +1`, `d = |p.x − hingeX|`,
`glass.x = hingeX + side·d·cos(tilt)`. Ours writes `u = p.x − xh`,
`glass.x = xh + u·cos(tilt)`, `glass.z = |u|·sin(tilt)`. For a right hinge
`u = −d`, for a left hinge `u = +d`, so `u = side·d` in both cases. Identical,
and unchanged from 002.

**Correction 1 to `context.md` (bounds).** `context.md` line 77 said the sample
coordinate is black when `P.xy ∉ [0,W]×[0,H]`. `DuoFold.metal` has no such test.
Its only test is `any(hit < -radius) || any(hit > size + radius)` → black, and
individual taps that land outside the layer read transparent (SwiftUI's
`layer.sample`, `maxSampleOffset: .zero`). The two agree exactly when
`radius = 0`, which is the whole of 002 and is why the 002 probes stay valid
once that suite sets `blurSpread = 0`. With blur on, a pixel whose hit is within
`radius` of the border averages its in-bounds taps with black, so the black
wedge gains a feathered edge of width ≈ `radius`. Hunk 7a records this.

**Correction 2 (tap count).** Metal's `clamp(int(radius·2.0), 6, 32)` is
transcribed as `clamp(floor(radius·2.0), 6.0, 32.0)` in float, then converted to
int. `radius ≥ 0.5` on that branch, so `floor ≡ trunc` and the values are
identical. Reason: integer `clamp` overloads are not guaranteed in every dialect
this asset is compiled through. Hunk 7a records this too.

**Blur kernel.** For tap `i ∈ [0, n)`:

```
rᵢ = radius · sqrt((i + 0.5) / n)          // area-uniform: equal area per tap
αᵢ = i · 2.39996322972865332 + φ           // golden angle
φ  = hash21(p) · 6.28318530717958648
hash21(q) = fract(sin(dot(q, vec2(12.9898, 78.233))) · 43758.5453)
rgb = attenuation · (1/n) · Σ sampleRgb(hit + rᵢ·(cos αᵢ, sin αᵢ))
```

`φ` depends on the pixel and not on the tilt, so the grain is static in screen
space, as in the original.

**Probe derivation for `test/blur_dim_test.dart`.** W = 400, H = 900, D = 1920,
θ = −20° (hinge left, `xh = 0`, so `d = p.x`), sin 20° = 0.3420201,
cos 20° = 0.9396926, blurSpread = 0.12, darkening = 0.015,
`t = D/(D − gap)`, `hit.x = 200 + (d·cos20° − 200)·t`.

| probe | d | gap | radius | n | t | hit.x | attenuation | expected |
|---|---|---|---|---|---|---|---|---|
| P1 x=5, y=450 | 5.5 | 1.881 | 0.226 | single | 1.00098 | 4.98 | 0.99661 | red 254 |
| P2 x=99, y=450 | 99.5 | 34.031 | 4.084 | 8 | 1.01804 | 91.58 | 0.93874 | red 239 |
| P3 x=300, y=450 | 300.5 | 102.777 | 12.333 | 24 | 1.05657 | 287.04 | 0.81500 | blue 208 |
| P4 x=212, y=450 | 212.5 | 72.679 | 8.722 | 17 | 1.03934 | 199.67 | 0.86918 | red+blue ≈ 222 |
| P5 x=399 | 399.5 | 136.637 | 16.396 | 32 | 1.07663 | 388.84 | 0.75406 | see below |

`hit.y = 450 + (y + 0.5 − 450)·t`, so at x = 399 (t = 1.076625):
`y = 0 → −33.94`, `y = 10 → −23.17`, `y = 30 → −1.66`, `y = 889 → +923.17`,
`y = 899 → +933.94`. The early-out fires when `hit.y < −16.396` or
`hit.y > 916.40`: rows 0, 10, 889 and 899 are fully black; row 30 is not — its
disk is ≈ 40 % inside in y and loses a further ~12 % past x = 400, giving
blue ≈ 255·0.754·0.40 ≈ 77, which the test brackets loosely as 15 < b < 150.
P1–P4 have their whole kernel inside one flat colour region: P2's spans
x ∈ [87.5, 95.7], P3's spans x ∈ [274.7, 299.4] and y ∈ [438.2, 462.9], P4's
spans x ∈ [190.9, 208.4] and y ∈ [441.8, 459.3] — all inside the interface,
which is why P4's two channels must sum to the full attenuated 255. The +20°
probes are the mirrors: `x = 394` mirrors P1 (hit ≈ 395.0, blue),
`x = 99` mirrors P3 (hit ≈ 112.96, red), `x = 0` mirrors P5.

Expected 8-bit values assume Flutter's usual sRGB-encoded (non-linear-blended)
pipeline: `round(255 × attenuation)`. If the host instead blends in linear
space, those three probes read ≈ 255, 247 and 232. In that case the implementer
records the observed triple in the report and adjusts **only** the four
`closeTo` centres (P1, P2, P3 and the two mirrors), leaving the shader alone;
any other discrepancy is `STATUS: BLOCKED`.

**Why 400×900 and not 400×300.** A pixel is fully black only when the ray misses
the interface by more than `radius`. At the top edge that is
`(H/2)·(t − 1) > blurSpread · gap`, and with `t − 1 = gap/(D − gap)` it reduces
to `D − gap < (H/2)/blurSpread`, i.e. `1920 − gap < H/0.24`. At H = 300 this
needs `gap > 670`, impossible for W = 400 (`gap ≤ 400·sin|θ|`); at H = 900 it
holds for every gap. The phone (390×844, half-height 422) needs
`D − gap < 3517`, always true, so the wedge is genuinely black on device.

## Commands

```
cd /Users/debojyoti/Documents/exploration/iphoneduo_animation_flutter
flutter analyze
flutter test test/blur_dim_test.dart
flutter test
flutter build ios --debug --no-codesign
git diff --stat
grep -rn "maxBlurPx\|dimStrength" lib test shaders
grep -n "0\.12\|0\.015" shaders/duo_fold.frag
```

Both greps must print nothing: the placeholders are gone and the tunable
constants live in Dart, not in the shader.

Do **not** commit; the review runs first.

## Acceptance

**Tree-checkable (implementer).**

- T1 `flutter analyze` reports no issues.
- T2 `flutter test` passes: the four `test/reprojection_test.dart` tests with
  their expectations unedited, the four new `test/blur_dim_test.dart` tests, and
  the untouched 003/004 suites.
- T3 `flutter build ios --debug --no-codesign` succeeds — this is the only
  check that the GLSL compiles (`impellerc`, Metal runtime stage).
- T4 `git diff --stat` shows exactly: `shaders/duo_fold.frag`,
  `lib/fold/fold_parameters.dart`, `lib/fold/fold_effect.dart`,
  `test/reprojection_test.dart`, `test/widget_test.dart`,
  `test/blur_dim_test.dart` (new), `context.md`, `docs/plans/005-blur-dim.md`.
  Nothing under `ios/`, `lib/motion/`, `lib/demo/`, `lib/main.dart` or
  `pubspec.yaml`.
- T5 `grep -c "texture(" shaders/duo_fold.frag` is 1: exactly one sampling
  site, inside `sampleRgb`.
- T6 `grep -n "for (int i" shaders/duo_fold.frag` shows the bound as
  `i < kBlurTaps`, a compile-time constant.
- T7 The report states whether the `break` fallback of `## Files` §1 was
  needed, and, if any `closeTo` centre was adjusted, the observed values.

**Visual, on the iPhone (`flutter run -d 00008120-000278980AE3601E`), panel
open, Manual tilt ON. Nothing below depends on the motion sign; the
which-edge-is-the-hinge question stays with 003's checklist.**

- H1 Slider at 0.0°: the 004 screen exactly — sharp, full brightness, no dim
  cast anywhere (the `|θ| < 1e-5` identity path).
- H2 Slider at 5°: the edge that lifts is just perceptibly soft, the hinge edge
  is pin-sharp, and there is no visible seam or step between the two.
- H3 Slider at 20°: text near the lifted edge is clearly frosted and visibly
  darker than at the hinge; softness and darkness increase smoothly across the
  screen with no band, ring or plateau.
- H4 Slider at 20° and 45°: the black wedges at the lifted edge have a soft,
  ~10–40 px feathered border rather than a hard cut, and there is **no** bright
  streak or smear along the top or bottom edge — a streak means a tap is reading
  clamped edge texels instead of black.
- H5 Slider at 45°: no magenta anywhere (the sentinel), and no concentric arcs
  or rosettes in the blurred region — the grain must read as uniform noise.
- H6 Sweep the slider end to end: it stays smooth. If it visibly stutters,
  report the observation and the device's thermal state; do not change the tap
  cap.
- H7 Report whether the gradient hero card shows stair-stepping at 45°
  (nearest sampling, decision 9). Observation only; no change this phase.

## Out of scope

- `lib/motion/**` and `ios/Runner/AppDelegate.swift`: the motion path is 003's
  and is not touched, re-signed or re-tuned here.
- `lib/demo/**` and `lib/main.dart`: no control for `blurSpread` or `darkening`
  is added to the panel; the original has none.
- `pubspec.yaml`, package versions, the shader asset declaration.
- `FilterQuality` on `setImageSampler` (decision 9), the `AnimatedSampler`
  wiring, and `FoldEffect`'s load/error path.
- The uniform *order* and *count*: only slots 4 and 5 change meaning. A new
  uniform would need a new plan.
- Moving, adding or retuning any probe in `test/reprojection_test.dart` beyond
  hunks 4a and 4b.
- 003's device sign checklist and any judgement about which edge hinges.

## Implementation report
STATUS: DONE
Files written:
  - test/blur_dim_test.dart (new)
Files edited:
  - shaders/duo_fold.frag — replaced whole file per plan §1 (reprojection + Vogel-disk blur + dimming, magenta sentinel updated).
  - lib/fold/fold_parameters.dart — replaced whole file per plan §2 (blurSpread/darkening replace maxBlurPx/dimStrength).
  - lib/fold/fold_effect.dart — hunk §3: setFloat(4)/setFloat(5) now feed blurSpread/darkening.
  - test/reprojection_test.dart — hunks §4a/§4b: header comment on blur=0 reduction, `_render` now passes `FoldParameters(blurSpread: 0, darkening: 0)`.
  - test/widget_test.dart — hunks §5a/§5b: added blurSpread/darkening default and copyWith assertions.
  - context.md — hunks §7a–§7d: reference-math section rewritten for the new bounds test and blur kernel, uniform table renamed (uBlurSpread/uDarkening), tunables table updated, two new gotcha bullets appended.
Deviations from plan: none.
Self-fixes applied: none — the primary `break`-based tap loop compiled without needing the fallback in plan §1.
Command results:
  flutter analyze — clean (No issues found!)
  flutter test test/blur_dim_test.dart — 4/4 passed, all `closeTo` centres matched the plan's predicted sRGB values with no adjustment (P1≈254, P2≈239, P3≈208, seam sum≈222)
  flutter test — 21/21 passed (reprojection_test.dart 4, widget_test.dart 8, blur_dim_test.dart 4, motion/demo suites unaffected)
  flutter build ios --debug --no-codesign — ok (`✓ Built build/ios/iphoneos/Runner.app`)
  flutter run … — not run (per instructions, device run not attempted)
  git diff --stat — matches T4 exactly: context.md, lib/fold/fold_effect.dart, lib/fold/fold_parameters.dart, shaders/duo_fold.frag, test/reprojection_test.dart, test/widget_test.dart, plus new test/blur_dim_test.dart and docs/plans/005-blur-dim.md; nothing under ios/, lib/motion/, lib/demo/, lib/main.dart or pubspec.yaml.
  grep -rn "maxBlurPx\|dimStrength" lib test shaders — empty (T-check passed)
  grep -c "texture(" shaders/duo_fold.frag — 1 (T5 passed)
  grep -n "for (int i" shaders/duo_fold.frag — `i < kBlurTaps` (T6 passed)
Open questions for architect:
  1. `grep -n "0\.12\|0\.015" shaders/duo_fold.frag` is NOT empty: it matches the two uniform-declaration comments (`// blur radius per logical px of gap (0.12)` and `// light lost per logical px of blur radius (0.015)`) that are verbatim from the plan's own §1 file content (lines 130–131). The actual numeric constants live only in `FoldParameters` (Dart); the shader has no `0.12`/`0.015` literal in code, only in these two documentation comments that the plan itself specified. Flagging since the plan's Commands section says "Both greps must print nothing" — left as written since the plan's file content is authoritative and I do not alter given content to satisfy a grep.

## Review

STATUS: ACCEPTED

Reviewed against `git diff a6f533b`, the appended `## Implementation report`, and
a fresh fetch of `DuoLikeAnimation/Shaders/DuoFold.metal`. The tree diff is
exactly T4's six files plus the new test and this plan; `grep -rn
"maxBlurPx\|dimStrength" lib test shaders` is empty; the shader is byte-identical
to plan §1 (`diff` against the plan's fenced block: no output) and
`test/blur_dim_test.dart` is byte-identical to plan §6. The `break`-based primary
tap loop was used; no fallback, no deviations.

### 1. Kernel vs `DuoFold.metal`, term by term

Checked against the fetched Metal, not against the plan. Left column is the
Metal source, right column `shaders/duo_fold.frag`.

| Metal | GLSL | verdict |
|---|---|---|
| `constant int kBlurTaps = 32;` | `const int kBlurTaps = 32;` | identical |
| `constant float kGoldenAngle = 2.39996322972865332;` | same literal, all 17 digits | identical |
| `constant float kTwoPi = 6.28318530717958648;` | same literal | identical |
| `fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453)` | same, `vec2` | identical |
| `hingeX = angle > 0 ? size.x : 0`, `side = ±1`, `d = abs(p.x - hingeX)`, `glass = (hingeX + side*d*cos, p.y, d*sin)` | `u = p.x - xh`, `G = (xh + u*cos, p.y, abs(u)*sin)` | equivalent: `u = side·d` for both hinges, `abs(u) = d` |
| `depth = eye.z - glass.z; if (depth <= 1e-3) → black` | same, `1e-3` | identical |
| `t = eye.z/depth; hit = eye.xy + (glass.xy - eye.xy)*t` | same | identical |
| `radius = blurSpread * gap`, `gap = glass.z` | same | identical |
| `if (any(hit < -radius) \|\| any(hit > size + radius)) → black` | `lessThan(hit, vec2(-radius))` / `greaterThan(hit, uSize + vec2(radius))` | identical, same strict comparators |
| `attenuation = max(1.0 - darkening * radius, 0.0)` | same (float instead of `half`) | identical value |
| `if (radius < 0.5) return opaque(layer.sample(bounds.xy + hit) * attenuation)` | `vec4(sampleRgb(hit) * attenuation, 1.0)` | identical: Metal's premultiplied `*attenuation` then alpha→1 equals scaling rgb only |
| `taps = clamp(int(radius * 2.0), 6, kBlurTaps)` | `clamp(floor(radius*2.0), 6.0, 32.0)` then `int()` | identical on this branch (`radius ≥ 0.5 > 0` ⇒ `floor ≡ trunc`) |
| `rotation = hash21(position) * kTwoPi` | `hash21(p) * kTwoPi`, `p = FlutterFragCoord()` | deviation, accepted — see finding F2 |
| `r = radius * sqrt((float(i) + 0.5) / float(taps))` | `ri = radius * sqrt((float(i) + 0.5) / tapsF)` | identical |
| `a = float(i) * kGoldenAngle + rotation` | identical | identical |
| `sum += layer.sample(bounds.xy + hit + offset).rgb` | `sum += sampleRgb(hit + ri*vec2(cos(ai), sin(ai)))` | identical; `layer.sample` is `address::clamp_to_zero`, i.e. black outside, which `sampleRgb`'s `inside ? rgb : vec3(0)` reproduces without relying on the sampler |
| `for (int i = 0; i < taps; ++i)` | `for (int i = 0; i < kBlurTaps; ++i) { if (i >= taps) break; … }` | equivalent; constant bound is required by Impeller |
| `return half4(sum / half(taps) * attenuation, 1.0h)` | `vec4(sum / tapsF * attenuation, 1.0)` | identical |
| `if (tilt < 1e-5) return opaque(layer.sample(position))` | `vec4(sampleRgb(p), 1.0)` | identical (`p` is always in bounds, so the added test never fires) |

No constant, comparator or threshold differs. `sum` is accumulated in `float`
rather than Metal's `half3`; that is strictly more accurate (Metal's worst case
is ≈0.25/255 of accumulation error) and is not a fidelity loss.

### 2. The reprojection suite passes for the right reason

Two independent checks, neither of which trusts the report:

- **Structural.** With `blurSpread = 0` the kernel's live code is character-wise
  002's. `radius = 0` ⇒ `vec2(-radius) ≡ vec2(0.0)` and `uSize + vec2(radius) ≡
  uSize`, so the early-out becomes 002's `any(lessThan(hit, vec2(0.0))) ||
  any(greaterThan(hit, uSize))`; `attenuation = max(1.0 - uDarkening*0.0, 0.0)`
  is exactly `1.0` in IEEE float; `radius < 0.5` is true, so the single tap
  `sampleRgb(hit)` runs, which is 002's `sampleInterface(hit)` with an added
  in-bounds test that the early-out has already guaranteed. Diffed against
  `git show a6f533b:shaders/duo_fold.frag`: the geometry block (`xh`, `u`, `G`,
  `E`, `depth`, `t`, `hit`) is unchanged line for line.
- **Sensitivity.** I re-implemented the 005 kernel independently (Vogel taps,
  hash, tap clamp) and evaluated the 002 probes at the *default* parameters on
  the 002 canvas (400×300, θ = −20°). They would read: (399,150) blue **162**
  not 255; (399,20) blue **162** not 255; (200,150) red **224** not 255;
  (399,0) blue **12** not black; (0,150) red **255** (hinge, unaffected). Nine
  of the eleven −20° expectations change. The suite is therefore not blind to
  blur/dim: it passes because the kernel genuinely degenerates, and it would
  have failed had the plan's hunk 4b been omitted.

The same independent model reproduces every `test/blur_dim_test.dart` centre:
P1 254.1 (single-sample path), P2 239.4 (n = 8), P3 blue 207.8 (n = 24), seam
117.3 + 104.3 = 221.6 (n = 17, all taps in bounds), feather row 30 blue 78.1
(inside the test's 15…150 bracket), rows 0/10/889/899 black, +20° mirrors
254.1 and 207.8. The probe values in the plan's table were right and the
implementer's report of an unadjusted pass is consistent with them.

### 3. Ruling on the failed grep

`grep -n "0\.12\|0\.015" shaders/duo_fold.frag` matching lines 30–31 is **my
bad check, not a defect**. The plan's own §1 file content puts those numbers in
the uniform-declaration comments, so the command could never have printed
nothing against a correct implementation; the implementer was right to keep the
plan's file content and flag the contradiction instead of editing comments to
satisfy a grep. The intent — no blur/dim magic number in shader *code* — holds:
`0.12` and `0.015` appear only after `//`, and the only numeric literals in the
kernel are the Metal constants. The check should have been

```
sed 's://.*::' shaders/duo_fold.frag | grep -nE '0\.12|0\.015'
```

which prints nothing here. No action; the comments stay.

### 4. Findings (no change required this phase)

- **F1 — `FilterQuality.none` is now the largest remaining departure from the
  original, and it is a real one.** `SwiftUI::Layer::sample` is documented as
  returning a *linearly filtered*, premultiplied value (`metal::filter::linear`,
  `address::clamp_to_zero`); we sample nearest. The blur hides it at large
  radius, but the near-hinge band runs the single-sample path at radius < 0.5
  where the original is bilinear and we are nearest, so a slightly reprojected
  sharp region will stair-step where the original is smooth. Out of scope here
  (decision 9, checklist H7); it must be settled in 006, and the switch is
  cheap: every 002 probe sits in a flat colour region ≥ 9 px from a seam, so
  `FilterQuality.linear` cannot move them. The `clamp_to_zero` half of that
  sampler is already reproduced correctly by `sampleRgb`, so only the filter
  changes.
- **F2 — hash argument.** Metal hashes `position` (pre-`bounds.xy` subtraction),
  we hash the local `FlutterFragCoord()`. This translates the noise field and
  nothing else; both are static in screen space. Accepted, as planned in
  decision 6.
- **F3 — premultiplication.** Metal sums premultiplied rgb and forces alpha 1;
  the Impeller snapshot texture is also premultiplied and we do the same. Equal
  for opaque content and equal for translucent content too. No action.
- **F4 — the visual checklist H1–H7 is unrun** (no device in this session), as
  is 003's sign checklist. Acceptance is granted on the tree-checkable criteria
  T1–T7 plus the two independent checks above; H1–H7 stay owed and should be
  run with 003's list in one device session before 006 is planned.

### 5. Proposed `context.md` hunks (route to the implementer; I do not edit it)

Hunk R1 — append to `## Gotchas already known`:

before
```
- A 400×300 test canvas cannot produce a fully black pixel under blur: a pixel
  is black only where the ray misses by more than `r`, i.e. where
  `D − gap < (H/2)/blurSpread`. Blur probes need a tall canvas (400×900 in
  `test/blur_dim_test.dart`); the phone at 390×844 satisfies it everywhere.
```
after
```
- A 400×300 test canvas cannot produce a fully black pixel under blur: a pixel
  is black only where the ray misses by more than `r`, i.e. where
  `D − gap < (H/2)/blurSpread`. Blur probes need a tall canvas (400×900 in
  `test/blur_dim_test.dart`); the phone at 390×844 satisfies it everywhere.
- `SwiftUI::Layer::sample` is a **linearly filtered**, premultiplied fetch with
  `address::clamp_to_zero` (hence black, not clamped edge, outside the layer).
  We match the addressing in `sampleRgb` but still sample nearest
  (`FilterQuality.none`, 002 decision, kept by 005 decision 9). That is the one
  known remaining departure from the original; resolving it is a 006 item, and
  no 002/005 probe sits near enough to a colour seam to move if it flips to
  `FilterQuality.linear`.
- The disk-rotation hash is fed `FlutterFragCoord()` (layer-local), where the
  Metal feeds `position` (pre-`bounds.xy`). That translates the grain field and
  changes nothing else; do not "fix" it by adding an offset uniform.
```

Hunk R2 — in `## Reference math`, after the "tap loop's bound" bullet:

before
```
- Attenuation applies to the single-sample path and the blur path alike, and is
  1 in the identity path (r = 0 there).
```
after
```
- Attenuation applies to the single-sample path and the blur path alike, and is
  1 in the identity path (r = 0 there).
- At `blurSpread = 0` the whole kernel collapses to the 002 path exactly:
  `±r` bounds ≡ `[0,uSize]` bounds, `a` ≡ 1, `r < 0.5` ⇒ one tap. That identity
  is what lets `test/reprojection_test.dart` keep its literal colours; it is
  verified, not assumed (005 review §2).
```

Commit as `phase 005: blur-dim`.
