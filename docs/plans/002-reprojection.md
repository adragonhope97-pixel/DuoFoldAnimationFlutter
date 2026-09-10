# 002 reprojection

## Goal

When this phase is done `shaders/duo_fold.frag` performs the full perspective
reprojection of `context.md`: each pixel is placed on the glass rotated by
|θ| about the hinge edge, a ray from the eye through it is continued to the
interface plane, and the interface is sampled there with nearest filtering;
rays that miss the interface are opaque black. The manual slider and
`--dart-define=TILT_DEGREES` drive θ exactly as in 001. No blur, no dimming.
The geometry is verified against the original `DuoFold.metal` (fetched from
`elijah-semyonov/DuoLikeAnimation`) and pinned by pixel-probe tests whose
expected values are derived by hand in `## Math`. `flutter analyze`,
`flutter test` (10/10) and `flutter build macos --debug` pass; the carried
001 check (`FlutterFragCoord()` logical px on Impeller) is acceptance item 0.

## Decisions

1. **Geometry = `context.md` reference math, verified against
   `DuoFold.metal`.** Term for term: Metal's `hingeX + side·d·cos(tilt)`
   with `side = hingeRight ? −1 : 1`, `d = |p.x − hingeX|` equals
   `xh + u·cos|θ|` with `u = px − xh`; `glass.z = d·sin(tilt)` equals
   `|u|·sin|θ|`; `t = eye.z / (eye.z − glass.z)`; `hit = eye.xy +
   (glass.xy − eye.xy)·t`. No reference math changed.
2. **Two guards from Metal added to the shader** (not in `context.md`'s
   block; proposed hunk in `## Math`): `|θ| < 1e-5` → identity
   pass-through (Metal early-exits; also keeps the slider's zero exact) and
   `E.z − G.z ≤ 1e-3` → black (glass at or behind the eye; unreachable with
   D ≈ 2016 px and W ≤ 3500 px, but it is the reference's behaviour and
   costs nothing).
3. **Black outside is decided on `hit` in logical px** (`hit < 0` or
   `hit > uSize`, componentwise, inclusive bounds as in Metal), not on
   `uv`; the sampler is never asked for a coordinate outside the image, so
   sampler clamping never smears the border.
4. **Nearest sampling stays on the Dart side**: `setImageSampler(…,
   filterQuality: FilterQuality.none)` from 001 is unchanged, so
   `fold_effect.dart` is not touched this phase.
5. **Output alpha is forced to 1** (`vec4(rgb, 1.0)`), matching Metal's
   `opaque()`: the sampled layer is composited over black. `DemoContent`
   is opaque anyway; this makes transparent children behave like the
   original.
6. **Hinge marker removed.** With reprojection on, the hinge is
   self-evident: the hinge column is pixel-identical to the untilted
   interface and the black wedges appear on the *opposite* (lifted) edge.
   The pixel tests check the hinge side numerically, so nothing is lost.
   Acceptance item 0's tilt sub-checks are restated in terms of wedges.
7. **Parameter sentinel kept** until 003 consumes `uMaxBlurPx` and
   `uDimStrength`; it is what keeps those two uniforms alive in the compiled
   stage so `setFloat(4/5)` cannot `RangeError`.
8. **`blurTaps` doc comment fixed now** (one hunk in
   `fold_parameters.dart`): it claimed a GLSL constant that does not exist
   until 003. One line of debt is cheaper to pay than to carry.
9. **New `test/reprojection_test.dart`** renders `FoldEffect` at 400×300,
   dpr 1, over a red|blue split child, reads pixels back through
   `RepaintBoundary.toImage` under `runAsync` (the technique
   flutter_shaders' own tests use) and asserts the hand-derived hit points
   at θ = 0, −20°, +20°. This proves the geometry and the hinge sign without
   a human and will catch a sign regression when 004 wires sensors. Probe
   margins are ≥ 5 px from every predicted boundary so half-pixel
   conventions cannot flip them.
10. **Test fixture uses `CrossAxisAlignment.stretch`.** A childless
    `ColoredBox` under a `Row` lays out at height 0 and rasterises nothing
    (found in the dry-run: every probe read opaque black).
11. **No changes to `main.dart`, `control_panel.dart`, `demo_content.dart`,
    `widget_test.dart`, the uniform table, or `pubspec.yaml`.**
12. **Validation target unchanged**: macOS desktop (Impeller/Metal), same
    commands as 001. Default template window is 800×600 logical
    (`MainMenu.xib` `contentRect`); acceptance numbers are given for that
    size and as formulas for any size the panel reports.
13. **Flagged for 003, decided there, not here** (details in `## Math`):
    `context.md`'s `g = gap/(W·sin|θ|)` normalisation makes blur
    independent of tilt magnitude, unlike Metal's absolute
    `radius = blurSpread·gap`; the tunables `maxBlurPx`/`dimStrength` do
    not mirror Metal's `blurSpread = 0.12`, `darkening = 0.015`; Metal uses
    up to 32 adaptive taps against our ceiling of 24.
14. **Dry-run before hand-off**: every block below was placed in a scratch
    copy of the 001 tree; `impellerc --sksl --runtime-stage-metal` OK
    (5336-byte stage), `flutter analyze` clean, `flutter test` 10/10,
    `dart format` 0 changes.

## Files

### `shaders/duo_fold.frag` — full replacement

```glsl
#version 320 es
// duo_fold.frag — phase 002: perspective reprojection, nearest sampling,
// black outside the interface. No blur, no dimming (003).
//
// Model (context.md, verified against DuoFold.metal in 002): the interface
// lies on z = 0; the eye E sits on the plane normal through the screen centre
// at uEyeDistPx; the glass rotates by |θ| around the hinge edge (right edge
// when θ > 0, left when θ < 0), rising toward the eye. Each pixel is placed
// on the rotated glass, a ray from E through it is continued to z = 0, and
// the interface is sampled at the hit point.

precision highp float;

#include <flutter/runtime_effect.glsl>

// Uniform layout is fixed by context.md. Float slots (Dart setFloat index):
//   uSize.x       0
//   uSize.y       1
//   uAngle        2
//   uEyeDistPx    3
//   uMaxBlurPx    4
//   uDimStrength  5
// Sampler slots (Dart setImageSampler index):
//   uTex          0
uniform vec2 uSize;          // logical px size of the sampled child
uniform float uAngle;        // tilt θ, radians; θ > 0 → hinge on the RIGHT edge
uniform float uEyeDistPx;    // eye distance D, logical px
uniform float uMaxBlurPx;    // used from 003
uniform float uDimStrength;  // 0..1, used from 003
uniform sampler2D uTex;      // the rasterised child

out vec4 fragColor;

const vec4 kBlack = vec4(0.0, 0.0, 0.0, 1.0);

// Interface colour at logical position q, opaque (alpha dropped: the
// sampled layer is composited over black, as in the Metal original).
vec4 sampleInterface(vec2 q) {
  return vec4(texture(uTex, q / uSize).rgb, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;   // logical px, origin top-left
  float tilt = abs(uAngle);

  vec4 color;
  if (tilt < 1e-5) {
    color = sampleInterface(p);     // untilted glass: identity
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
      if (any(lessThan(hit, vec2(0.0))) || any(greaterThan(hit, uSize))) {
        color = kBlack;                        // ray misses the interface
      } else {
        color = sampleInterface(hit);          // nearest sampling (Dart side)
      }
    }
  }

  // Parameter sentinel: keeps every uniform live and makes bad values visible.
  if (uEyeDistPx <= 0.0 || uMaxBlurPx < 0.0 ||
      uDimStrength < 0.0 || uDimStrength > 1.0) {
    color = vec4(1.0, 0.0, 1.0, 1.0);          // magenta = invalid FoldParameters
  }

  fragColor = color;
}
```

### `lib/fold/fold_parameters.dart` — one edit

Before:

```dart
  /// Blur tap count. A compile-time constant in `shaders/duo_fold.frag`
  /// (ceiling 24), recorded here for display only — it is not a uniform.
  static const int blurTaps = 16;
```

After:

```dart
  /// Blur tap count. Phase 003 bakes it into `shaders/duo_fold.frag` as a
  /// compile-time constant (ceiling 24). Recorded here for display only: it
  /// is not a uniform and has no effect before 003.
  static const int blurTaps = 16;
```

### `test/reprojection_test.dart` — new

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

// Pixel probes against the reference math (docs/plans/002-reprojection.md,
// Math). Geometry: W = 400, H = 300 logical px, dpr = 1, D = 2015.748 px.
// At |θ| = 20° (sin 0.34202, cos 0.93969):
//   hinge column (d = 0.5):  t ≈ 1.00009 → samples itself
//   far edge   (d = 399.5):  t ≈ 1.07272 → hit.y = 150 ± 1.07272·(py − 150)
//                            → rows 0..9 and 290..299 miss the interface
//   centre     (d = 200.5):  t ≈ 1.03521 → hit.x ≈ 188.0 (θ < 0), ≈ 213.0 (θ > 0)
const double _w = 400;
const double _h = 300;
const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);
const Color _black = Color(0xFF000000);

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
        Expanded(child: ColoredBox(color: _red)),
        Expanded(child: ColoredBox(color: _blue)),
      ],
    );
  }
}

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
    final ui.Image image = await boundary.toImage();
    bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();
  });
  return bytes!;
}

Color _pixel(ByteData bytes, int x, int y) {
  final int i = (y * _w.toInt() + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

void main() {
  testWidgets('θ = 0 is the identity: split at the centre, no black', (
    WidgetTester tester,
  ) async {
    final ByteData px = await _render(tester, 0);
    expect(_pixel(px, 190, 150), _red);
    expect(_pixel(px, 210, 150), _blue);
    expect(_pixel(px, 0, 0), _red);
    expect(_pixel(px, 399, 0), _blue);
    expect(_pixel(px, 0, 299), _red);
    expect(_pixel(px, 399, 299), _blue);
  });

  testWidgets('θ = -20°: hinge LEFT, black wedges on the lifted right edge', (
    WidgetTester tester,
  ) async {
    final ByteData px = await _render(tester, -20);
    // Hinge column samples itself.
    expect(_pixel(px, 0, 0), _red);
    expect(_pixel(px, 0, 150), _red);
    expect(_pixel(px, 0, 299), _red);
    // Far edge: ~10 px wedges top and bottom are black, the middle is content.
    expect(_pixel(px, 399, 0), _black);
    expect(_pixel(px, 399, 5), _black);
    expect(_pixel(px, 399, 20), _blue);
    expect(_pixel(px, 399, 150), _blue);
    expect(_pixel(px, 399, 280), _blue);
    expect(_pixel(px, 399, 294), _black);
    expect(_pixel(px, 399, 299), _black);
    // Centre pixel looks at hit.x ≈ 188: the interface appears shifted toward the hinge.
    expect(_pixel(px, 200, 150), _red);
  });

  testWidgets('θ = +20°: hinge RIGHT, mirror image', (
    WidgetTester tester,
  ) async {
    final ByteData px = await _render(tester, 20);
    expect(_pixel(px, 399, 0), _blue);
    expect(_pixel(px, 399, 150), _blue);
    expect(_pixel(px, 399, 299), _blue);
    expect(_pixel(px, 0, 0), _black);
    expect(_pixel(px, 0, 5), _black);
    expect(_pixel(px, 0, 20), _red);
    expect(_pixel(px, 0, 150), _red);
    expect(_pixel(px, 0, 280), _red);
    expect(_pixel(px, 0, 294), _black);
    expect(_pixel(px, 0, 299), _black);
    expect(_pixel(px, 200, 150), _blue);
  });
}
```

## Math

Conventions (unchanged from `context.md`): logical px; x right, y down, z
toward the viewer; interface on z = 0; `E = (W/2, H/2, D)`,
`D = uEyeDistPx = eyeDistanceMm · 160/25.4` (default 2015.748 px); θ > 0 ⇒
hinge on the right edge, `xh = θ > 0 ? W : 0`; `uAngle = degrees · π/180`,
|degrees| ≤ 35.

Shader variables (names as in the GLSL), for pixel `p = FlutterFragCoord()`
(pixel centres, i.e. `x + 0.5`):

```
tilt  = |uAngle|
if tilt < 1e-5:  colour = tex(p)                        // identity (Metal early exit)
xh    = uAngle > 0 ? uSize.x : 0
u     = p.x − xh                                       // ≤ 0 when hinge right, ≥ 0 when hinge left
G     = (xh + u·cos tilt,  p.y,  |u|·sin tilt)         // pixel on the rotated glass
E     = (uSize/2, uEyeDistPx)
depth = E.z − G.z;   if depth ≤ 1e-3: colour = black    // Metal guard, unreachable at D ≈ 2016
t     = E.z / depth                                    // > 1 whenever |u| > 0
hit   = E.xy + (G.xy − E.xy)·t                         // point on z = 0
colour = (hit.x < 0 ∨ hit.y < 0 ∨ hit.x > W ∨ hit.y > H) ? black : tex(hit)
tex(q) = (texture(uTex, q / uSize).rgb, 1)             // nearest; alpha forced to 1
```

Equivalence to `DuoFold.metal` (fetched, `main` branch): Metal writes
`d = |p.x − hingeX|`, `side = hingeRight ? −1 : 1`,
`glass = (hingeX + side·d·cos(tilt), p.y, d·sin(tilt))`. Since
`side·d = p.x − hingeX = u` and `d = |u|`, `glass ≡ G`. `eye ≡ E`,
`t`, `hit`, and the bounds test (`any(hit < 0) || any(hit > size)` when the
blur radius is 0) are identical. Metal's `opaque()` drops alpha as `tex()`
does. Reference math in `context.md` is therefore **confirmed**; the only
additions are the two guards (Decision 2).

Derived observables (used by the tests and by visual acceptance):

- Hinge column (`u → 0`): `G.z → 0`, `t → 1`, `hit → p`: the column is
  pixel-identical to the untilted interface.
- Vertical map: `hit.y = H/2 + t·(p.y − H/2)` with `t` depending only on
  `|u|`. Rows miss the interface when `|p.y − H/2| > (H/2)/t`, so the black
  wedge height at distance `|u|` from the hinge is
  `h_w(|u|) = (H/2)·(1 − 1/t) = (H/2)·gap/D`, `gap = |u|·sin tilt` — linear
  in `|u|`: each wedge is a triangle from the hinge's corner to
  `(far edge, h_w(W))`, `h_w(W) = H·W·sin tilt / (2D)`.
- Horizontal map: `hit.x = W/2 + t·(G.x − W/2)`; vertical interface lines
  stay vertical. Slope `dhit.x/d|u|` ≈ `cos tilt` ≈ 0.94 near the hinge
  (interface slightly magnified) and grows past 1 toward the lifted edge
  (interface slightly minified there: that glass is nearer the eye, so each
  pixel sees more interface). Horizontal interface lines keystone toward
  the vertical middle as they approach the lifted edge.

Worked values:

| Case | gap at far edge | t at far edge | h_w(W) | hit.x at far edge |
|---|---|---|---|---|
| test: W 400, H 300, 20° | 136.6 | 1.0727 | 10.2 px (rows 0–9, 290–299 black) | 388.2 (θ<0) / 11.8 (θ>0) — inside |
| macOS window 800×600, 20° | 273.6 | 1.157 | 40.7 px | 807 → the last ≈ 6 px of the lifted edge are black, the interface's 2 px border sits just inside |
| phone 390×844, 20° | 133.4 | 1.071 | 27.9 px | 378.6 / 11.4 — inside, no black column |
| phone 390×844, 35° | 223.7 | 1.125 | 46.8 px | 335 / 55 — inside |

Test-probe predictions (θ = −20°, W 400, H 300): far-edge pixel column
`x = 399` (`|u| = 399.5`): rows 0 and 5 → `hit.y = −10.4, −5.0` black; row
20 → 11.1 inside; row 280 → 290.0 inside; rows 294, 299 → 305.0, 310.4
black. Centre pixel (200, 150): `|u| = 200.5`, `t = 1.03521`,
`G.x = 188.41`, `hit.x = 188.0` → left half (red). Mirror for +20°:
`G.x = 212.53`, `hit.x = 213.0` → right half (blue). Every probe is ≥ 5 px
from a predicted boundary.

Proposed `context.md` hunks (main session routes to the implementer; not
applied this phase):

Hunk A — reference math block, reflecting the verification and the guards:

```
-## Reference math (architect verifies in 002; implementer never alters)
+## Reference math (verified against DuoFold.metal in 002; implementer never alters)

 For pixel p = (px, py):

 ```
+if |θ| < 1e-5 → sample p directly (identity); skip the rest
 u   = px - xh                       // signed distance from hinge along x
 G   = (xh + u·cos|θ|, py, |u|·sin|θ|)   // pixel's position on the rotated glass
+if E.z - G.z ≤ 1e-3 → black         // glass at/behind the eye (Metal guard)
 t   = E.z / (E.z - G.z)             // ray E→G extended to z = 0
 P   = E + t·(G - E)                 // hit point on interface plane
-uv  = P.xy / uSize                  // sample coordinate
+uv  = P.xy / uSize                  // sample coordinate; black if P.xy ∉ [0,W]×[0,H]
 gap = G.z                           // 0 at hinge, W·sin|θ| at far edge
-g   = gap / (W·sin|θ|)              // normalised 0..1 (guard θ = 0 → g = 0)
+g   = gap / (W·sin(maxTiltRad))     // 0..1; = 1 only at the far edge at max tilt.
+                                    // PROVISIONAL, 003 finalises. Metal uses the
+                                    // absolute gap (radius = blurSpread·gap); the old
+                                    // gap/(W·sin|θ|) made blur independent of tilt
+                                    // magnitude, which is wrong.
 ```
```

Hunk B — tunables table, notes column (for 003's decision):

```
-| maxBlurPx | 24 | logical px at g = 1 |
-| dimStrength | 0.6 | fraction of brightness removed at g = 1 |
-| blurTaps | 16 | compile-time constant in GLSL; 24 is the ceiling |
+| maxBlurPx | 24 | logical px at g = 1. Metal instead: blurSpread = 0.12 px per px of gap → 26.8 px at 35° on a 390-wide screen. 003 decides which semantics to keep. |
+| dimStrength | 0.6 | fraction removed at g = 1. Metal instead: darkening = 0.015 per px of blur radius → 0.40 removed at the same point. 003 decides. |
+| blurTaps | 16 | compile-time constant in GLSL; 24 is the ceiling. Metal: clamp(int(radius·2), 6, 32) adaptive taps, Vogel disk, per-pixel hash rotation. |
```

## Commands

Run from the repo root, in this order (001 is committed as `4c0e95d`; no
baseline step; the main session commits after review).

```sh
# 1. Write the three files in ## Files (shader, one-hunk edit, new test).

# 2. Format, analyze, test. `dart format` should report 0 changed.
dart format lib test
flutter analyze
flutter test

# 3. Compile the shader through impellerc (Metal runtime stage).
flutter build macos --debug
ls build/macos/Build/Products/Debug/iphoneduo_animation_flutter.app/Contents/Frameworks/App.framework/Resources/flutter_assets/shaders/

# 4. Run once with a launch tilt, as in 001 (background, ~90 s, grep, kill).
flutter run -d macos --dart-define=TILT_DEGREES=-20 > "$SCRATCH/duo_fold_run.log" 2>&1
grep -n "Flutter run key commands\|Error\|Exception\|impellerc" "$SCRATCH/duo_fold_run.log"
pkill -f "flutter run -d macos"; pkill -x iphoneduo_animation_flutter

# 5. Confirm the change set.
git status --short
```

`$SCRATCH` stands for the implementer's scratchpad directory — substitute
the real path.

## Acceptance

0. **(carried from 001) `FlutterFragCoord()` is logical px on Impeller.**
   Main session / human, on the built-in Retina display: run
   `flutter run -d macos --dart-define=TILT_DEGREES=0`, confirm the panel's
   last line reads `dpr 2.00`, take a window screenshot (`screencapture -l
   <windowid> shot.png`, or the main session's screenshot tooling). PASS:
   the 2 px white frame is on all four window edges and there is no black
   region; pixel probes `(width − 1, height / 2)` and `(width / 2,
   height − 1)` are white. FAIL: the interface occupies only the top-left
   quarter at 2× with black elsewhere. Then `--dart-define=TILT_DEGREES=-20`:
   the LEFT border stays intact along its full height (hinge left) and black
   wedges appear at the top-RIGHT and bottom-RIGHT corners; slider to +20:
   mirrored. Record the result in `## Review`. If FAIL, do not judge the
   reprojection; the shader must receive logical px — report to the
   architect rather than scaling on the Dart side.
1. `flutter analyze` prints `No issues found!`.
2. `flutter test` prints `All tests passed!` — 10 tests (7 from 001 in
   `widget_test.dart`, 3 in `reprojection_test.dart`).
3. `flutter build macos --debug` ends with `✓ Built …/iphoneduo_animation_flutter.app`
   and the `ls` lists `duo_fold.frag`.
4. `git status --short` shows exactly: `M shaders/duo_fold.frag`,
   `M lib/fold/fold_parameters.dart`, `?? test/reprojection_test.dart`,
   `?? docs/plans/002-reprojection.md` (plus `M` on it once the report is
   appended). Nothing else.
5. Visual, main session / human, `flutter run -d macos
   --dart-define=TILT_DEGREES=-20` at the default 800×600 window (the panel
   prints the size; for other sizes use `h_w = H·W·sin 20° / 4031.5`):
   a. Left border (hinge) intact top to bottom; left-edge content identical
      to the untilted view.
   b. Two black right triangles along the top and bottom edges, each with
      its thin end at the left corner and ≈ 41 px tall at the right edge,
      straight hypotenuses.
   c. At the right edge a black strip ≈ 6 px wide with the interface's
      white right border just inside it.
   d. Grid: vertical lines remain vertical, slightly wider spaced near the
      hinge and slightly tighter toward the right; horizontal lines converge
      toward the vertical middle as they approach the right edge (keystone).
      Tiles near the right edge look slightly smaller, not larger.
   e. Slider to +20: exact mirror (hinge right, wedges top-left and
      bottom-left). Slider to 0 or Center: identical to 001's pass-through.
   f. Sweep the slider −35…+35: continuous, no popping, no magenta, no
      console exception. At ±35 the wedges reach ≈ 68 px on 800×600.
   g. Resize the window: wedges rescale per the formula; the hinge column
      never shows black.
6. `## Implementation report` appended to this file.

## Out of scope

- Blur, dimming, tap loops, any use of `uMaxBlurPx`/`uDimStrength` beyond
  the sentinel (003).
- Sensors, `flutter_rotation_sensor`, platform channels (004).
- Any edit to `lib/fold/fold_effect.dart`, `lib/fold/fold_shader.dart`,
  `lib/main.dart`, `lib/demo/*`, `lib/motion/*`, `test/widget_test.dart`,
  `pubspec.yaml`, `context.md`, `CLAUDE.md`, `.claude/`, `android/`,
  `ios/`, `macos/`.
- Changing the uniform table, the shader's header comment block, or the
  early-exit / guard thresholds (`1e-5`, `1e-3`).
- Re-adding the hinge marker; changing `FilterQuality`.
- Committing or pushing; the main session commits after review.
- Applying the proposed `context.md` hunks (routed by the main session).

## Implementation report

STATUS: DONE

Files written:
- `test/reprojection_test.dart`

Files edited:
- `shaders/duo_fold.frag` — full replacement per the plan: perspective
  reprojection (`G`, `E`, `depth`/`t`/`hit`), the two Metal guards
  (`tilt < 1e-5` identity, `depth <= 1e-3` black), black-outside decided on
  `hit` in logical px (not `uv`), alpha forced to 1, hinge marker removed,
  parameter sentinel kept.
- `lib/fold/fold_parameters.dart` — one-hunk edit: `blurTaps` doc comment
  updated to say the GLSL constant arrives in 003, not that it exists now.

Deviations from plan: none. Every file matches the plan's blocks verbatim
(re-diffed after writing).

Self-fixes applied: none — no analyzer issues, no compile errors, no test
failures on the first run.

Command results:
```
dart format lib test    — Formatted 10 files (0 changed)
flutter analyze         — No issues found!
flutter test            — All tests passed! (10/10: 7 in widget_test.dart,
                           3 in reprojection_test.dart)
flutter build macos --debug
                         — ok: "✓ Built build/macos/Build/Products/Debug/iphoneduo_animation_flutter.app"
ls .../flutter_assets/shaders/
                         — duo_fold.frag  ink_sparkle.frag  stretch_effect.frag
flutter run -d macos --dart-define=TILT_DEGREES=-20
                         — rendered first frame (DevTools URI printed,
                           "Flutter run key commands." reached), then killed
                           via pkill per instructions. grep output:
                             8:Flutter run key commands.
                           No Error/Exception/impellerc lines matched. As in
                           001, the log also shows a benign "Failed to
                           foreground app; open returned 1" line — this
                           sandbox has no active window server for `open`;
                           unrelated to the build or shader compile.
git status --short      — exactly:
                            M lib/fold/fold_parameters.dart
                            M shaders/duo_fold.frag
                            ?? docs/plans/002-reprojection.md
                            ?? test/reprojection_test.dart
                           Matches Acceptance 4. Nothing under android/,
                           ios/, macos/, or any file listed in Out of scope.
```

Open questions for architect:
1. Acceptance item 0 and Acceptance 5 (visual: wedge geometry, keystoning,
   dpr 2.00 confirmation, slider sweep −35…+35) require an actual on-screen
   window; this execution environment is headless (no window server for
   `open` to foreground the app), so those checks were not performed here.
   Left for the main session / human with `flutter run -d macos
   --dart-define=TILT_DEGREES=-20` and, for item 0, `TILT_DEGREES=0` first,
   exactly as the plan's own wording anticipates.
2. `test/reprojection_test.dart`'s three pixel-probe tests passed on the
   first run with no adjustment to the hand-derived hit points or margins —
   no discrepancy to flag against the `## Math` derivation.

## Review

STATUS: ACCEPTED

The code is correct against `context.md` and against the Metal original,
and every automatable check passes. No screenshot will ever come from this
sandbox (`screencapture` and `osascript` both fail for lack of a window
server / Screen Recording grant, and that is a property of the environment,
not of a phase), so the visual items are closed as follows: discharged by
the offscreen pixel probes where the probes actually exercise the claim,
converted into a concrete test for the next plan where a test can reach it,
and otherwise placed on the single human checklist in section 5 — to be run
on the physical iPhone, which is the validation target from now on.

### 1. Diff against `4c0e95d`, checked against the plan

Method: re-extracted the plan's code blocks and `diff`ed them against the
working tree; `git diff 4c0e95d` for tracked files; `git ls-files --others`
for new ones.

| Path | Result |
|---|---|
| `shaders/duo_fold.frag` | byte-identical to the plan block |
| `test/reprojection_test.dart` | byte-identical to the plan block |
| `lib/fold/fold_parameters.dart` | exactly the one hunk (3 comment lines), nothing else |
| `docs/plans/002-reprojection.md` | append-only: report added, 0 lines removed |
| any other tracked file | unchanged (`git diff --name-only 4c0e95d` lists only the three above) |
| untracked | only `test/reprojection_test.dart` and this plan |

Reported deviations: none. Self-fixes: none reported, none found.

### 2. Independent verification (not taken from the report)

- `flutter analyze` in the repo: `No issues found!`.
- `flutter test --timeout 60s` in the repo: 10/10, including the three
  reprojection probes.
- Built app carries `flutter_assets/shaders/duo_fold.frag` at 5336 bytes —
  the same size as the `--sksl --runtime-stage-metal` stage produced from
  the plan's GLSL during the dry-run, so the shipped stage is this shader.
- Shader vs `context.md` and vs `DuoFold.metal`, re-read from the working
  tree rather than the plan:
  - Uniform block unchanged: `uSize(0,1) uAngle(2) uEyeDistPx(3)
    uMaxBlurPx(4) uDimStrength(5)`, `uTex` sampler 0; Dart side untouched
    (`git diff` shows no change to `fold_effect.dart`), so the six
    `setFloat` calls still match.
  - `xh = uAngle > 0 ? uSize.x : 0`, `u = p.x − xh`,
    `G = (xh + u·cos tilt, p.y, |u|·sin tilt)`, `E = (uSize/2, D)`,
    `t = E.z/(E.z − G.z)`, `hit = E.xy + (G.xy − E.xy)·t` — each line is
    the `context.md` reference line, and `G` equals Metal's
    `glass = (hingeX + side·d·cos, p.y, d·sin)` because `side·d = u`,
    `d = |u|`.
  - Black on `hit ∉ [0,W]×[0,H]` (inclusive, as Metal with radius 0);
    never relies on sampler clamping. Alpha forced to 1 (Metal `opaque()`).
  - Guards `tilt < 1e-5` (identity) and `depth ≤ 1e-3` (black) are Metal's.
  - Impeller dialect: `#include <flutter/runtime_effect.glsl>`,
    `FlutterFragCoord()`, two-argument `texture()`, `any(lessThan(…))`
    ES 3.0 built-ins, no loops, no dynamic indexing, no `gl_FragCoord`.
  - No blur, no dim, no tap loop: phase boundary respected.
- Hand-recomputed one probe from scratch as a spot check: θ = +20°,
  pixel (0, 5) → `u = 0.5 − 400 = −399.5`, `G.z = 399.5·0.34202 = 136.64`,
  `t = 2015.748/1879.11 = 1.07272`, `hit.y = 150 + 1.07272·(5.5 − 150)
  = −5.0` → black; the test asserts black at (0, 5) for +20° and it
  passes.

### 3. Runtime observation and why there is no screenshot

`flutter run -d macos --dart-define=TILT_DEGREES=-20` reached "Flutter run
key commands." with no `Error`/`Exception`/`impellerc` lines: the Metal
stage loaded and frames were produced offscreen. The coordinator's
screenshot attempt failed deterministically: `screencapture` in display,
rect and window modes returns "could not create image" (exit 1), and
`osascript` to System Events returns −1743 (not authorised for Apple
events); "Failed to foreground app; open returned 1" on every run confirms
there is no Aqua session for the app. This will not change in later
phases; macOS can compile and execute the shader here but cannot show it.

### 4. Disposition of every acceptance item

The pixel-probe tests run on `flutter_tester` (Skia). They execute the
same GLSL with the same uniform values the app sends, through the same
`AnimatedSampler` → `FragmentShader` path, and read the result back
through `RepaintBoundary.toImage`. What differs from the device is only
the backend: on Skia `FlutterFragCoord()` is `gl_FragCoord` rewritten to
local coordinates; on Impeller it is the vertex-stage `_fragCoord`.

| Item | Claim | Discharged by | Status |
|---|---|---|---|
| 1 analyze | clean | my run | done |
| 2 tests | 10/10 | my run | done |
| 3 build | Metal stage compiled and bundled | my run (5336 B) | done |
| 4 change set | exactly three files + plan | `git status` | done |
| 6 report | appended | read | done |
| 5a hinge column intact | `t → 1` at `u → 0` | probes (0,0) (0,150) (0,299) red at −20°; (399,·) blue at +20° | done |
| 5b wedge triangles, height `H·W·sin θ/(2D)` | rows 0–9 / 290–299 black at the lifted edge, rows 20 / 280 content | probes | done (size proven at 400×300; the 800×600 and phone numbers follow from the same formula) |
| 5e mirror and identity | ±20° symmetric; θ = 0 identity | probes | done |
| 5c ≈ 6 px black strip at an 800-wide lifted edge | bounds test on `hit.x` | the same bounds test that the wedge probes exercise on `hit.y`; the strip width is a consequence of proven maths | discharged as maths; cosmetic confirmation → checklist H3 |
| 5d keystone / minified toward the lifted edge | `hit.y = H/2 + t(p.y − H/2)`, `t` increasing with `|u|` | the (200,150) probe verifies the horizontal map (hit.x 188 / 213); the vertical map is what the wedge probes measure | discharged as maths; visual impression → checklist H3 |
| 5f slider sweep continuous, no popping | maths continuous in θ; early exit at `1e-5` equals the limit | analytic; unobserved | checklist H4 |
| 5g window resize | N/A on the phone | — | dropped: the target is now the iPhone, whose size does not change |
| **0** `FlutterFragCoord()` logical px **on Impeller** | `_fragCoord = position` in the sampler's identity-transformed local space | **not** reachable by any `flutter test` (Skia); the source argument stands but is unobserved | **open** → checklist H1 (first iPhone run) + the dpr-2 test in section 6, which closes the Dart/GLSL half of the claim |

Why accept with item 0 open: the failure signature, if the claim were
wrong, is not subtle — at dpr 2 or 3 the interface would occupy the
top-left quarter/ninth of the screen at 2×/3× with black elsewhere. It
cannot be missed on the first device run, and it does not compound with
anything until blur offsets exist. The checklist below makes it the first
thing the human looks at.

### 5. Human checklist — physical iPhone, run once, any phase from 003 on

Device `00008120-000278980AE3601E` (iOS 26.5.2, wireless). Hold the phone
upright in portrait, screen facing you, at normal reading distance. Record
PASS/FAIL per line in the `## Review` of whichever phase is under review
when this is run; lines already passed need not be repeated later.

```
H0  flutter run -d 00008120-000278980AE3601E --dart-define=TILT_DEGREES=0
    Wait for the first frame. The panel's last line shows "dpr 3.00"
    (or 2.00) and the logical size, e.g. "393×852 lpx". Note both.

H1  [closes acceptance 0]  At θ = 0 the demo interface fills the screen
    edge to edge: the 2 px white frame is visible on all four screen edges
    (top under the status bar, bottom under the panel), nothing is drawn
    at 2×/3× in the top-left corner, no black region anywhere.
    FAIL looks like: the interface shrunk into the top-left quarter/ninth
    with black filling the rest. If FAIL, stop and report; do not judge
    anything below.

H2  [5a, 5b]  Slider to −20 (panel reads "θ -20.0°  hinge left"):
    the LEFT border and the content along the left edge are unchanged;
    two black right triangles appear along the TOP and BOTTOM edges, thin
    at the left, widest at the right edge, with straight hypotenuses.
    Expected height at the right edge = H·W·sin 20° / (2·D):
    for 393×852 with D = 2015.7 → ≈ 28 px; for 390×844 → ≈ 28 px.
    (If FoldParameters later adopts 6 px/mm, D = 1920 and the height is
    ≈ 30 px.) A ruler is not needed: "about the height of the status
    bar text" is the right order of magnitude.

H3  [5c, 5d]  Still at −20: the right border of the white frame is still
    visible at the right screen edge (no black column on a phone-width
    screen); tiles and grid cells near the RIGHT edge look slightly
    smaller than those near the left; horizontal grid lines bend toward
    the vertical middle as they approach the right edge (keystone);
    vertical grid lines stay vertical.

H4  [5e, 5f]  Slider to +20: exact mirror (right border intact, wedges at
    top-left and bottom-left). Sweep the slider slowly −35 … +35: motion
    is continuous, no popping, no flicker, no magenta anywhere; at ±35 the
    wedges are ≈ 47 px tall. Press Center: identical to H1.

H5  Console (the flutter run terminal): no exception, no RangeError, no
    impellerc line during any of the above.
```

### 6. Concrete test addition for the 003 plan (dpr-2 offscreen probes)

The only part of item 0 a test can reach is the Dart/GLSL contract at
dpr ≠ 1: the `AnimatedSampler` image is `ceil(dpr·W) × ceil(dpr·H)`
physical px while `uSize` is logical and `FlutterFragCoord()` is local
px. The 003 plan will add to `test/reprojection_test.dart`, verbatim:

1. Change `_render` to `Future<ByteData> _render(WidgetTester tester,
   double degrees, {double dpr = 1.0})`; set
   `tester.view.devicePixelRatio = dpr` and
   `tester.view.physicalSize = Size(_w * dpr, _h * dpr)` (logical size
   stays 400×300); call `boundary.toImage(pixelRatio: dpr)`.
2. Change `_pixel` to take the image width: `_pixel(bytes, x, y, {int
   stride = 400})` with `i = (y * stride + x) * 4`.
3. Add one test, `'dpr 2: identical probes at physical 2× coordinates'`:
   `px = await _render(tester, -20, dpr: 2.0)`, then every −20° assertion
   from the existing test repeated with `x`, `y` doubled and
   `stride: 800`, i.e. `(0,0) (0,300) (0,598)` red, `(798,0) (798,10)`
   black, `(798,40) (798,300) (798,560)` blue, `(798,588) (798,598)`
   black, `(400,300)` red.
   PASS proves the shader receives logical `uSize`, samples a 2× image
   correctly, and that the wedge geometry is dpr-invariant in logical px.
   FAIL with black in the lower-right three quarters would reproduce the
   item-0 failure signature on the Skia path, which would mean the Dart
   side (not Impeller) is at fault.

This test does not observe Impeller; H1 remains the closing evidence for
item 0 on the device.

### 7. Answers to the implementer's open questions

1. Correct — items 0 and 5 were never the implementer's to perform; their
   disposition is section 4, the human part is section 5.
2. Noted: the probes matched the derivation on first run; no correction to
   `## Math`.

### 8. Proposed `context.md` hunks (main session routes to the implementer)

Hunks A and B from `## Math` above, verbatim, plus:

Hunk C — gotchas, append:

```
+- `flutter test` runs on Skia (`flutter_tester`). Pixel-probe tests there
+  validate the GLSL maths and the uniform binding, but not Impeller's
+  `FlutterFragCoord()` provenance; the closing evidence for the
+  logical-px claim is the first run on the iPhone (002 review, checklist H1).
+- This sandbox has no window server: `screencapture`/`osascript` fail, and
+  a macOS `flutter run` draws offscreen only. macOS compiles and executes
+  the shader; it cannot show it. Visual acceptance is a human with the
+  iPhone (device 00008120-000278980AE3601E).
+- In a widget-test fixture, a childless `ColoredBox` under a `Row` lays out
+  at height 0 and rasterises nothing; use `CrossAxisAlignment.stretch` (or
+  `SizedBox.expand`) or every probe reads opaque black.
```

Hunk D — the last gotcha bullet, replace:

```
-- macOS desktop (Impeller/Metal by default since 3.47) is the device-free
-  validation target; its build compiles the same `--runtime-stage-metal`
-  stage as iOS.
+- Build/compile validation: `flutter build macos --debug` (device-free;
+  compiles the same `--runtime-stage-metal` stage as iOS). Visual and
+  motion validation: `flutter run -d 00008120-000278980AE3601E` with a
+  human holding the phone and reporting against the plan's checklist.
```

For the g-normalisation change (Hunk A): the recommended semantics for the
blur phase are Metal's — `radius = blurSpread · gap` in logical px with
`blurSpread` a tunable (Metal 0.12), `attenuation = max(1 − darkening ·
radius, 0)` with `darkening` a tunable (Metal 0.015 per px of radius) —
which makes blur and dimming scale with tilt magnitude and with screen
size as the physical model says. The provisional `g = gap / (W ·
sin(maxTiltRad))` in Hunk A is only the minimal correction if the
`maxBlurPx`/`dimStrength` names are kept; the blur phase's plan makes that
call and, if names change, bumps the uniform table (slots 4 and 5 stay
floats either way).

### 9. Notes for the next plan

- The next plan is not necessarily blur: a fidelity assessment against the
  whole source repo and the phase order are being delivered alongside this
  review, on the user's instruction. Whatever the next phase is, it must
  (a) add the dpr-2 test of section 6, (b) carry checklist H0–H5 as its
  device acceptance, and (c) switch the run target to the iPhone.
- Uniform slots 4 and 5 are consumed for the first time in the blur phase;
  drop the parameter sentinel's clauses for them only if the blur/dim path
  reads both unconditionally (otherwise keep the sentinel).
- The Metal kernel for the blur phase: Vogel disk, `taps = clamp(int(radius·2),
  6, 32)`, `r_i = radius·sqrt((i + 0.5)/taps)`, `a_i = i·2.39996 +
  hash21(position)·2π`, taps that leave the interface contribute black,
  `radius < 0.5` single-sample path, whole-kernel-outside test `any(hit <
  −radius) || any(hit > size + radius)`. Impeller needs a constant loop
  bound: loop to the ceiling and skip by `i < taps`.
- `test/reprojection_test.dart` stays as the geometry regression; the blur
  phase adds probes for radius and dimming and must keep the 002 probes
  passing (pick probes ≥ radius + 5 px from boundaries).
