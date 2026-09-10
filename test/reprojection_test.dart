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
// Math, re-derived for D = 1920 in 003). Geometry: W = 400, H = 300 logical
// px, D = 320 mm × 6 px/mm = 1920 px. At |θ| = 20° (sin 0.34202, cos 0.93969):
//   hinge column (d = 0.5):  t ≈ 1.00009 → samples itself
//   far edge   (d = 399.5):  t ≈ 1.07663 → hit.y = 150 ± 1.07663·(py − 150)
//                            → rows 0..10 and 289..299 miss the interface
//   centre     (d = 200.5):  t ≈ 1.03704 → hit.x ≈ 188.0 (θ < 0), ≈ 213.0 (θ > 0)
// Every probe is ≥ 9 px from a predicted boundary.
//
// Blur and dim are switched off here (blurSpread = darkening = 0). With
// radius = 0 the 005 kernel reduces exactly to 002's path — one bounds-checked
// sample, attenuation 1, black iff hit ∉ [0,uSize] — so these probes keep
// their literal colours and stay a pure test of the reprojection geometry.
// Blur and dimming are pinned by test/blur_dim_test.dart.
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

/// Renders FoldEffect at 400×300 logical px and [dpr], returns raw RGBA of
/// the (400·dpr)×(300·dpr) physical image.
Future<ByteData> _render(
  WidgetTester tester,
  double degrees, {
  double dpr = 1.0,
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(_w * dpr, _h * dpr);
  addTearDown(tester.view.reset);

  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: FoldEffect(
          angle: degrees * math.pi / 180,
          params: const FoldParameters(blurSpread: 0, darkening: 0),
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
  // FoldEffect gates the sampler on |angle| > 1e-4, as FoldEffectModifier does
  // with `isEnabled:`; at θ = 0 the child is painted with no shader at all.
  expect(
    sampler.enabled,
    degrees != 0,
    reason: 'the shader must be loaded, and the sampler gated on the angle',
  );

  ByteData? bytes;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: dpr);
    expect(image.width, (_w * dpr).round());
    bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();
  });
  return bytes!;
}

Color _pixel(ByteData bytes, int x, int y, {int stride = 400}) {
  final int i = (y * stride + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

void main() {
  testWidgets('θ = 0: the effect is bypassed, the child paints unchanged', (
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
    // Far edge: ~11 px wedges top and bottom are black, the middle is content.
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

  testWidgets('dpr 2: the same geometry at physical 2× coordinates', (
    WidgetTester tester,
  ) async {
    // The sampler image is 800×600 physical, uSize stays 400×300 logical and
    // FlutterFragCoord() stays logical: every −20° probe holds at 2× (x, y).
    final ByteData px = await _render(tester, -20, dpr: 2.0);
    expect(_pixel(px, 0, 0, stride: 800), _red);
    expect(_pixel(px, 0, 300, stride: 800), _red);
    expect(_pixel(px, 0, 598, stride: 800), _red);
    expect(_pixel(px, 798, 0, stride: 800), _black);
    expect(_pixel(px, 798, 10, stride: 800), _black);
    expect(_pixel(px, 798, 40, stride: 800), _blue);
    expect(_pixel(px, 798, 300, stride: 800), _blue);
    expect(_pixel(px, 798, 560, stride: 800), _blue);
    expect(_pixel(px, 798, 588, stride: 800), _black);
    expect(_pixel(px, 798, 598, stride: 800), _black);
    expect(_pixel(px, 400, 300, stride: 800), _red);
  });
}
