import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphoneduo_animation_flutter/demo/control_panel.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_effect.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_parameters.dart';
import 'package:iphoneduo_animation_flutter/main.dart';
import 'package:iphoneduo_animation_flutter/motion/manual_tilt.dart';

void main() {
  group('FoldParameters', () {
    test('defaults match context.md tunables', () {
      const FoldParameters p = FoldParameters();
      expect(p.eyeDistanceMm, 320);
      expect(p.maxBlurPx, 24);
      expect(p.dimStrength, 0.6);
      expect(p.maxTiltDeg, 35);
      expect(FoldParameters.blurTaps, 16);
    });

    test('eyeDistancePx converts with 160/25.4 px per mm', () {
      expect(const FoldParameters().eyeDistancePx, closeTo(2015.748, 0.001));
      expect(
        const FoldParameters(eyeDistanceMm: 25.4).eyeDistancePx,
        closeTo(160, 1e-9),
      );
    });

    test('copyWith and equality', () {
      const FoldParameters p = FoldParameters();
      expect(p.copyWith(), p);
      expect(p.copyWith(maxBlurPx: 8), const FoldParameters(maxBlurPx: 8));
      expect(p.copyWith(maxBlurPx: 8), isNot(p));
    });
  });

  group('ManualTilt', () {
    test('clamps to ±maxDeg and reports θ in radians', () {
      final ManualTilt tilt = ManualTilt(maxDeg: 35, initialDeg: -50);
      expect(tilt.degrees, -35);
      expect(tilt.theta, closeTo(-35 * math.pi / 180, 1e-12));
      tilt.degrees = 90;
      expect(tilt.degrees, 35);
      tilt.degrees = 20;
      expect(tilt.theta, greaterThan(0)); // θ > 0 ⇒ hinge on the right edge
      tilt.dispose();
    });

    test('notifies only when the clamped value changes', () {
      final ManualTilt tilt = ManualTilt(maxDeg: 35);
      int notified = 0;
      tilt.addListener(() => notified++);
      tilt.degrees = 10;
      tilt.degrees = 10; // no change
      tilt.degrees = 40; // clamps to 35
      tilt.degrees = 50; // still 35: no change
      tilt.reset();
      expect(notified, 3);
      tilt.dispose();
    });
  });

  group('FoldApp', () {
    testWidgets('composes demo content, fold effect and panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const FoldApp(initialTiltDegrees: -20));
      await tester.pump();
      expect(find.byType(FoldEffect), findsOneWidget);
      expect(find.byType(DemoContent), findsOneWidget);
      expect(find.byType(ControlPanel), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('θ -20.0°'), findsOneWidget);
      expect(find.text('hinge left'), findsOneWidget);
    });

    testWidgets(
      'fold shader loads in the test renderer and enables the sampler',
      (WidgetTester tester) async {
        // The load is driven by pump(): FragmentProgram.fromAsset completes
        // on a microtask that pump flushes. Do not await FoldShader.load()
        // before the first pump — inside testWidgets that never resumes.
        await tester.pumpWidget(const FoldApp(initialTiltDegrees: 0));
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
