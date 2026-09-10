# context.md — what we are building and why

## The effect (from the source repo README)

The phone becomes a pane of frosted glass. The interface lives on a fixed
plane in the world — the plane the screen occupied at zero tilt. Tilt the
phone about its vertical axis and the interface stays put in space while
the screen shows what you'd see through a tilted, slightly cloudy window:
reprojected by perspective, blurred and dimmed in proportion to how far the
glass has moved from the interface, black wherever a ray misses the
interface entirely.

Model, verbatim in spirit:

- The interface is on plane z = 0.
- The viewer does not move. Eye sits on the plane normal through screen
  centre at a hand-held distance (320 mm default).
- When the device tilts, the glass rotates around the side edge that is
  **farther from the viewer**. That edge stays in the plane; the rest of
  the glass rises toward the eye.
- Per pixel: cast a ray from the eye through that pixel's position on the
  rotated glass, continue to z = 0, sample the interface there with a disk
  blur whose radius grows with the glass–plane gap, dim by the same gap.

Source layout, for reference when reading the Swift:

| Swift file | Role |
|---|---|
| `Shaders/DuoFold.metal` | `layerEffect`: reprojection, blur, darkening |
| `FoldEffect.swift` | `.foldEffect(angle:parameters:)`, `FoldParameters` tunables |
| `FoldMotionModel.swift` | Core Motion: calibrated zero pose, tilt about screen Y, gyro prediction |
| `DemoContentView.swift` | The interface being looked at |
| `ContentView.swift` | Composition + floating panel (recalibrate, manual tilt) |

## Flutter mapping

| Swift / iOS | Flutter |
|---|---|
| Metal `layerEffect` shader | GLSL fragment shader compiled by `impellerc`, loaded via `FragmentProgram.fromAsset` |
| Feeding the rendered subtree into the shader | `AnimatedSampler` from `flutter_shaders` (child rasterised to `ui.Image` each frame, bound with `setImageSampler`) |
| `CMMotionManager` attitude | Preferred: `flutter_rotation_sensor` (game-rotation-vector on Android, `CMDeviceMotion` on iOS). Fallback: `sensors_plus` gyro + accelerometer with our own complementary filter. Last resort: a small `MethodChannel`/`EventChannel` to `CMMotionManager` (`XArbitraryZVertical`) and Android `TYPE_GAME_ROTATION_VECTOR`. The architect chooses in phase 004. |
| `FoldParameters` | `class FoldParameters` (immutable, `copyWith`) |
| `.foldEffect(angle:)` | `FoldEffect(angle: double, params: FoldParameters, child: Widget)` |
| Manual tilt slider / recalibrate panel | Same, plain Flutter widgets |

## Coordinate conventions (both agents use these)

- Work in **logical pixels** in the shader. `uSize` is the logical size of
  the sampled child (the `size` argument of the `AnimatedSampler` builder).
  `FlutterFragCoord()` is the local position of the `drawRect` that used the
  shader (`runtime_effect.vert`: `_fragCoord = position`), i.e. logical px
  from the widget's top-left. Established from source and by the 001
  build/test; on-screen Impeller confirmation is 002 acceptance item 0.
- Eye distance is converted from mm to logical px on the Dart side:
  `pxPerMm = 160 / 25.4` (Flutter logical px are 1/160 in by definition).
  Do **not** use `devicePixelRatio` for this.
- x grows right, y grows down, z grows **toward the viewer**. Interface
  plane is z = 0. Eye E = (W/2, H/2, D) where D = eyeDistancePx.
- Tilt angle θ (radians). Sign convention: θ > 0 means the **right** edge
  is the hinge (the left edge lifts toward the viewer). Hinge x-coordinate
  `xh = θ > 0 ? W : 0`. The motion model is responsible for producing θ in
  this convention after resolving the rotation-matrix handedness against
  gravity (see gotchas).

## Reference math (verified against DuoFold.metal in 002; implementer never alters)

For pixel p = (px, py):

```
if |θ| < 1e-5 → sample p directly (identity); skip the rest
u   = px - xh                       // signed distance from hinge along x
G   = (xh + u·cos|θ|, py, |u|·sin|θ|)   // pixel's position on the rotated glass
if E.z - G.z ≤ 1e-3 → black         // glass at/behind the eye (Metal guard)
t   = E.z / (E.z - G.z)             // ray E→G extended to z = 0
P   = E + t·(G - E)                 // hit point on interface plane
uv  = P.xy / uSize                  // sample coordinate; black if P.xy ∉ [0,W]×[0,H]
gap = G.z                           // 0 at hinge, W·sin|θ| at far edge
g   = gap / (W·sin(maxTiltRad))     // 0..1; = 1 only at the far edge at max tilt.
                                    // PROVISIONAL, 003 finalises. Metal uses the
                                    // absolute gap (radius = blurSpread·gap); the old
                                    // gap/(W·sin|θ|) made blur independent of tilt
                                    // magnitude, which is wrong.
```

- If `uv` is outside [0,1]² → output black (alpha 1). Do not rely on
  sampler clamping; it smears the border.
- Blur radius `r = uMaxBlurPx · g`. Disk blur with N taps (N ≤ 24), taps
  on a golden-angle spiral or a fixed Poisson set; scale offsets by `r`.
  Taps that land outside [0,1]² contribute black, not clamped edge.
- Dim: `rgb *= 1 - uDimStrength · g` (linear is fine for v1; architect may
  swap for a curve in 003).

## Uniform layout (fixed — order matters, indices are what Dart uses)

```
uniform vec2  uSize;           // 0,1  logical size
uniform float uAngle;          // 2    tilt θ, radians, signed per convention
uniform float uEyeDistPx;      // 3
uniform float uMaxBlurPx;      // 4
uniform float uDimStrength;    // 5    0..1
uniform sampler2D uTex;        // sampler 0
```

Adding a uniform = append at the end, bump this table, note it in the plan.

## Tunables (mirror `FoldParameters`)

| Name | Default | Notes |
|---|---|---|
| eyeDistanceMm | 320 | from the Swift default |
| maxBlurPx | 24 | logical px at g = 1. Metal instead: blurSpread = 0.12 px per px of gap → 26.8 px at 35° on a 390-wide screen. 003 decides which semantics to keep. |
| dimStrength | 0.6 | fraction removed at g = 1. Metal instead: darkening = 0.015 per px of blur radius → 0.40 removed at the same point. 003 decides. |
| blurTaps | 16 | compile-time constant in GLSL; 24 is the ceiling. Metal: clamp(int(radius·2), 6, 32) adaptive taps, Vogel disk, per-pixel hash rotation. |
| maxTiltDeg | 35 | clamp on |θ| from the motion model |

## Package targets

```
flutter_shaders: 0.1.3       # AnimatedSampler only; pinned in 001 (latest on pub.dev)
flutter_rotation_sensor: latest   # phase 004, architect confirms
sensors_plus: latest         # fallback only
```

Pin exact versions in `pubspec.yaml` at phase 001 after `flutter pub add`.

## File layout

```
lib/
  main.dart                  # app entry, composes everything
  fold/
    fold_effect.dart         # FoldEffect widget (AnimatedSampler + shader)
    fold_parameters.dart     # FoldParameters
    fold_shader.dart         # loads FragmentProgram once, exposes shader
  motion/
    tilt_source.dart         # TiltSource (ChangeNotifier): theta (rad, signed), isLive
    fold_motion_model.dart   # attitude → θ, calibration, prediction
    manual_tilt.dart         # slider-driven θ source (same interface)
  demo/
    demo_content.dart        # the interface being looked at
    control_panel.dart       # floating panel
shaders/
  duo_fold.frag
docs/
  plans/                     # 001-scaffold.md … 005-polish.md
```

## Gotchas already known

- `AnimatedSampler` re-rasterises its child every frame the shader
  repaints. Fine for a phone screen; keep `blurTaps` modest.
- On iOS the Core Motion rotation-matrix handedness must be resolved at
  runtime against the gravity vector so the hinge lands on the correct
  side; the Swift repo notes it doesn't trust the docs for this. Do the
  same in Dart: on calibration, record which screen edge gravity favours
  and derive the sign of θ from that, not from an assumed axis.
- Platform views under the sampler are not captured. Demo content must be
  pure Flutter.
- Impeller only. Don't reach for `dart:ui` APIs that exist only on Skia.
- Simulator / desktop has no motion data: manual mode must be the default
  when the sensor stream is absent, and a launch-time tilt should be
  settable for screenshots (`--dart-define=TILT_DEGREES=-20`).
- Shader compile errors from `impellerc` surface at `flutter build` /
  `flutter run`, not at `flutter analyze`. The implementer must run a
  build to validate GLSL.
- `AnimatedSampler` compares its builder with `==`; pass a fresh closure
  every build (a method tear-off compares equal and freezes the effect).
- Never cache the shader-loading `Future` in a static: it is bound to the
  zone that created it, and under `flutter test` that is one test's
  FakeAsync zone — later tests wait forever. Cache the loaded instance.
- Inside `testWidgets`, never `await` the shader loader before the first
  `pump()`; the load completes on a microtask that only `pump` flushes.
- Flutter 3.47: the `IMPELLER_TARGET_OPENGLES` uv flip is no longer needed.
- `double.fromEnvironment` does not exist; read `--dart-define` values with
  `String.fromEnvironment` + `double.tryParse`.
- `flutter create --platforms=<x> .` rewrites `.metadata`'s
  `migration.platforms` to only the platforms named. Harmless (nothing
  reads it in 3.47), but expect the diff.
- Build/compile validation: `flutter build macos --debug` (device-free;
  compiles the same `--runtime-stage-metal` stage as iOS). Visual and
  motion validation: `flutter run -d 00008120-000278980AE3601E` with a
  human holding the phone and reporting against the plan's checklist.
- `flutter test` runs on Skia (`flutter_tester`). Pixel-probe tests there
  validate the GLSL maths and the uniform binding, but not Impeller's
  `FlutterFragCoord()` provenance; the closing evidence for the
  logical-px claim is the first run on the iPhone (002 review, checklist H1).
- This sandbox has no window server: `screencapture`/`osascript` fail, and
  a macOS `flutter run` draws offscreen only. macOS compiles and executes
  the shader; it cannot show it. Visual acceptance is a human with the
  iPhone (device 00008120-000278980AE3601E).
- In a widget-test fixture, a childless `ColoredBox` under a `Row` lays out
  at height 0 and rasterises nothing; use `CrossAxisAlignment.stretch` (or
  `SizedBox.expand`) or every probe reads opaque black.
