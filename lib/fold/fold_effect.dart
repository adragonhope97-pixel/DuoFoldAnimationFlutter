import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'fold_parameters.dart';
import 'fold_shader.dart';

/// Applies the fold shader to [child].
///
/// [angle] is θ in radians, signed per context.md: θ > 0 → the RIGHT edge is
/// the hinge. While the program is loading the child is painted unmodified;
/// if loading fails a [FoldShaderError] panel replaces it (never silent).
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

  final FoldParameters params;

  /// Pure-Flutter subtree; platform views are not captured by the sampler.
  final Widget child;

  @override
  State<FoldEffect> createState() => _FoldEffectState();
}

class _FoldEffectState extends State<FoldEffect> {
  ui.FragmentShader? _shader;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    FoldShader.load().then<void>(
      (FoldShader loaded) {
        if (!mounted) {
          return;
        }
        setState(() => _shader = loaded.createShader());
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() => _loadError = error);
      },
    );
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  /// Uniform slots — must match the table in context.md and the header of
  /// shaders/duo_fold.frag. Sampler indices are counted separately.
  void _paint(
    ui.FragmentShader shader,
    ui.Image image,
    Size size,
    Canvas canvas,
  ) {
    final FoldParameters p = widget.params;
    shader
      ..setFloat(0, size.width) // uSize.x
      ..setFloat(1, size.height) // uSize.y
      ..setFloat(2, widget.angle) // uAngle
      ..setFloat(3, p.eyeDistancePx) // uEyeDistPx
      ..setFloat(4, p.blurSpread) // uBlurSpread
      ..setFloat(5, p.darkening) // uDarkening
      // `SwiftUI::Layer::sample` is a linearly filtered fetch; nearest
      // stair-steps the reprojected image where the original is smooth. Only
      // the filter changes: sampleRgb() still blacks out anything outside the
      // interface, so no tap depends on the sampler's addressing (006).
      // dart:ui's FilterQuality has no `linear` constant; `low` is the
      // documented bilinear filter the plan's own Math §3 means by "linear".
      ..setImageSampler(0, image, filterQuality: FilterQuality.low); // uTex
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  Widget build(BuildContext context) {
    final Object? error = _loadError;
    if (error != null) {
      return FoldShaderError(error: error);
    }
    final ui.FragmentShader? shader = _shader;
    // A fresh closure every build: AnimatedSampler compares builders with ==
    // and only re-rasterises when the builder changed. A method tear-off
    // would compare equal and freeze the effect at the first angle.
    return AnimatedSampler(
      (ui.Image image, Size size, Canvas canvas) {
        _paint(shader!, image, size, canvas);
      },
      enabled:
          shader != null && widget.angle.abs() > FoldEffect.minVisibleAngle,
      child: widget.child,
    );
  }
}

/// Replaces the child when the fragment program failed to load. Red on
/// purpose: a silent fallback would look exactly like "no effect".
class FoldShaderError extends StatelessWidget {
  const FoldShaderError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF7A0000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Fold shader failed to load\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
