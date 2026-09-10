# Fidelity assessment — what exists vs. elijah-semyonov/DuoLikeAnimation

Written after reading every file in the source repo (`DuoFold.metal`,
`FoldEffect.swift`, `FoldMotionModel.swift`, `ContentView.swift`,
`DemoContentView.swift`, `DuoLikeAnimationApp.swift`, `README.md`) and
after the 002 review. The user's bar is "exactly like this", so the
original is the reference from here on and `context.md` is corrected to it
where the two differ.

## 1. Is there a fidelity defect in the 002 shader beyond the missing phases?

**In the shader: no.** The reprojection in `shaders/duo_fold.frag` is the
Metal `duoFold` kernel with the blur and darkening removed — same glass
placement, same eye, same ray, same bounds test, same guards, same alpha
handling. The pixel probes in `test/reprojection_test.dart` pin it.

**In what feeds the shader: one constant.** `FoldParameters.eyeDistancePx`
is `320 mm × 160/25.4 = 2015.7 px`; the original uses
`320 mm × 6 pt/mm = 1920 pt`. Flutter logical px equal iOS points, and
6 pt/mm is the closer figure for current iPhone panels (460 ppi @3x). The
5 % larger eye distance makes every wedge and every perspective shift
≈ 5 % smaller than the original. Fixed in 003 (`pointsPerMm = 6`).

**In the clamp:** the original never clamps the motion tilt; only the
manual slider is bounded (−45…45°, 0.5° steps). `context.md`'s
`maxTiltDeg = 35` clamp is ours and is removed in 003.

Everything else that makes the current build "not even close" is absence,
not error:

| Original | Status here |
|---|---|
| Reprojection (`DuoFold.metal` geometry) | done (002), verified identical |
| Vogel-disk blur, adaptive 6–32 taps, per-pixel hash rotation, `radius = 0.12 · gap` | missing |
| Darkening `max(1 − 0.015 · radius, 0)` | missing |
| Core Motion attitude → tilt, gravity-resolved handedness, 0.04 s gyro prediction, 0.7 smoothing, recalibrate | missing (manual slider only) |
| ContentView controls: frosted round button, hidden 280 px frosted panel, readout, Recalibrate, Manual-tilt switch, −45…45° slider | different (always-visible panel, −35…35 slider, "Center" button) |
| DemoContentView: light "Today" screen — header with date and avatar, chips, gradient hero card with 12 bars, 2×2 stat tiles, "Recent" list of 4 rows | different (our dark placeholder with six tiles and a grid; the stock counter app was replaced in 001, but not by the original's content) |
| Effect pinned to the full physical screen incl. safe-area insets, content padded by the insets | done (FoldEffect fills the screen, DemoContent applies SafeArea) |

So the user's reading is confirmed: reprojection is faithful; the effect
reads as "not even close" because motion, blur, dimming, the controls and
the content are the original's identity and none of them exist yet.

## 2. Gyroscope

Required, and it is the largest perceptual gap. The original's motion
model is small and self-contained Swift (`FoldMotionModel.swift`, ~110
lines): `CMMotionManager` device motion at 120 Hz in the
`xArbitraryZVertical` frame, a reference pose latched on the first sample
(recalibrate = clear it), the rotation-matrix handedness resolved against
the gravity vector, the tilt as `atan2(normal·screenX, normal.z)` of the
current screen normal in the calibrated frame, extrapolated by
`rotationRate·screenY × 0.04 s`, and an exponential smoothing of 0.7 per
sample.

The most faithful port is to run that Swift verbatim inside the iOS
Runner and stream the result to Dart over an `EventChannel` — the same
sensor, the same reference frame, the same constants, the same handedness
trick, with Dart only choosing between the stream and the slider. A pub
package (`flutter_rotation_sensor`) would give a fused attitude but not
the gravity vector the handedness resolution needs, and would force us to
re-derive the axis conventions; `sensors_plus` would force our own fusion.
Neither can be "exactly like this". `context.md`'s "last resort" ranking
is inverted by the new bar; 003 proposes the hunk.

## 3. Phase order

Recommended, replacing `CLAUDE.md`'s 003–005:

1. **003 motion** — native Core Motion bridge + Dart `FoldMotionModel`
   with the original's mode logic; ContentView's controls (round toggle,
   hidden panel, readout, Recalibrate, Manual-tilt switch, −45…45°
   slider); `pointsPerMm = 6`; clamp removed. Validation moves to the
   iPhone; the human's first look is at the effect following the hand.
2. **004 demo content** — `DemoContentView` ported to pure Flutter,
   light theme, same sections, strings, colours and geometry. Cheap, no
   effect changes, and every later human judgement is then made on the
   original's screen rather than a placeholder.
3. **005 blur + dim** — the Metal kernel exactly: `radius = blurSpread ·
   gap`, Vogel disk with `clamp(int(radius·2), 6, 32)` taps under a
   constant loop bound, per-pixel hash rotation, `radius < 0.5` single
   sample, whole-kernel-outside black, `attenuation = max(1 − darkening ·
   radius, 0)`; `FoldParameters` gains `blurSpread = 0.12`, `darkening =
   0.015`; uniform slots 4/5 renamed. Judged on the original's content.
4. **006 parity sweep** — whatever the human still sees differ:
   materials, transitions, orientation handling, launch-time overrides.

Motion before blur because the user names it as what makes the effect
real, because it is the riskiest port (sign conventions, calibration) and
the human is now in the loop to see it, and because blur has no bearing on
whether the interface "stays put in space". Content before blur because
blur is judged by eye on content, and the original's content is the
reference.

## 4. Validation from now on

`flutter build ios --debug --no-codesign` is the implementer's compile
check (Swift + Dart + Metal shader stage, no device). Visual and motion
acceptance is `flutter run -d 00008120-000278980AE3601E` with a human
holding the phone and reporting against the plan's checklist; each plan's
acceptance lists exactly what to look at, in order. The 002 review's
H0–H5 checklist is carried into 003 unchanged, with the D = 1920 numbers.
