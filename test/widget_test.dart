import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSlider;
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphoneduo_animation_flutter/demo/control_panel.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_effect.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_parameters.dart';
import 'package:iphoneduo_animation_flutter/main.dart';
import 'package:iphoneduo_animation_flutter/motion/fold_motion_channel.dart';
import 'package:iphoneduo_animation_flutter/motion/fold_motion_model.dart';

/// Scriptable stand-in for the native bridge.
class FakeMotionChannel implements MotionChannel {
  FakeMotionChannel({required this.available});

  final bool available;
  final StreamController<double> tilt = StreamController<double>.broadcast();
  int recalibrations = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<double> tiltStream() => tilt.stream;

  @override
  Future<void> recalibrate() async => recalibrations++;
}

void main() {
  group('FoldParameters', () {
    test('defaults mirror FoldEffect.swift', () {
      const FoldParameters p = FoldParameters();
      expect(p.eyeDistanceMm, 320);
      expect(p.pointsPerMm, 6);
      expect(p.eyeDistancePx, 1920);
      expect(p.blurSpread, 0.12);
      expect(p.darkening, 0.015);
    });

    test('copyWith and equality', () {
      const FoldParameters p = FoldParameters();
      expect(p.copyWith(), p);
      expect(p.copyWith(pointsPerMm: 6.3), isNot(p));
      expect(p.copyWith(eyeDistanceMm: 400).eyeDistancePx, 2400);
      expect(p.copyWith(blurSpread: 0, darkening: 0), isNot(p));
      expect(p.copyWith(blurSpread: 0).darkening, 0.015);
    });
  });

  group('FoldMotionModel', () {
    test('without motion it is manual, clamped to ±45°', () async {
      final FoldMotionModel m = FoldMotionModel(
        channel: FakeMotionChannel(available: false),
        initialManualDegrees: -60,
      );
      await m.start();
      expect(m.isMotionAvailable, isFalse);
      expect(m.usesManualTilt, isTrue);
      expect(m.isLive, isFalse);
      expect(m.manualDegrees, -45);
      expect(m.theta, closeTo(-45 * math.pi / 180, 1e-12));
      m.usesManualTilt = false; // refused: no motion
      expect(m.usesManualTilt, isTrue);
      m.manualDegrees = 20;
      expect(m.theta, greaterThan(0)); // θ > 0 ⇒ hinge on the right edge
      m.dispose();
    });

    test(
      'with motion it follows the native stream and can recalibrate',
      () async {
        final FakeMotionChannel channel = FakeMotionChannel(available: true);
        final FoldMotionModel m = FoldMotionModel(channel: channel);
        int notified = 0;
        m.addListener(() => notified++);
        await m.start();
        expect(m.usesManualTilt, isFalse);
        expect(m.isLive, isTrue);
        expect(channel.tilt.hasListener, isTrue);

        channel.tilt.add(0.25);
        await Future<void>.delayed(Duration.zero);
        expect(m.theta, 0.25);
        expect(m.motionTilt, 0.25);

        await m.recalibrate();
        expect(channel.recalibrations, 1);
        expect(m.theta, 0);

        m.usesManualTilt = true;
        m.manualDegrees = 10;
        expect(m.theta, closeTo(10 * math.pi / 180, 1e-12));
        channel.tilt.add(0.5); // still received, not shown
        await Future<void>.delayed(Duration.zero);
        expect(m.motionTilt, 0.5);
        expect(m.theta, closeTo(10 * math.pi / 180, 1e-12));
        m.usesManualTilt = false;
        expect(m.theta, 0.5);
        expect(notified, greaterThan(0));

        m.stop();
        expect(channel.tilt.hasListener, isFalse);
        m.dispose();
      },
    );

    test('forceManual keeps the slider even when motion exists', () async {
      final FakeMotionChannel channel = FakeMotionChannel(available: true);
      final FoldMotionModel m = FoldMotionModel(
        channel: channel,
        forceManual: true,
        initialManualDegrees: -20,
      );
      await m.start();
      expect(m.isMotionAvailable, isTrue);
      expect(m.usesManualTilt, isTrue);
      expect(m.theta, closeTo(-20 * math.pi / 180, 1e-12));
      m.dispose();
    });

    test('a stream error cancels the subscription and falls back', () async {
      final FakeMotionChannel channel = FakeMotionChannel(available: true);
      final FoldMotionModel m = FoldMotionModel(channel: channel);
      await m.start();
      expect(channel.tilt.hasListener, isTrue);

      channel.tilt.addError(StateError('sensor gone'));
      await Future<void>.delayed(Duration.zero);
      expect(channel.tilt.hasListener, isFalse); // native updates stopped
      expect(m.isMotionAvailable, isFalse);
      expect(m.usesManualTilt, isTrue);
      expect(m.isLive, isFalse);
      m.dispose();
    });
  });

  group('FoldApp', () {
    testWidgets('composes the effect, the content and the hidden panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        FoldApp(
          motionChannel: FakeMotionChannel(available: false),
          initialTiltDegrees: -20,
        ),
      );
      await tester.pump();
      expect(find.byType(FoldEffect), findsOneWidget);
      expect(find.byType(DemoContent), findsOneWidget);
      expect(find.byType(ControlPanel), findsOneWidget);
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
    });

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
        // |angle| = 0 < 1e-4: the child is painted with no shader at all, as
        // FoldEffectModifier's `isEnabled:` switches its layerEffect off. Note
        // the original's `.compositingGroup()` sits outside `isEnabled`, so it
        // still flattens the subtree at rest and we do not; see 006 review §3.
        final AnimatedSampler sampler = tester.widget<AnimatedSampler>(
          find.byType(AnimatedSampler),
        );
        expect(sampler.enabled, isFalse);
      },
    );
  });
}
