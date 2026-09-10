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
| `CMMotionManager` attitude | `FoldMotionModel.swift` ported verbatim into `ios/Runner/AppDelegate.swift` (`FoldMotionBridge`), streamed over `EventChannel` `duo_fold/motion/tilt`; `MethodChannel` `duo_fold/motion` for `isAvailable`/`recalibrate`. Dart `FoldMotionModel` only switches between the stream and the slider. iOS only; chosen in 003 for exact fidelity. |
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
- Eye distance is converted from mm to logical px on the Dart side with the
  original's constant: `pointsPerMm = 6` (Flutter logical px equal iOS
  points; ≈ 6 pt/mm on current panels), so the default eye is 1920 px.
  Do **not** use `devicePixelRatio` for this.
- x grows right, y grows down, z grows **toward the viewer**. Interface
  plane is z = 0. Eye E = (W/2, H/2, D) where D = eyeDistancePx.
- Tilt angle θ (radians). Sign convention: θ > 0 means the **right** edge
  is the hinge (the left edge lifts toward the viewer). Hinge x-coordinate
  `xh = θ > 0 ? W : 0`. The native motion bridge produces θ in this
  convention (the original's `atan2(n·screenX, n.z)` after resolving the
  rotation-matrix handedness against gravity). θ is not clamped; only the
  manual slider is bounded (−45…45°, 0.5° steps), as in the original.

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
r   = blurSpread · gap              // blur radius in logical px; blurSpread = 0.12.
                                    // The ABSOLUTE gap, as in DuoFold.metal: no
                                    // normalisation, because there is no maximum tilt
                                    // any more — 003 deleted maxTiltDeg/maxTiltRad.
                                    // Settled in the 003 review; 005 implements it.
```

- If `uv` is outside [0,1]² → output black (alpha 1). Do not rely on
  sampler clamping; it smears the border.
- Blur: golden-angle (Vogel) disk of radius `r`, tap count
  `clamp(int(r·2), 6, 32)` evaluated under a constant GLSL loop bound; the
  005 plan fixes the bound and the offset schedule. Taps that land outside
  [0,1]² contribute black, not clamped edge.
- Dim: `rgb *= max(1 − darkening · r, 0)` with `darkening = 0.015` (Metal's
  `attenuation`). Slots 4 and 5 carry `blurSpread` and `darkening` from 005;
  the uniform table is renamed by that plan, not before it.

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
| eyeDistanceMm | 320 | Swift `eyeDistanceMillimeters` |
| pointsPerMm | 6 | Swift `pointsPerMillimeter`; eye = 1920 px |
| maxBlurPx | 24 | placeholder holding uniform slot 4 since 003. In 005 the slot becomes `blurSpread = 0.12` with the Metal semantics: `radius = blurSpread · gap`. |
| dimStrength | 0.6 | placeholder holding uniform slot 5 since 003. 005 adopts `attenuation = max(1 − darkening · radius, 0)`, `darkening = 0.015`. |
| (blur taps) | — | the blur phase uses the original's `clamp(int(radius·2), 6, 32)` under a constant loop bound; no Dart tunable |

## Package targets

```
flutter_shaders: 0.1.3       # AnimatedSampler only; pinned in 001 (latest on pub.dev)
# No sensor package: motion is the original Swift in ios/Runner (003).
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
    fold_motion_channel.dart # MotionChannel + PlatformMotionChannel (method/event channels)
    fold_motion_model.dart   # mode logic: native stream vs manual slider; recalibrate
ios/Runner/AppDelegate.swift # FoldMotionBridge: FoldMotionModel.swift verbatim + channels
  demo/
    demo_content.dart        # DemoContentView port: root, header, chips, hero
    demo_sections.dart       # DemoContentView port: stat grid, Recent list
    demo_style.dart          # iOS light system colours + text styles
    control_panel.dart       # floating panel
shaders/
  duo_fold.frag
docs/
  plans/                     # 001-scaffold.md … 005-polish.md
```

## Gotchas already known

- `AnimatedSampler` re-rasterises its child every frame the shader
  repaints. Fine for a phone screen; keep the tap count modest.
- On iOS the Core Motion rotation-matrix handedness must be resolved at
  runtime against the gravity vector so the hinge lands on the correct
  side; the Swift repo notes it doesn't trust the docs for this. Done in
  `FoldMotionBridge` since 003, in Swift, not in Dart: `rowsScore` vs
  `columnsScore` against normalised gravity, latched once when they differ
  by more than 0.2. Dart receives θ already in the sign convention above
  and must never re-derive or re-sign it.
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
- Build/compile validation since 003: `flutter build ios --debug
  --no-codesign` (device-free; compiles the Dart, the Swift bridge and the
  same `--runtime-stage-metal` shader stage, and links CoreMotion). Visual
  and motion validation: `flutter run -d 00008120-000278980AE3601E` with a
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
- 3.47 iOS template is UIScene-based: app-level channels are created in
  `didInitializeImplicitFlutterEngine` from
  `engineBridge.applicationRegistrar.messenger()`. `SceneDelegate.swift`
  stays empty.
- A debug iOS build's `Runner` executable is a stub that loads
  `Runner.debug.dylib`; check linked frameworks and symbols on the dylib.
- `CMMotionManager` device motion needs no Info.plist usage key.
- Widget-test text uses a fixed-width test font (glyph width = font size);
  size rows for it or they overflow in tests only.
- The zero pose is latched on the first Core Motion sample after launch or
  after Recalibrate, in `FoldMotionBridge`. Launching with the phone flat on
  a desk calibrates to that pose; θ is then measured from it and `atan2`
  degenerates as the relative pitch approaches 90°. Hold the phone as you
  intend to use it before the first frame, or recalibrate.
- The handedness latch is resolved from live gravity data at the first
  decisive sample and is never reset. A wrong latch computes the inverse
  relative rotation, i.e. it shows up as θ inverted and nothing else — which
  is why the device sign check is repeated after a cold relaunch in a
  different attitude.
- The reference pose and the latch survive a Dart hot restart (they live in
  the native bridge); re-listening only replaces the event sink. Tap
  Recalibrate after a hot restart.
- The demo screen is pinned to the iOS **light** appearance (004). It hard-codes
  the light values of the UIColor semantic names and reads `Theme.of(context)`
  nowhere, so theme changes cannot move the reference screen. `MaterialApp`'s
  theme is light and seeded with `#007AFF` from 004 on.
- `.background.secondary` (the stat tiles and the Recent list) is `#F2F2F7` in
  light appearance — the same colour as the page. The near-invisible cards are
  the original's, not a porting bug.
- The content is taller than the screen at 390x844. It is laid out at natural
  height in a `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`
  and clipped at the bottom, which is what SwiftUI's overflowing top-aligned
  `VStack` plus `ContentView`'s `.clipped()` does. Do not shrink it to fit.
- SwiftUI's `.firstTextBaseline` uses a shape's **bottom edge** as its baseline,
  so `DemoContentView`'s avatar sits high; Flutter's `CrossAxisAlignment
  .baseline` top-aligns baseline-less children instead, so the offset is an
  explicit `DemoHeader.textTopInset = 29.7`.
- SwiftUI `Text` boxes come from the font's line height, not from the HIG
  "line height" column; leave `TextStyle.height` null in the demo. SF's system
  font metrics are ascent ≈ 0.953 em, descent ≈ 0.228 em (line box ≈ 1.181 em);
  the ascent is what `DemoHeader.textTopInset = 44 − 0.953 × 15 = 29.7` is
  derived from, so do not "round" it away.
