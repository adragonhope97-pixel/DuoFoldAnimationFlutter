# 006 parity-sweep

## Goal

When this phase is done the port differs from `elijah-semyonov/DuoLikeAnimation`
in nothing a user can see except the four items listed as 007 candidates at the
end of `## Out of scope`. Concretely: the interface is sampled with the same
linear filter `SwiftUI::Layer::sample` uses; the effect switches itself off
below `|angle| > 1e-4` exactly as `FoldEffectModifier`'s `isEnabled:` does; the
floating control panel is the original's control panel — 12 pt row spacing,
`.subheadline.weight(.medium)` readout with a separate degree sign, a systemBlue
borderless Recalibrate button, an iOS switch, an iOS slider with no tick marks,
`.caption2` end labels, a 0.5 s `.snappy` slide-and-fade transition, an
unbordered material — and the 003 debug footer is gone; the home screen says
`DuoLikeAnimation`; the app is pinned to the light appearance it hard-codes.
No shader code, no uniform, no tunable, no motion code and no demo-content
geometry changes in this phase.

## Decisions

Re-verified against freshly fetched sources (`ContentView.swift`,
`FoldEffect.swift`, `DuoLikeAnimationApp.swift`, `DemoContentView.swift`,
`FoldMotionModel.swift`, `DuoFold.metal`, `project.pbxproj`,
`AccentColor.colorset/Contents.json`, `Docs/demo.png`), not against the 005
review's summary.

1. **`FilterQuality.linear`.** Confirmed: `layer.sample` in `DuoFold.metal` is
   SwiftUI's `metal::filter::linear` + `address::clamp_to_zero` fetch. We keep
   our own addressing (`sampleRgb` blacks out anything outside the interface)
   and change only the filter. This is the largest known fidelity gap; it costs
   one argument.
2. **We do not hand-roll clamp-to-zero bilinear.** Hardware linear with
   clamp-to-edge differs from the Metal only inside a half-pixel band at the
   interface border (see `## Math` §3). Reproducing it exactly needs 4 texel
   fetches per tap — 128 fetches per fragment at 32 taps. Rejected.
3. **The effect is gated on `|angle| > 1e-4` in Dart, not in GLSL.**
   `FoldEffectModifier` passes `isEnabled: abs(angle) > 1e-4` to `layerEffect`,
   so at rest the original never rasterises the subtree at all. `AnimatedSampler
   .enabled` is the same switch. Consequence, and it is the original's too: the
   shader's `tilt < 1e-5` identity branch becomes unreachable. The shader file
   is not touched.
4. **The debug footer goes.** 003 decision 11 marked it for removal here; it has
   no counterpart in `controlPanel`.
5. **Control tints are literals, not theme lookups.** `AccentColor.colorset` is
   empty ⇒ the original's accent is systemBlue `#007AFF`, which SwiftUI gives
   the Slider and the Button. Our `ColorScheme.fromSeed(#007AFF)` produces a
   *tonal* primary, not `#007AFF`, so every Material default was subtly wrong.
   `control_panel.dart` stops importing `material.dart` altogether and takes its
   colours from `demo_style.dart`, like the demo screen.
6. **The switch is green.** SwiftUI's `Toggle` in the switch style keeps
   `UISwitch`'s `onTintColor` (systemGreen `#34C759`) unless `.tint()` is
   applied; `ContentView.swift` applies none. Stated as a decision because I
   cannot verify it from the repo (the panel is not visible in `Docs/demo.png`).
   If the human reports a blue switch in the original, the fix is one constant:
   `activeTrackColor: kSystemGreen` → `kAccentColor`.
7. **Cupertino controls, not Material ones.** `Slider(divisions: 180)` draws 181
   Material tick marks along the track — a dotted track where SwiftUI's
   `Slider(in: -45...45, step: 0.5)` is clean. `CupertinoSlider(divisions: 180)`
   gives the same 0.5° quantisation with the iOS look. Likewise
   `CupertinoSwitch` (it also dims itself by 0.5 when disabled, which is what
   `.disabled()` does) and `CupertinoButton` (press-fade instead of a Material
   ink ripple). `CupertinoSlider` does **not** dim itself, so its row is wrapped
   in `Opacity(0.5)` to match.
8. **SF Symbols where `CupertinoIcons` has them.** `CupertinoIcons
   .slider_horizontal_3`, `.xmark` and `.scope` are the exact three symbols
   `ContentView.swift` names; all three exist in the shipped `CupertinoIcons`
   class. Verified by grep against the installed framework.
9. **The degree sign is a separate `Text`.** `HStack { Text(number); Text("°") }`
   in the Swift, so the original shows an 8 pt gap between them. Reproduced;
   `test/widget_test.dart`'s `find.text('-20.0°')` splits into two finders.
10. **Transition: 500 ms, spring.** `withAnimation(.snappy)` is
    `spring(duration: 0.5, bounce: 0.15)` and the transition is
    `.move(edge: .bottom).combined(with: .opacity)` — a full-height slide, not
    the 0.15-fraction nudge we had, over 500 ms, not 250. The spring's closed
    form is 15 lines (`SnappyCurve`), so it is written out rather than
    approximated; it drives the slide and the column's height change. The fade
    stays linear because the spring overshoots 1.0 by 0.6 % and `Opacity`
    asserts above 1.0.
11. **The material loses its border.** An iOS `.ultraThinMaterial` shape has no
    stroke; 004's hairline was ours. The blur σ and tint are left alone — they
    were accepted in 004 and I have no better number than a guess.
12. **`CFBundleDisplayName` = `DuoLikeAnimation`.** The original's
    `PRODUCT_NAME = $(TARGET_NAME)` with `GENERATE_INFOPLIST_FILE = YES` puts
    exactly that on the home screen. The app icon stays Flutter's default (the
    original ships an empty `AppIcon.appiconset`, i.e. the grey placeholder;
    neither is "the original's icon" and shipping a placeholder is worse).
13. **`UIUserInterfaceStyle = Light`.** The original follows the system
    appearance; our demo screen hard-codes light (004, deliberate, keyed to
    `Docs/demo.png`). Without this key the launch screen and system chrome go
    dark around a light app on a dark-mode phone — a visible inconsistency that
    the original never has. Full dark support is a 007 candidate.
14. **Orientation set: already correct**, verified, no edit.
    `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "Portrait,
    LandscapeLeft, LandscapeRight"` matches our `Info.plist` exactly, iPad set
    included. The Swift `screenAxesInDeviceSpace()` handles the rotated cases
    and is ported verbatim, so landscape behaves identically in both.
15. **`CADisableMinimumFrameDurationOnPhone` stays true**, knowingly *not*
    matching the original (which lacks the key and is therefore capped at
    60 Hz). The 0.04 s gyro prediction compensates display latency; halving the
    frame rate would add lag the original does not have on the reviewer's
    device. This is the one deliberate non-parity in the phase.
16. **The safe-area strips are correct as they are.** I checked whether
    `.safeAreaPadding(insets)` insets `DemoContentView`'s
    `.background(Color(.systemGroupedBackground))`, which would make the status
    bar strip sample as transparent ⇒ black under the shader. It does not:
    `background(_:ignoresSafeAreaEdges:)` defaults to `.all`, and the top strip
    in `Docs/demo.png` is light grey behind the clock. Our `ColoredBox` + inner
    `SafeArea` matches. No change.
17. **The three Material pictograms stay.** `Icons.directions_walk`,
    `Icons.directions_run`, `Icons.psychology` for `figure.walk`, `figure.run`,
    `brain.head.profile` (004 finding 6.6): `CupertinoIcons` has no equivalent
    and shipping SF Symbols is not an option. Closed as accepted, not deferred.
18. **`MaterialApp.title`** follows the display name for consistency; it is
    invisible on iOS.
19. **No numeric test expectation may move.** The plan's test edits are
    structural only (widget types, icon constants, the split readout, the
    enabled gate). `## Math` §3 argues that linear filtering cannot move any
    probe in `reprojection_test.dart` or `blur_dim_test.dart`. If one does move,
    that is a finding, not a licence to re-baseline — report `STATUS: BLOCKED`.

## Files

### 1. `lib/demo/control_panel.dart` — full replacement

```dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart'
    show CupertinoButton, CupertinoIcons, CupertinoSlider, CupertinoSwitch;
import 'package:flutter/widgets.dart';

import '../motion/fold_motion_model.dart';
import 'demo_style.dart';

/// `withAnimation(.snappy)` — SwiftUI's `spring(duration: 0.5, bounce: 0.15)`.
const Duration kSnappyDuration = Duration(milliseconds: 500);

/// The unit step response of that spring, in normalised time. With
/// `zeta = 1 - bounce`, `decay = 2*pi*zeta` and `damped = 2*pi*sqrt(1 - zeta^2)`
/// the duration cancels out, so this curve is only the `.snappy` spring when it
/// is driven over [kSnappyDuration]. It overshoots 1.0 by 0.6 %, which reads as
/// a firm ease-out rather than a bounce.
class SnappyCurve extends Curve {
  const SnappyCurve();

  static const double _zeta = 0.85;
  static const double _decay = 2 * math.pi * _zeta;
  static final double _damped = 2 * math.pi * math.sqrt(1 - _zeta * _zeta);
  static final double _ratio = _decay / _damped;

  @override
  double transformInternal(double t) {
    if (t >= 1.0) {
      return 1.0; // the overshoot must not be where the animation settles
    }
    return 1.0 -
        math.exp(-_decay * t) *
            (math.cos(_damped * t) + _ratio * math.sin(_damped * t));
  }
}

/// The floating controls of ContentView.swift: a 44 pt frosted round button at
/// the bottom-trailing corner that toggles a 280 pt frosted panel holding the
/// tilt readout, Recalibrate, the Manual-tilt toggle and the −45…45° slider.
///
/// Composed OUTSIDE the fold effect so it stays flat and usable. Every colour
/// and text style is an iOS light-appearance literal from `demo_style.dart`:
/// no Material theming reaches these controls (006, decision 5).
class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key, required this.model});

  final FoldMotionModel model;

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  static const SnappyCurve _snappy = SnappyCurve();

  bool _showsControls = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // `.transition(.move(edge: .bottom).combined(with: .opacity))`: the
        // panel slides up out of the button and fades in while the column's
        // height springs open around it — SwiftUI animates that layout change
        // with the same `.snappy` spring.
        AnimatedSize(
          duration: kSnappyDuration,
          curve: _snappy,
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          child: AnimatedSwitcher(
            duration: kSnappyDuration,
            // The spring drives the slide only: it overshoots 1.0 and Opacity
            // asserts on values above 1.
            switchInCurve: Curves.linear,
            switchOutCurve: Curves.linear,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(
                    Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: _snappy)),
                  ),
                  child: child,
                ),
              );
            },
            child: _showsControls
                ? _Panel(model: widget.model)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 10),
        _Frosted(
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => setState(() => _showsControls = !_showsControls),
              child: Icon(
                _showsControls
                    ? CupertinoIcons.xmark
                    : CupertinoIcons.slider_horizontal_3,
                size: 20,
                color: kLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `controlPanel`: `VStack(alignment: .leading, spacing: 12).padding(16)
/// .frame(width: 280).background(.ultraThinMaterial, in: .rect(cornerRadius: 20))`.
class _Panel extends StatelessWidget {
  const _Panel({required this.model});

  final FoldMotionModel model;

  /// The readout row is `.font(.subheadline.weight(.medium))`; the number is
  /// `.monospacedDigit()`, the degree sign is not.
  static const TextStyle _readout = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: kLabel,
    fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
  );
  static const TextStyle _degreeSign = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: kLabel,
  );

  /// Same size and weight, tinted like an iOS borderless button — and
  /// `UIColor.tertiaryLabel` when disabled, which is CupertinoButton's own rule.
  static const TextStyle _action = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: kAccentColor,
  );
  static const TextStyle _actionDisabled = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: kTertiaryLabel,
  );

  /// The Toggle's label: `.body`, half-transparent when disabled (the 0.5
  /// CupertinoSwitch applies to itself).
  static const TextStyle _body = TextStyle(fontSize: 17, color: kLabel);
  static const TextStyle _bodyDisabled = TextStyle(
    fontSize: 17,
    color: Color(0x80000000),
  );

  /// The slider's minimum/maximum value labels: `.caption2`.
  static const TextStyle _caption2 = TextStyle(fontSize: 11, color: kLabel);

  @override
  Widget build(BuildContext context) {
    return _Frosted(
      radius: 20,
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListenableBuilder(
            listenable: model,
            builder: (BuildContext context, Widget? _) {
              final bool manual = model.usesManualTilt;
              final bool available = model.isMotionAvailable;
              final bool canRecalibrate = !manual && available;
              final double degrees = model.tiltAngle * 180 / math.pi;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // HStack { number, "°", Spacer() }. Flexible + clip so the
                      // fixed-width widget-test font cannot overflow 280 pt.
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                degrees.toStringAsFixed(1),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: _readout,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('°', style: _degreeSign),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: canRecalibrate ? model.recalibrate : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              CupertinoIcons.scope,
                              size: 17,
                              color: canRecalibrate
                                  ? kAccentColor
                                  : kTertiaryLabel,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Recalibrate',
                              style: canRecalibrate ? _action : _actionDisabled,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Manual tilt',
                          style: available ? _body : _bodyDisabled,
                        ),
                      ),
                      CupertinoSwitch(
                        value: manual,
                        activeTrackColor: kSystemGreen,
                        onChanged: available
                            ? (bool value) => model.usesManualTilt = value
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // `.disabled(!motion.usesManualTilt)`: CupertinoSlider does
                  // not dim itself, so the row carries the same 0.5.
                  Opacity(
                    opacity: manual ? 1.0 : 0.5,
                    child: Row(
                      children: <Widget>[
                        const Text('-45°', style: _caption2),
                        Expanded(
                          child: CupertinoSlider(
                            value: model.manualDegrees,
                            min: -FoldMotionModel.maxManualDegrees,
                            max: FoldMotionModel.maxManualDegrees,
                            divisions: 180, // `step: 0.5` over −45…45
                            activeColor: kAccentColor,
                            onChanged: manual
                                ? (double value) => model.manualDegrees = value
                                : null,
                          ),
                        ),
                        const Text('45°', style: _caption2),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Stand-in for SwiftUI's `.ultraThinMaterial` in the **light** appearance:
/// backdrop blur under a translucent light tint. Explicit colours, not
/// scheme-derived, so the panel stays neutral over the light demo content and
/// over the black the shader paints outside the interface (004, decision 9).
/// No border: an iOS material shape has no stroke (006, decision 11).
class _Frosted extends StatelessWidget {
  const _Frosted({required this.radius, required this.child});

  /// iOS light `.ultraThinMaterial` ≈ 62 % of #F2F2F7 over a heavy blur.
  static const Color _tint = Color(0x9EF2F2F7);

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _tint,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### 2. `lib/fold/fold_effect.dart` — three hunks

2a. After the constructor, add the gate constant.

before
```dart
class FoldEffect extends StatefulWidget {
  const FoldEffect({
    super.key,
    required this.angle,
    required this.child,
    this.params = const FoldParameters(),
  });

  /// Tilt θ, radians, signed per context.md.
  final double angle;
```
after
```dart
class FoldEffect extends StatefulWidget {
  const FoldEffect({
    super.key,
    required this.angle,
    required this.child,
    this.params = const FoldParameters(),
  });

  /// Below this |angle| the effect is switched off and the child is painted
  /// directly, exactly as `FoldEffectModifier` does with
  /// `isEnabled: abs(angle) > 1e-4`. The shader's own `tilt < 1e-5` identity
  /// branch is unreachable through this widget as a result — as it is in the
  /// original.
  static const double minVisibleAngle = 1e-4;

  /// Tilt θ, radians, signed per context.md.
  final double angle;
```

2b. The sampler filter.

before
```dart
      ..setImageSampler(0, image, filterQuality: FilterQuality.none); // uTex
```
after
```dart
      // `SwiftUI::Layer::sample` is a linearly filtered fetch; nearest
      // stair-steps the reprojected image where the original is smooth. Only
      // the filter changes: sampleRgb() still blacks out anything outside the
      // interface, so no tap depends on the sampler's addressing (006).
      ..setImageSampler(0, image, filterQuality: FilterQuality.linear); // uTex
```

2c. The enabled gate.

before
```dart
      enabled: shader != null,
```
after
```dart
      enabled:
          shader != null && widget.angle.abs() > FoldEffect.minVisibleAngle,
```

### 3. `lib/main.dart` — one hunk

before
```dart
      title: 'Duo Fold',
```
after
```dart
      title: 'DuoLikeAnimation',
```

### 4. `ios/Runner/Info.plist` — two hunks

4a. Home-screen name.

before
```xml
	<key>CFBundleDisplayName</key>
	<string>Iphoneduo Animation Flutter</string>
```
after
```xml
	<key>CFBundleDisplayName</key>
	<string>DuoLikeAnimation</string>
```

4b. Pin the appearance (the demo screen hard-codes the light palette). Append
the key at the end of the top-level dict; leave both orientation arrays exactly
as they are.

before
```xml
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
</dict>
```
after
```xml
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UIUserInterfaceStyle</key>
	<string>Light</string>
</dict>
```

Indentation in `Info.plist` is tabs. Keep tabs.

### 5. `test/widget_test.dart` — three hunks

5a. Imports: `material.dart` becomes unused once `Slider` and `Icons` are gone
(an analyzer warning), so replace it.

before
```dart
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
```
after
```dart
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSlider;
import 'package:flutter_shaders/flutter_shaders.dart';
```

5b. The panel assertions.

before
```dart
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byType(Slider), findsNothing); // panel closed by default

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('-20.0°'), findsOneWidget);
      expect(find.text('Recalibrate'), findsOneWidget);
      expect(find.text('Manual tilt'), findsOneWidget);
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, -20);
      expect(slider.min, -45);
      expect(slider.max, 45);
      expect(slider.onChanged, isNotNull); // manual mode: slider enabled
```
after
```dart
      expect(find.byIcon(CupertinoIcons.slider_horizontal_3), findsOneWidget);
      // panel closed by default
      expect(find.byType(CupertinoSlider), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
      // The Swift renders the number and the degree sign as two Texts.
      expect(find.text('-20.0'), findsOneWidget);
      expect(find.text('°'), findsOneWidget);
      expect(find.text('Recalibrate'), findsOneWidget);
      expect(find.text('Manual tilt'), findsOneWidget);
      final CupertinoSlider slider = tester.widget<CupertinoSlider>(
        find.byType(CupertinoSlider),
      );
      expect(slider.value, -20);
      expect(slider.min, -45);
      expect(slider.max, 45);
      expect(slider.divisions, 180); // `step: 0.5` over −45…45
      expect(slider.onChanged, isNotNull); // manual mode: slider enabled
```

5c. The sampler test: it must now be tilted to be enabled, plus a new test for
the gate itself.

before
```dart
    testWidgets(
      'fold shader loads in the test renderer and enables the sampler',
      (WidgetTester tester) async {
        // Driven by pump(): never await the loader before the first pump.
        await tester.pumpWidget(
          FoldApp(motionChannel: FakeMotionChannel(available: false)),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(FoldShaderError), findsNothing);
        final AnimatedSampler sampler = tester.widget<AnimatedSampler>(
          find.byType(AnimatedSampler),
        );
        expect(sampler.enabled, isTrue);
      },
    );
  });
}
```
after
```dart
    testWidgets(
      'fold shader loads in the test renderer and enables the sampler',
      (WidgetTester tester) async {
        // Driven by pump(): never await the loader before the first pump.
        await tester.pumpWidget(
          FoldApp(
            motionChannel: FakeMotionChannel(available: false),
            initialTiltDegrees: -20,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(FoldShaderError), findsNothing);
        final AnimatedSampler sampler = tester.widget<AnimatedSampler>(
          find.byType(AnimatedSampler),
        );
        expect(sampler.enabled, isTrue);
      },
    );

    testWidgets(
      'at rest the sampler is off, like FoldEffect.swift\'s isEnabled:',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          FoldApp(motionChannel: FakeMotionChannel(available: false)),
        );
        await tester.pump();
        await tester.pump();
        // |angle| = 0 < 1e-4: the child is painted with no shader at all, so
        // the subtree is never rasterised — the original's behaviour.
        final AnimatedSampler sampler = tester.widget<AnimatedSampler>(
          find.byType(AnimatedSampler),
        );
        expect(sampler.enabled, isFalse);
      },
    );
  });
}
```

### 6. `test/reprojection_test.dart` — one hunk

`_render(tester, 0)` now renders with the sampler switched off, so the
unconditional assertion must become the gate's own expectation. The pixel
expectations of that test are unchanged and still valid: at θ = 0 the child is
the split image the shader would have reproduced pixel for pixel.

before
```dart
  final AnimatedSampler sampler = tester.widget<AnimatedSampler>(
    find.byType(AnimatedSampler),
  );
  expect(sampler.enabled, isTrue, reason: 'shader must be loaded first');
```
after
```dart
  final AnimatedSampler sampler = tester.widget<AnimatedSampler>(
    find.byType(AnimatedSampler),
  );
  // FoldEffect gates the sampler on |angle| > 1e-4, as FoldEffectModifier does
  // with `isEnabled:`; at θ = 0 the child is painted with no shader at all.
  expect(
    sampler.enabled,
    degrees != 0,
    reason: 'the shader must be loaded, and the sampler gated on the angle',
  );
```

Also retitle that test so it says what it now covers.

before
```dart
  testWidgets('θ = 0 is the identity: split at the centre, no black', (
```
after
```dart
  testWidgets('θ = 0: the effect is bypassed, the child paints unchanged', (
```

### 7. `test/blur_dim_test.dart` — no change

Both of its render angles are ±20°, so the gate is satisfied and every
expectation stands (`## Math` §3).

## Math

Conventions restated, unchanged from `context.md`: logical px throughout; x
right, y down, z toward the viewer; the interface is the plane z = 0; θ > 0 puts
the hinge on the **right** edge (`xh = W`); `uSize` is the logical size of the
sampled child; `FlutterFragCoord()` is logical px from the widget's top-left.
No formula in `context.md`'s `## Reference math` changes in this phase, and the
shader is not edited.

**§1 — The `isEnabled` gate (new, from `FoldEffect.swift`).**

```
effectEnabled = |θ| > 1e-4          // FoldEffect.minVisibleAngle
```

`FoldEffectModifier` passes `isEnabled: abs(angle) > 1e-4` to `layerEffect`.
Because 1e-4 > 1e-5, the shader's `if (tilt < 1e-5)` identity branch can never
run while the effect is enabled: it is dead code in the Metal too. Do not
delete it from `duo_fold.frag` — it is the original's line and the shader is out
of scope this phase.

At θ = 1e-4 rad the far edge of a 390 pt screen lifts by
`390 × sin(1e-4) = 0.039 px` and the hit point moves by ≈ 2e-5 px: switching the
effect on and off across the threshold is invisible.

**§2 — The `.snappy` spring (new, from `ContentView.swift`).**

`withAnimation(.snappy)` is `spring(duration: 0.5, bounce: 0.15)`. Apple defines
`duration` as the perceptual duration, i.e. `ωn = 2π/duration`, and
`ζ = 1 − bounce` for `bounce ≥ 0`. The unit step response of the underdamped
second-order system is

```
ωn    = 2π / 0.5 = 12.566 rad/s
ζ     = 0.85
ωd    = ωn·√(1 − ζ²) = 6.6197 rad/s
x(τ)  = 1 − e^(−ζωnτ)·( cos(ωd τ) + (ζωn/ωd)·sin(ωd τ) )
```

In normalised time `t = τ / 0.5` the duration cancels:

```
decay  = ζ·ωn·0.5 = 2π·ζ      = 5.34071
damped = ωd·0.5   = 2π·√(1−ζ²) = 3.30986
ratio  = decay / damped        = 1.61357
x(t)   = 1 − e^(−decay·t)·( cos(damped·t) + ratio·sin(damped·t) )
```

which is `SnappyCurve.transformInternal`. `x(0) = 0` exactly. Peak overshoot is
`e^(−πζ/√(1−ζ²)) = 0.0063`, reached at t ≈ 0.95, and `x(1) = 1.0063`; the curve
clamps to 1.0 at t ≥ 1 so the animation settles at its target and
`CurvedAnimation`'s endpoint assertion (`transform(1).round() == 1`) holds
either way. `Opacity` asserts `0 ≤ opacity ≤ 1`, which is why the fade is driven
by the raw linear animation and only the slide and the height by the spring.

**§3 — Why `FilterQuality.linear` cannot move a probe.**

The sampled image is the child rasterised at the device pixel ratio, so its
texel centres sit at `(i + 0.5)/dpr` logical px, and `FlutterFragCoord()` at a
physical fragment centre is exactly one of those. Therefore:

- **Identity/bypass paths** (`hit = p`): the fetch lands on a texel centre and
  bilinear returns that texel exactly. Every θ = 0 probe is bit-identical.
- **Flat-colour probes**: all four neighbours of the fetch carry the same
  colour, so the blend returns it. This covers every probe in
  `reprojection_test.dart` (all ≥ 9 px from the red/blue seam, per the header of
  that file) and the single-sample / all-red / all-blue probes of
  `blur_dim_test.dart`.
- **The seam probe** (`blur_dim_test.dart`, x = 212, 17 taps straddling the
  seam) asserts `g == 0` and `r + b ≈ 222 ± 6`. Bilinear across the seam
  interpolates between (255,0,0) and (0,0,255): `g` stays 0 and `r + b` stays
  255 before attenuation, for every tap and hence for their mean. Both
  assertions are invariant under the filter change.
- **The wedge probes** are decided by `sampleRgb`'s in/out test and by the
  whole-kernel bounds test, neither of which involves the sampler; the feather
  probe is bracketed 15 < b < 150 and can move by at most a fraction of one tap
  out of 32.

The one real difference from the Metal: within 0.5 px *inside* the interface
border, hardware clamp-to-edge blends with the edge texel where
`address::clamp_to_zero` blends with transparent black, so the original's
outermost half pixel is slightly darker than ours. This is a half-pixel band at
the border of the interface only, and each blur tap that lands in it contributes
at most `1/n ≤ 1/6` of the pixel. Accepted (decision 2).

**§4 — Nothing else changes.** `radius = blurSpread · gap`, the tap count
`clamp(int(radius·2), 6, 32)`, the Vogel disk, `attenuation = max(1 − darkening
· radius, 0)`, the hinge side, the eye at `(W/2, H/2, 1920)` and the black
outside the interface are all exactly as `context.md` states and as 005 shipped.

## Commands

Run in order, from the repository root. Stop and report at the first failure.

1. `git log --oneline -1` — must name phase 005. If 005 is still uncommitted,
   commit it first (`git add -A && git commit -m "phase 005: blur-dim"`,
   attribution per the repo convention) so this phase's diff is reviewable on
   its own.
2. Apply `## Files` §1–§7.
3. `dart format lib test` — report which of the plan's files it rewrites (if it
   rewrites any, that is a formatting slip in the plan, not a defect; keep the
   formatted result and say so in the report).
4. `flutter analyze` — must print `No issues found!`.
5. `flutter test` — all suites must pass **without editing any numeric
   expectation**. If a pixel value must move, stop and report
   `STATUS: BLOCKED` with the actual value.
6. `flutter build ios --debug --no-codesign` — must succeed (it compiles the
   Dart, the Swift bridge and the `--runtime-stage-metal` shader stage).
7. Acceptance greps:
   - `grep -n "devicePixelRatio\|material.dart" lib/demo/control_panel.dart`
     → no output.
   - `grep -rn "FilterQuality\." lib/` → exactly one line, and it reads
     `FilterQuality.low`. (Corrected in review: `FilterQuality.linear` does not
     exist in dart:ui; `low` is the bilinear filter. The `\.` anchor is needed
     because the code comment above the call also contains the bare word
     `FilterQuality`.)
   - `grep -n "minVisibleAngle" lib/fold/fold_effect.dart` → two lines.
   - `grep -A1 -n "CFBundleDisplayName\|UIUserInterfaceStyle" ios/Runner/Info.plist`
     → `DuoLikeAnimation` and `Light`.
   - `grep -c "UIInterfaceOrientation" ios/Runner/Info.plist` → `7`.
   - `git diff --stat -- shaders lib/motion lib/fold/fold_parameters.dart
     lib/demo/demo_content.dart lib/demo/demo_sections.dart
     lib/demo/demo_style.dart ios/Runner/AppDelegate.swift pubspec.yaml` → no
     output.
8. Human device pass: `flutter run -d 00008120-000278980AE3601E`, then the
   H-list below.

## Acceptance

**Tree-checkable (this phase's own acceptance; nothing here depends on an
unrun checklist):**

- T1 Command 4 prints `No issues found!`.
- T2 Command 5 passes with the plan's structural test edits only.
- T3 Command 6 builds.
- T4 Every grep in command 7 gives the stated result.
- T5 `lib/demo/control_panel.dart` uses no Material control. (Corrected in
  review: a bare substring grep for `Slider(`/`Switch(`/`Icons.` also matches
  the Cupertino widgets this phase installs. Use the anchored form —
  `grep -nE '(^|[^A-Za-z])(Slider|Switch|Icons)[.(]|IconButton|TextButton|Theme\.of' lib/demo/control_panel.dart`
  → no output.)
- T6 The diff touches exactly: `lib/demo/control_panel.dart`,
  `lib/fold/fold_effect.dart`, `lib/main.dart`, `ios/Runner/Info.plist`,
  `test/widget_test.dart`, `test/reprojection_test.dart`, and this plan file.
  (Amended in review: `test/blur_dim_test.dart` and `test/demo_content_test.dart`
  may also appear if and only if `git diff -w` on them is empty, i.e. command 3
  reflowed pre-existing formatter drift. Verified: both fail
  `dart format --set-exit-if-changed` at `be6eecd` and pass after.)

**Human, on the iPhone (visual acceptance of this phase):**

- H1 The home screen icon is labelled `DuoLikeAnimation`.
- H2 With the phone in system dark mode, launch: the launch screen and the app
  are both light, with no dark flash and no dark system chrome around a light
  app.
- H3 The round button is a light frosted circle with a dark
  `slider.horizontal.3` glyph and **no** outline ring; it becomes an `xmark`
  when the panel is open.
- H4 Tapping it: the panel rises from behind the button and fades in over about
  half a second, ending firmly with no visible bounce; the button slides up with
  it rather than jumping. Tapping again reverses it.
- H5 Panel contents, top to bottom: the tilt number with a small gap before `°`;
  a blue "Recalibrate" with a scope glyph at the right, grey while Manual tilt
  is on; "Manual tilt" at body size with a green iOS switch; a blue iOS slider
  with a white knob, **no tick marks**, between "-45°" and "45°". With Manual
  tilt off the whole slider row is half-transparent; with it on, Recalibrate is
  half-transparent-grey.
- H6 Rows are visibly separated (12 pt) rather than crowded, and nothing is
  clipped inside the 280 pt panel.
- H7 At rest (motion mode, phone held still at the calibrated pose) the screen
  is indistinguishable from the app with the effect removed: text is as crisp as
  any other iOS app's. Tilt slowly through the first degree — no pop, no sudden
  softening at the moment the effect engages. Then hold the phone dead still at
  the calibrated pose for ten seconds and watch the straight edges of the stat
  tiles and the chips. They must be perfectly static. A faint shimmer or crawl
  on those edges is the gate toggling the offscreen on and off across
  |θ| = 1e-4 (Review §3); report it against 007, and note the tilt readout's
  last digit while you look. (Added by the review revision; §6 listed only
  items (a)–(c) and correction 1, so this never reached the implementer. It is
  a checklist line, not a code change.)
- H8 In manual mode at ±20°, edges inside the reprojected image are smooth, not
  stair-stepped, in the sharp band next to the hinge. This is the
  `FilterQuality.linear` change and is the one place it is visible.
- H9 CONDITIONAL on 005's device checklist, which is still unrun: do **not**
  judge blur strength, dimming or the hinge side here. If any of those look
  wrong, record it against 003/005 — it is not evidence about this phase.

## Out of scope

- `shaders/duo_fold.frag`, the uniform table, `FoldParameters` and its
  defaults, `fold_shader.dart`. No shader edit of any kind.
- `lib/motion/**`, `ios/Runner/AppDelegate.swift`, the tilt sign, the
  calibration and handedness latches.
- `lib/demo/demo_content.dart`, `demo_sections.dart`, `demo_style.dart`: the
  demo screen's geometry, strings and colours are 004's and stay untouched (the
  control panel *reads* `demo_style.dart`, it does not modify it).
- `pubspec.yaml`, `pubspec.lock`: no new packages. `CupertinoIcons` and the
  Cupertino widgets ship with the framework.
- The `android/` and `macos/` targets, the repo `README.md`, the pubspec
  description typo.
- The blur σ and tint of `_Frosted`, the app icon, the launch storyboard,
  `CADisableMinimumFrameDurationOnPhone`.
- Re-running or re-deciding the 003 and 005 device checklists. Findings from
  them belong to their own phase or to 007.

**Proposed 007, if the human wants it.** These are each too large or too
speculative to fold in here:

1. **Dark appearance.** The original follows the system appearance through
   semantic colours; we hard-code the light palette (004) and pin the app to
   light (006, decision 13). Doing it properly means a second palette for every
   constant in `demo_style.dart`, a dark `_Frosted`, a dark status-bar style and
   removing `UIUserInterfaceStyle`. One phase on its own.
2. **SF Symbol parity** for `figure.walk`, `figure.run`, `brain.head.profile`
   (currently Material pictograms; decision 17 closes them as accepted, but
   drawing three matching paths would close the gap).
3. **`.ultraThinMaterial` fidelity** — the real material is a saturated,
   vibrancy-tinted blur; ours is a plain blur under a flat tint. Needs a
   measurement against a screenshot of the original's panel, which we do not
   have.
4. **Dynamic Type and larger text sizes**, and an iPad/landscape pass.
5. Whatever the 003, 005 and 006 device checklists turn up.

## Implementation report
STATUS: DONE
Files written: none (all edits were to existing files)
Files edited:
  - lib/demo/control_panel.dart — full replacement per plan §1.
  - lib/fold/fold_effect.dart — added `minVisibleAngle`, changed the sampler
    filter, gated `enabled` on `|angle| > minVisibleAngle` (plan §2a–2c).
  - lib/main.dart — `title: 'DuoLikeAnimation'` (plan §3).
  - ios/Runner/Info.plist — `CFBundleDisplayName` → `DuoLikeAnimation`,
    appended `UIUserInterfaceStyle: Light` (plan §4).
  - test/widget_test.dart — Cupertino imports/finders, split degree-sign
    assertion, new "at rest" gate test (plan §5).
  - test/reprojection_test.dart — sampler-enabled expectation now keyed to
    `degrees != 0`, test retitled (plan §6).
  - test/blur_dim_test.dart, test/demo_content_test.dart — reformatted only,
    by `dart format` (see Deviations #2); no text changes.
Deviations from plan:
  1. `FilterQuality.linear` does not exist in this SDK's `dart:ui`
     (`FilterQuality` has `none, low, medium, high`; 3.47.1 stable, checked
     against `sky_engine/lib/ui/painting.dart`). Used `FilterQuality.low`
     instead — its doc comment is literally "Bilinear... smoothly
     interpolates between pixels", which is what the plan's own Math §3 and
     decision 1 mean by "linear". Added a one-line code comment explaining
     the substitution. This moves acceptance grep 2's result: `grep -rn
     "FilterQuality" lib/` now returns two lines (the comment and the code),
     not one, and neither says `FilterQuality.linear`. Everything else
     (single filter call, no other FilterQuality use) matches the plan's
     intent.
  2. `dart format lib test` (command 3) additionally reformatted
     `test/blur_dim_test.dart` (one multi-line `testWidgets(` call reflowed)
     and `test/demo_content_test.dart` (one method-chain reflow) — pre-existing
     formatting drift from a newer `dart format`, unrelated to this phase's
     content. Per the plan's own instruction for command 3 ("keep the
     formatted result and say so"), both are kept as formatted. This makes
     the diff wider than acceptance item T6's file list; the additional two
     files carry no textual changes beyond reformatting, and `git diff -w`
     on both is empty of semantic change.
Self-fixes applied:
  1. See Deviation #1 (`FilterQuality.low` in place of the nonexistent
     `FilterQuality.linear`) — required to compile; no other resolution
     changes behaviour, since `low` is dart:ui's only bilinear option.
Command results:
  dart format lib test — reformatted 2 files not named in the plan's Files
    section (test/blur_dim_test.dart, test/demo_content_test.dart); see
    Deviations #2. No plan file was reformatted.
  flutter analyze — clean: "No issues found!"
  flutter test — All 22 tests passed; no numeric expectation was edited.
  flutter build ios --debug --no-codesign — ok: "Built build/ios/iphoneos/Runner.app"
  flutter run — not run (per instructions, compile-only check for this phase)
Acceptance greps (command 7):
  - `devicePixelRatio\|material.dart` in control_panel.dart — no output. ✓
  - `FilterQuality` in lib/ — two lines (see Deviation #1), not the plan's
    expected one `FilterQuality.linear`. ✗ against the plan's literal text;
    the code itself does what decision 1 asks.
  - `minVisibleAngle` in fold_effect.dart — two lines. ✓
  - `CFBundleDisplayName\|UIUserInterfaceStyle` in Info.plist — `DuoLikeAnimation`
    and `Light`. ✓
  - `UIInterfaceOrientation` count — 7. ✓
  - out-of-scope diff stat (shaders, lib/motion, fold_parameters.dart,
    demo_content.dart, demo_sections.dart, demo_style.dart,
    AppDelegate.swift, pubspec.yaml) — no output. ✓
T5 (no `Slider(`, `Switch(`, `IconButton`, `TextButton`, `Icons.`, `Theme.of`
  in control_panel.dart): a substring grep for `Slider(`/`Switch(` matches
  `CupertinoSlider(`/`CupertinoSwitch(`, which the plan's own §1 file
  content specifies; no Material `Slider`, `Switch`, `IconButton`,
  `TextButton`, `Icons.` or `Theme.of` appears.
T6 (diff touches exactly 6 files + the plan): touches those 6 plus
  test/blur_dim_test.dart and test/demo_content_test.dart, both reformat-only
  (Deviation #2).
Open questions for architect:
  1. Confirm `FilterQuality.low` as the intended substitution for the
     nonexistent `FilterQuality.linear` (Deviation #1), or supply the
     correct API if one was meant that I've missed.
  2. Whether to fold the two collateral `dart format` reflows (Deviation #2)
     into this phase's diff (as done) or revert them and file a separate
     formatting-only change.

## Review

STATUS: REVISE

Three findings. The shipped **behaviour** is correct and I found no defect in
any pixel path; the required corrections are one code comment and three
`context.md` hunks that this phase's findings invalidate. The plan file's own
two bad checks I corrected myself, in place (see §6).

### 1. Deviation 1 — `FilterQuality.linear` → `FilterQuality.low`: ACCEPTED

Verified from the SDK source, not from the report:
`/Users/debojyoti/development/flutter/bin/cache/pkg/sky_engine/lib/ui/painting.dart`

- L1035–L1081: `enum FilterQuality { none, low, medium, high }`. There is no
  `linear`. The plan was wrong; the compile error was real.
- L1045–L1049, the doc for `low`: *"This value results in a 'Bilinear'
  algorithm which smoothly interpolates between pixels in an image."*
- L6488: `void setImageSampler(int index, Image image, {FilterQuality
  filterQuality = FilterQuality.none})` → `_setImageSampler(index, image._image,
  filterQuality.index)`.

So `low` is exactly the bilinear filter `## Math` §3 and decision 1 mean by
"linear", and it is the **only** admissible substitution: `medium` adds mipmap
selection, and the texture here comes from `toImageSync` (flutter_shaders
`animated_sampler.dart` L229–L231), which carries no mip chain — `medium` would
have been a second, unplanned change to the image, not a filter rename.

**The no-probe-can-move proof holds verbatim under `low`.** The proof in
`## Math` §3 never uses the name of the enum; it uses only the two properties
`low` has:

1. The fetch is a 2×2 blend with weights from the fractional texel coordinate.
   At a texel centre the weights are (1,0,0,0) ⇒ exact texel ⇒ every θ = 0 and
   every bypass probe is bit-identical.
2. The blend is a convex combination of the four neighbours ⇒ a flat-colour
   neighbourhood returns that colour, and across the red/blue seam `g` stays 0
   and `r + b` stays 255. Both seam assertions are invariant.

The empirical half of the proof also stands: 22/22 tests pass and I confirmed
line by line from `git diff be6eecd -- test/` that **no numeric expectation was
edited** — `test/blur_dim_test.dart`'s diff is pure re-indentation with every
literal (`399,0`, `399,30`, `222 ± 6`, `15 < b < 150`) unchanged, and
`test/reprojection_test.dart`'s only semantic change is the `sampler.enabled`
expectation the plan asked for.

One caveat the proof did not state and should have (proposed as a `context.md`
hunk, §7-C): property 1 requires `ceil(dpr·W) == dpr·W`. `_buildChildScene`
allocates `(pixelRatio * bounds.width).ceil()` texels but the shader maps
`uv = q / uSize`, so the texel scale is `ceil(dpr·W)/W`, not `dpr`. On the
target device (390×844 @ 3× → 1170×2532) and in both pixel-probe suites
(400×300 and 400×900 @ 1×) that is integral and the identity is exact. It is
not exact on a fractional-dpr panel; that is Android, which is out of scope.

The plan's grep check is corrected in place (§6-a): `grep -rn "FilterQuality\."
lib/` → exactly one line, `FilterQuality.low`. Ran it: one line, L92 of
`lib/fold/fold_effect.dart`. This is the same class of error as the 005 check I
corrected there — the check was written against the text I expected to write
rather than against the property I wanted to hold.

### 2. Deviation 2 — the two collateral `dart format` reflows: ACCEPTED

Verified rather than believed. `git show be6eecd:test/demo_content_test.dart`
and `:test/blur_dim_test.dart` into the scratchpad, then
`dart format --output=none --set-exit-if-changed` on both: **exit 1, "2
changed"**. Both files were already non-canonical under Dart 3.13.1's formatter
before this phase touched anything. The working tree now passes the same check
across `lib test` ("15 files, 0 changed"). This is pre-existing drift, the plan's
command 3 instructed exactly this handling, and reverting it would leave the
repo unformattable-clean. Answer to open question 2: **keep them in this
phase's diff**; do not file a separate change. `## Acceptance` T6 is amended
accordingly (§6-c).

### 3. The `isEnabled` gate: threshold correct, no pop, one wrong comment

**Threshold.** Fetched `FoldEffect.swift` fresh. Verbatim:

```swift
content
    .compositingGroup()
    .visualEffect { [angle, parameters] content, _ in
        content.layerEffect(
            ShaderLibrary.duoFold(...),
            maxSampleOffset: .zero,
            isEnabled: abs(angle) > 1e-4
        )
    }
```

`FoldEffect.minVisibleAngle = 1e-4` and `widget.angle.abs() > ...` match the
original exactly — same constant, same strict `>`, same `abs`.

**No pop.** Worked from the geometry, at the worst pixel (far edge / corner) of
a 390×844 pt screen with D = 1920 px, at θ = 1e-4 rad:

```
gap   = 390·sin(1e-4)          = 0.0390 px
t     = D/(D − gap)            = 1.0000203
|hit − p|.x ≤ 195·(t−1)        = 0.0040 px
|hit − p|.y ≤ 422·(t−1)        = 0.0086 px   → 0.026 texel at 3×
foreshortening u·(1−cos θ)     = 2·10⁻⁶ px
radius = 0.12·gap              = 0.0047 px   → radius < 0.5 ⇒ single tap
atten  = 1 − 0.015·radius      = 0.999930    → 0.018 of one 8-bit level
```

So the discontinuity across the threshold is: one 0.026-texel bilinear resample
shift plus 0.018/255 of dimming, in the screen corner, decaying to zero at the
hinge. On antialiased content that is far below one quantisation level. Its
absolute worst case — a synthetic 0/255 step edge exactly on a texel boundary in
the corner — is ~7/255 for the frame the gate opens on. Nothing in
`DemoContent` is that. **No pop.**

Reachability, which matters more than the bound: in manual mode the slider
quantises to 0.5° = 8.7·10⁻³ rad, so θ is either exactly 0 (gate closed) or at
least 87× the threshold (gate open) — the band is never occupied. In motion
mode, at-rest Core Motion attitude noise is 10⁻⁴–10⁻³ rad, i.e. the gate is
open essentially always and the threshold is crossed only in the first frames
after Recalibrate. Both are the original's behaviour, for the same reason.

**But decision 3's stated reason is factually wrong, and it got into the code.**
`.compositingGroup()` sits *outside* `.visualEffect`, so the original flattens
the subtree into an offscreen on **every** frame, gate or no gate; `isEnabled`
gates only the `layerEffect` read of that offscreen. Our `AnimatedSampler`
(`animated_sampler.dart` L20–L24, L173 `alwaysNeedsCompositing => enabled`)
gates the offscreen itself. The consequence is real though small: when θ dithers
across 1e-4, the original switches between "shader-resampled offscreen" and
"direct blit of the same offscreen" — pixel-identical by the proof above — while
we switch between "shader-resampled offscreen" and "no offscreen at all". If
Impeller's offscreen and onscreen passes differ in multisample resolve at all,
that reads as a faint shimmer on hard rect edges while the phone is held still.

I am **not** requiring a code change for this. Forcing an unconditional offscreen
would throw away the gate's only practical benefit (never rasterising the
subtree at rest) to chase an artefact nobody has yet seen, and the correct
evidence is one device pass. It is a comment correction plus a `context.md`
gotcha plus an extra sub-check on H7.

Add to `## Acceptance`, H7: *"Hold the phone dead still at the calibrated pose
for ten seconds and watch the straight edges of the stat tiles and the chips.
They must be perfectly static. A faint shimmer or crawl on those edges is the
gate toggling the offscreen on and off across |θ| = 1e-4 (Review §3); report it
against 007, and note the tilt readout's last digit while you look."*

### 4. Independent math check

Read `shaders/duo_fold.frag` against `context.md`'s `## Reference math`
(L75–L101) without reference to the report:

- `git diff be6eecd -- shaders lib/motion lib/fold/fold_parameters.dart
  lib/demo/demo_content.dart lib/demo/demo_sections.dart lib/demo/demo_style.dart
  ios/Runner/AppDelegate.swift pubspec.yaml` → **empty**. The shader is
  byte-identical to the 005-accepted file, as `## Out of scope` requires.
- Re-derived anyway: `xh = uAngle > 0 ? uSize.x : 0` (L67) ✓ θ>0 ⇒ hinge right;
  `u = p.x − xh` ✓; `G = (xh + u·cos, p.y, |u|·sin)` (L71) ✓;
  `depth ≤ 1e-3 → black` (L74) ✓; `t = E.z/depth` (L77) ✓;
  `radius = uBlurSpread·gap` (L80) ✓ absolute gap, no normalisation;
  `hit < −radius || hit > uSize + radius → black` (L81–82) ✓ whole-kernel test;
  `atten = max(1 − uDarkening·radius, 0)` (L85) ✓;
  `radius < 0.5` ⇒ one tap (L86) ✓;
  `clamp(floor(radius·2), 6, 32)` in float (L92) ✓;
  `ri = radius·sqrt((i+0.5)/tapsF)`, `ai = i·2.39996322972865332 + hash21(p)·2π`
  (L100–101) ✓; `sum/tapsF·atten` (L104) ✓; alpha 1 everywhere ✓.
  Uniform slots 0–5 and sampler 0 match the `context.md` table and the
  `setFloat` calls in `fold_effect.dart` L79–L84 ✓.
- The `tilt < 1e-5` branch (L64) is now unreachable through `FoldEffect`, as
  `## Math` §1 says. Correctly left in place: it is the Metal's line, and the
  shader is out of scope.

### 5. Panel vs `ContentView.swift`

Fetched `controls` and `controlPanel` verbatim and checked item by item. All of
the plan's structural claims are confirmed by the source: outer
`VStack(alignment: .trailing, spacing: 10).padding()`; `44×44` button on
`.ultraThinMaterial, in: .circle` with `.buttonStyle(.plain)` (⇒ label colour,
not accent — our `kLabel` is right); `withAnimation(.snappy)` +
`.transition(.move(edge: .bottom).combined(with: .opacity))`; inner
`VStack(alignment: .leading, spacing: 12).padding(16).frame(width: 280)
.background(.ultraThinMaterial, in: .rect(cornerRadius: 20))`; `Text(number)
.monospacedDigit()`, separate `Text("°")`, `Spacer()`, `Button("Recalibrate",
systemImage: "scope")`, the whole HStack under `.font(.subheadline.weight
(.medium))`; `Toggle("Manual tilt")` inheriting `.body` because the
`.subheadline` font is scoped to the HStack only; `Slider(in: -45...45,
step: 0.5)` with `.caption2` min/max labels, `.disabled(!usesManualTilt)`
covering the labels too. `main.dart`'s `Positioned(right: 16, bottom: 16)`
matches `.padding()`, and the always-present 10 px gap above the collapsed
`AnimatedSize` is invisible because the column is bottom-anchored.

`SnappyCurve` is right. `.snappy` = `spring(duration: 0.5, bounce: 0.15)`;
Apple's mapping is `ωn = 2π/duration`, `ζ = 1 − bounce`, so `decay = 2πζ =
5.34071`, `damped = 2π√(1−ζ²) = 3.30986`, `ratio = 1.61357`, all as coded.
`transformInternal(0) = 1 − 1·(1 + 0) = 0` ✓ and the `t ≥ 1` guard returns 1.0,
so `Curve.transform`'s endpoint assertions hold. Overshoot
`e^(−πζ/√(1−ζ²)) = 0.0063` ✓.

Two residual cosmetic deviations, both ACCEPTED, both the plan's own choices and
neither worth a round trip: the button glyph is 20 pt where `.headline` is 17 pt
semibold, and the number→`°` gap is a fixed 8 px where SwiftUI's `HStack`
default is 8 pt on iOS (i.e. it happens to agree, but by constant, not by rule).

### 6. Corrections

Items (a)–(c) are already applied by me to this plan file; the implementer does
not re-do them. Item 1 and §7 are for the implementer, verbatim.

- (a) `## Commands` step 7, `FilterQuality` grep — replaced with the anchored
  `grep -rn "FilterQuality\." lib/` → one line, `FilterQuality.low`.
- (b) `## Acceptance` T5 — replaced with the anchored
  `grep -nE '(^|[^A-Za-z])(Slider|Switch|Icons)[.(]|IconButton|TextButton|Theme\.of'`
  form. The old substring form matched `CupertinoSlider(`, `CupertinoSwitch(`
  and `CupertinoIcons.`, i.e. it could never have passed. Ran the corrected
  form: no output.
- (c) `## Acceptance` T6 — amended to admit the two reformat-only files under
  the `git diff -w` condition proved in §2.

**1. `test/widget_test.dart`, line 206 — factually wrong claim about the
original.**

current
```dart
        // |angle| = 0 < 1e-4: the child is painted with no shader at all, so
        // the subtree is never rasterised — the original's behaviour.
```
required
```dart
        // |angle| = 0 < 1e-4: the child is painted with no shader at all, as
        // FoldEffectModifier's `isEnabled:` switches its layerEffect off. Note
        // the original's `.compositingGroup()` sits outside `isEnabled`, so it
        // still flattens the subtree at rest and we do not; see 006 review §3.
```

Nothing else in the diff needs to change. After applying, re-run
`dart format lib test`, `flutter analyze` and `flutter test`, then commit
`phase 006: parity-sweep`.

### 7. Proposed `context.md` hunks

I do not edit `context.md`. Route these to the implementer.

**A.** `## Gotchas already known`, the bullet currently reading (L272–L278):

before
```
- `SwiftUI::Layer::sample` is a **linearly filtered**, premultiplied fetch with
  `address::clamp_to_zero` (hence black, not clamped edge, outside the layer).
  We match the addressing in `sampleRgb` but still sample nearest
  (`FilterQuality.none`, 002 decision, kept by 005 decision 9). That is the one
  known remaining departure from the original; resolving it is a 006 item, and
  no 002/005 probe sits near enough to a colour seam to move if it flips to
  `FilterQuality.linear`.
```
after
```
- `SwiftUI::Layer::sample` is a **linearly filtered**, premultiplied fetch with
  `address::clamp_to_zero` (hence black, not clamped edge, outside the layer).
  We match the addressing in `sampleRgb` and, since 006, the filter:
  `setImageSampler(0, image, filterQuality: FilterQuality.low)`. `dart:ui` has
  no `FilterQuality.linear` — the enum is `none, low, medium, high` and `low`
  is the bilinear one. Do **not** "upgrade" it to `medium`: that selects a
  mipmap level, and the `toImageSync` texture `AnimatedSampler` hands us has no
  mip chain. What remains is a half-pixel band at the interface border, where
  hardware clamp-to-edge blends with the edge texel and the Metal's
  `clamp_to_zero` blends with transparent black (006 decision 2, rejected as
  4 fetches per tap).
- The bilinear fetch is an exact identity only while `ceil(dpr·W) == dpr·W`:
  `AnimatedSampler._buildChildScene` allocates `(dpr·width).ceil()` texels but
  the shader maps `uv = q / uSize`, so the texel scale is `ceil(dpr·W)/W`.
  Integral on iOS (390×844 @3× → 1170×2532) and in both probe suites; a
  fractional-dpr panel would soften the whole image slightly. Do not "fix" this
  by dividing by the texture size — `uSize` is the logical contract.
```

**B.** `## Gotchas already known`, append:

```
- The effect is gated in Dart on `|θ| > FoldEffect.minVisibleAngle = 1e-4`,
  which is `FoldEffectModifier`'s `isEnabled: abs(angle) > 1e-4` verbatim. Two
  consequences. (i) The shader's `tilt < 1e-5` identity branch is unreachable
  through `FoldEffect` — it is dead in the Metal too; leave it, it is the
  original's line. (ii) The original's `.compositingGroup()` sits *outside*
  `isEnabled`, so it flattens the subtree on every frame and gates only the
  `layerEffect`; `AnimatedSampler.enabled: false` removes the offscreen
  entirely. Crossing the threshold is worth ~0.026 texel of resample shift and
  0.018/255 of dimming (006 review §3), so it cannot pop on its own — but if a
  held-still phone shows a shimmer on hard rect edges, that is the offscreen
  appearing and disappearing, not the maths.
- Manual mode quantises to 0.5° = 8.7e-3 rad, so the slider never lands inside
  the ±1e-4 gate band; at-rest Core Motion noise is 1e-4…1e-3 rad, so in motion
  mode the gate is open essentially always. The gate is in practice a
  manual-zero and first-frames-after-Recalibrate switch.
```

**C.** `## Gotchas already known`, append:

```
- `dart format` (Dart 3.13.1, tall style) rewrites files this project has
  carried since 003. Running it is part of every phase's commands; the two-file
  reflow it produced in 006 was pre-existing drift, verified by formatting the
  `be6eecd` blobs. `dart format --output=none --set-exit-if-changed lib test`
  must exit 0 before a report is written.
```

### 8. Is the port complete?

**Code-complete, not verified-complete.** Against `elijah-semyonov/
DuoLikeAnimation` I can no longer find a difference in the maths, the uniform
plumbing, the motion model, the demo content or the control panel that I can
justify from the sources — §4 and §5 are exhaustive re-derivations, not
spot-checks. Everything that is left is either a deliberate, argued
non-parity or a cosmetic gap with a named owner:

| Left over | Status |
|---|---|
| half-pixel `clamp_to_zero` band at the interface border | accepted, 006 dec. 2 |
| `.compositingGroup()` unconditional in the original | accepted, review §3 |
| `CADisableMinimumFrameDurationOnPhone` (we 120 Hz, original 60) | deliberate, 006 dec. 15 |
| `hash21` fed layer-local coords (grain field translated) | accepted, 005 |
| button glyph 20 pt vs `.headline` 17 pt | accepted, review §5 |
| three Material pictograms for SF Symbols | accepted, 006 dec. 17 |
| light appearance pinned; original follows the system | 007 candidate 1 |
| `.ultraThinMaterial` is a flat tint over a plain blur | 007 candidate 3 |
| Dynamic Type, iPad, landscape | 007 candidate 4 |
| app icon (both are placeholders) | accepted, 006 dec. 12 |
| switch tint green (unverifiable from the repo) | 006 dec. 6, one constant if wrong |

What blocks calling it done is not a list of features. It is that **no human has
run a single device checklist yet**: 003's motion pass, 005's blur/dim pass and
006's H1–H8 are all unrun. Everything above was validated on `flutter_tester`
(Skia, pixel probes) and by `flutter build ios`. The three claims that only
hardware can settle are the ones the whole effect rests on: that
`FlutterFragCoord()` really is logical px from the widget's top-left under
Impeller (002 H1, still open by `context.md`'s own admission), that the hinge
lands on the side gravity says it should, and that the blur and dimming read as
frosted glass rather than as mud.

**A 007 must therefore hold, in this order:**

1. **The device pass, as one plan.** 003's, 005's and 006's H-lists run back to
   back in a single session with the phone, one screenshot per numbered item at
   a stated manual tilt. Nothing else in 007 can be planned before its output
   exists — every remaining item is either confirmed or reopened by it.
2. The findings that pass produces. Expected candidates, from the reasoning
   above: the at-rest shimmer (§3), a wrong handedness latch after a cold
   relaunch, and blur strength.
3. Only then the four cosmetic items, dark appearance first, since it is the
   only one a user would notice unprompted.

If the human's answer to "is it done" has to be given before that session, the
honest form is: *the port reproduces the source's model exactly as far as it can
be checked without a screen, and has never been looked at on one.*

## Implementation report (revision)
STATUS: DONE
Files written: none
Files edited:
  - test/widget_test.dart — replaced the "at rest" test's comment (review §6
    item 1): the old comment claimed the original never rasterises the subtree
    at rest, which review §3 shows is false (`.compositingGroup()` sits outside
    `isEnabled`, so the original always flattens the subtree; only the
    `layerEffect` read is gated). New comment states the correct mechanism and
    cross-references 006 review §3.
  - context.md — applied review §7 hunks A, B and C to `## Gotchas already
    known`: (A) replaced the stale "we sample nearest" bullet with the
    `FilterQuality.low` substitution rationale plus the new `ceil(dpr·W)`
    exactness bullet; (B) appended the `isEnabled` gate gotcha (unreachable
    shader branch, `.compositingGroup()` asymmetry, no-pop bound, manual/motion
    reachability); (C) appended the `dart format` drift gotcha.
Deviations from plan: none. FilterQuality.low and the dart format reflows were
  left untouched per instructions (both already accepted in review).
Self-fixes applied: none
Command results:
  dart format lib test — "Formatted 15 files (0 changed)"
  flutter analyze — clean: "No issues found!"
  flutter test — All 22 tests passed
  flutter build ios --debug --no-codesign — ok: "Built build/ios/iphoneos/Runner.app"
Open questions for architect: none

## Review (revision)

STATUS: ACCEPTED

All four required corrections landed as specified. I re-ran the checks rather
than reading the report's claims, and re-fetched the Swift rather than trusting
my own previous review.

### 1. Correction 1 — the gate comment: applied, and now true

`test/widget_test.dart` L203–L206 is the required text byte for byte:

```dart
        // |angle| = 0 < 1e-4: the child is painted with no shader at all, as
        // FoldEffectModifier's `isEnabled:` switches its layerEffect off. Note
        // the original's `.compositingGroup()` sits outside `isEnabled`, so it
        // still flattens the subtree at rest and we do not; see 006 review §3.
```

Checked clause by clause against a fresh fetch of `FoldEffect.swift`, since this
comment is the tree's only record of why the gate is safe:

- *"the child is painted with no shader at all"* — true of **our** code:
  `AnimatedSampler` with `enabled: false` paints the child directly
  (`animated_sampler.dart` L173 `alwaysNeedsCompositing => enabled`).
- *"as `FoldEffectModifier`'s `isEnabled:` switches its layerEffect off"* —
  true: `isEnabled: abs(angle) > 1e-4` is the last argument of `layerEffect`,
  and `FoldEffect.minVisibleAngle = 1e-4` with the same strict `>` and `abs`.
- *"`.compositingGroup()` sits outside `isEnabled`"* — verified from source
  order: `content.compositingGroup().visualEffect { content.layerEffect(…,
  isEnabled:) }`. The flattening is unconditional in the *declaration*; only the
  `layerEffect` is gated. This is the fact the old comment inverted.
- *"and we do not"* — true of our code, as above.

The old comment claimed the original "never rasterises the subtree" at rest,
which is the opposite of what the source says. The replacement makes no such
claim and, where it is least verifiable (whether SwiftUI's renderer actually
materialises the compositing group when no effect is live — an implementation
detail no source can settle), it hedges into "see 006 review §3", which routes
to the H7 device check and to a named 007 candidate. That is the correct
resting place for it. No code depends on the claim either way. Accepted.

Also confirmed no other comment in `lib/` or `test/` still asserts the old
reason: `grep -rn "never rasteris\|not rasteris\|no offscreen" lib test` → the
only hits are `demo_content.dart`'s platform-view note, which is unrelated and
correct. `fold_effect.dart`'s `minVisibleAngle` doc and
`reprojection_test.dart` L79–L80 both describe the gate without the false
premise.

### 2. Corrections A, B, C — `context.md`: applied verbatim

`git diff -- context.md` matches §7 exactly, with correct placement:

- **A** replaced the stale bullet in `## Gotchas already known` (the old text
  "we ... still sample nearest (`FilterQuality.none`, 002 decision …)" is gone
  from the file) with the `FilterQuality.low` bullet, and inserted the
  `ceil(dpr·W) == dpr·W` bullet directly after it, ahead of the `hash21`
  bullet — the order §7-A's "after" block specifies.
- **B** appended the two gate bullets after the `hash21` bullet.
- **C** appended the `dart format` bullet last.

No other line of `context.md` moved. The reference math, the uniform table and
the tunables table are untouched, as this phase requires.

### 3. Commands, re-run by me

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | `Formatted 15 files (0 changed)`, exit 0 |
| `flutter analyze` | `No issues found!` |
| `flutter test` | `00:01 +22: All tests passed!` |
| `flutter build ios --debug --no-codesign` | accepted on the report, not re-run: the only changes since the build that produced it are one four-line Dart comment and one markdown file, neither of which can reach the compiler or `impellerc` |

Acceptance greps, re-run: `grep -rn "FilterQuality\." lib/` → one line,
`fold_effect.dart:92 … FilterQuality.low`; the anchored T5 form → no output;
`minVisibleAngle` → two lines (L27, L111); `CFBundleDisplayName` →
`DuoLikeAnimation`, `UIUserInterfaceStyle` → `Light`;
`grep -c "UIInterfaceOrientation"` → 7; the out-of-scope `git diff --stat` →
empty, so the shader, the motion code, the parameters, the demo screen, the
AppDelegate and the pubspec are byte-identical to `be6eecd`.

T1 ✓ T2 ✓ T3 ✓ (report) T4 ✓ T5 ✓ T6 ✓ (eight files + this plan, the two extra
being the reformat-only pair admitted by the amended T6).

### 4. Plan-file amendment I made in this revision

Review §3 asked for a sub-check on `## Acceptance` H7 but §6 listed only items
(a)–(c) and correction 1, so it never reached the implementer. I have added it
to H7 myself, in this file. It is a checklist line; no code changes.

### 5. Device checklists

H1–H8 remain **pending, not failing**, as do 003's and 005's. Nothing in this
phase's tree-checkable acceptance depends on them. They are the whole content of
the proposed 007 item 1 (§8).

### 6. State of the tree at this commit

Phase 006 is accepted and the port is code-complete. `duo_fold` reproduces
`elijah-semyonov/DuoLikeAnimation` — the reprojection, blur and dimming maths of
`DuoFold.metal` in `shaders/duo_fold.frag`, `FoldMotionModel.swift` ported
verbatim into `ios/Runner/AppDelegate.swift` behind an `EventChannel`,
`DemoContentView` and the floating control panel in Flutter widgets — with every
remaining departure argued and listed in the table in `## Review` §8 of this
plan. `context.md` is the single source of truth for the model, the uniform
order and the gotchas; every phase's reasoning is in `docs/plans/`. What has
**not** happened is a single run on a phone: all validation so far is
`flutter analyze`, 22 `flutter_tester` pixel-probe tests on Skia, and
`flutter build ios`. The three claims only hardware can settle — that
`FlutterFragCoord()` is logical px from the widget's top-left under Impeller,
that the hinge lands on the side gravity says it should, and that the blur and
dimming read as frosted glass — are the ones the effect rests on. Run the H-lists
of 003, 005 and 006 back to back before changing anything else.
