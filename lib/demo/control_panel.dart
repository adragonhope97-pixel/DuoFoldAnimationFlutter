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
