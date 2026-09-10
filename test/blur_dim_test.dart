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
