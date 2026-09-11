# DuoFoldAnimationFlutter

A Flutter port of [DuoLikeAnimation](https://github.com/elijah-semyonov/DuoLikeAnimation)
by [Elijah Semyonov](https://github.com/elijah-semyonov) — the "iPhone Duo"
frosted-glass fold effect, rebuilt with a single fragment shader on Impeller.

The phone becomes a pane of frosted glass. The interface stays fixed on the
plane the screen occupied at rest; tilt the phone and you see the interface
through a tilted, slightly cloudy window — reprojected by perspective,
blurred and dimmed in proportion to how far the glass has moved from the
interface, black wherever a ray misses it.

<!-- TODO: replace with a real recording -->
<!-- ![demo](docs/demo.gif) -->

## How it works

| | SwiftUI original | This port |
|---|---|---|
| Shader | Metal `layerEffect` | GLSL fragment shader, compiled by `impellerc` ([`shaders/duo_fold.frag`](shaders/duo_fold.frag)) |
| Feeding the UI into the shader | `layerEffect` samples the view | [`AnimatedSampler`](https://pub.dev/packages/flutter_shaders) rasterises the child each frame and binds it as a sampler |
| Device attitude | `CMMotionManager` | Same motion model, ported to Swift in the iOS runner and to Kotlin in the Android runner (`TYPE_GAME_ROTATION_VECTOR` + gyroscope), both streamed over the same `EventChannel` |
| Tunables | `FoldParameters` | [`FoldParameters`](lib/fold/fold_parameters.dart) — field for field |

Per pixel, the shader casts a ray from a fixed eye (320 mm from the screen)
through the pixel's position on the rotated glass, extends it to the
interface plane, and samples there with a disk blur whose radius grows with
the glass–plane gap. The full model — coordinate conventions, the
reprojection math, the blur kernel and the uniform layout — is worked through
in the plan files under [`docs/plans/`](docs/plans/), starting with
[`002-reprojection.md`](docs/plans/002-reprojection.md) and
[`005-blur-dim.md`](docs/plans/005-blur-dim.md).

### Layout

```
shaders/duo_fold.frag        the effect: reprojection, disk blur, darkening
lib/fold/                    FoldEffect widget, FoldParameters, shader loader
lib/motion/                  tilt source: Core Motion stream or manual slider
lib/demo/                    the interface behind the glass + control panel
ios/Runner/AppDelegate.swift FoldMotionBridge (Core Motion → EventChannel)
android/app/src/main/kotlin/…/FoldMotionBridge.kt
                             FoldMotionBridge (SensorManager → EventChannel)
docs/plans/                  design notes and review log for each phase
test/                        shader golden tests, blur/dim and widget tests
```

## Running it

Requires Flutter 3.47 or later (Impeller is the default renderer).

```sh
flutter pub get
flutter run -d <your-iphone-or-android-phone>
```

Run it on a physical phone: the effect is driven by the device's attitude,
which the simulator and emulator cannot provide. The floating panel at the
bottom has:

- **Recalibrate** — re-zeroes the rest pose to the phone's current attitude.
  The first sample after launch is used as the zero pose automatically.
- **Manual tilt** — switches to a −45°…45° slider so you can inspect the
  effect without moving the phone. This is also the fallback wherever
  device motion is unavailable.

### Platform support

| Platform | Shader | Motion-driven tilt |
|---|---|---|
| iOS | ✅ | ✅ Core Motion (`ios/Runner/AppDelegate.swift`) |
| Android | ✅ Impeller (Vulkan, GLES fallback) | ✅ `TYPE_GAME_ROTATION_VECTOR` + `TYPE_GYROSCOPE` (`android/app/src/main/kotlin/…/FoldMotionBridge.kt`); falls back to the slider on devices without a gyroscope |
| macOS | ✅ | manual slider only (no attitude sensor) |

The shader and the Dart code have no platform-specific paths; the two native
bridges implement the same `duo_fold/motion` channels with the same model
(reference pose latched on the first sample, 0.7 smoothing, 40 ms gyro
prediction, θ > 0 ⇔ right edge is the hinge).

## Tuning

`FoldParameters` mirrors the original's tunables:

| Field | Default | Meaning |
|---|---|---|
| `eyeDistanceMm` | 320 | Viewer distance from the untilted screen |
| `pointsPerMm` | 6 | Logical px per mm on current phone panels (deliberately not `devicePixelRatio`) |
| `blurSpread` | 0.12 | Blur radius gained per logical px of glass–plane gap |
| `darkening` | 0.015 | Light lost per logical px of blur radius |

## Tests

```sh
flutter analyze
flutter test
```

The reprojection and blur/dim tests render the real shader through
`AnimatedSampler` and check pixel values against the reference math, so they
need a Flutter version that can compile shaders for the test runner.

## Project notes

This port was built in phases (`docs/plans/001` … `007`), each with a design
plan, an implementation report and a review. The plan files are kept in the
repo because they document *why* the shader and the motion model look the way
they do, including the parity sweep against the Metal original. The demo
content behind the glass is a small portfolio page; swap
`lib/demo/demo_content.dart` for anything you like — everything under
`FoldEffect` is rasterised, so any widget tree works (except platform views).

## License

MIT — see [LICENSE](LICENSE). The shader, fold parameters and motion model are
derived from DuoLikeAnimation (MIT, © 2026 Elijah Semyonov). The Geist
typeface is © The Geist Project Authors, SIL Open Font License 1.1
([`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)).
