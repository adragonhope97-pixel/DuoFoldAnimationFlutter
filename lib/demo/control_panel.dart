import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../motion/fold_motion_model.dart';

/// The floating controls of ContentView.swift: a 44 px frosted round button
/// at the bottom-trailing corner that toggles a 280 px frosted panel with the
/// tilt readout, Recalibrate, the Manual-tilt switch and the −45…45° slider.
///
/// Composed OUTSIDE the fold effect so it stays flat and usable.
class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key, required this.model});

  final FoldMotionModel model;

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  bool _showsControls = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _showsControls
              ? _Panel(model: widget.model)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),
        _Frosted(
          radius: 22,
          child: IconButton(
            tooltip: _showsControls ? 'Hide controls' : 'Show controls',
            onPressed: () => setState(() => _showsControls = !_showsControls),
            iconSize: 22,
            icon: Icon(_showsControls ? Icons.close : Icons.tune),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.model});

  final FoldMotionModel model;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
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
              final double degrees = model.tiltAngle * 180 / math.pi;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${degrees.toStringAsFixed(1)}°',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            fontFeatures: <ui.FontFeature>[
                              ui.FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: manual || !available
                            ? null
                            : model.recalibrate,
                        icon: const Icon(Icons.center_focus_strong, size: 18),
                        label: const Text('Recalibrate'),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Expanded(child: Text('Manual tilt')),
                      Switch.adaptive(
                        value: manual,
                        onChanged: available
                            ? (bool value) => model.usesManualTilt = value
                            : null,
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      const Text('-45°', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: model.manualDegrees,
                          min: -FoldMotionModel.maxManualDegrees,
                          max: FoldMotionModel.maxManualDegrees,
                          divisions: 180,
                          label: '${model.manualDegrees.toStringAsFixed(1)}°',
                          onChanged: manual
                              ? (double value) => model.manualDegrees = value
                              : null,
                        ),
                      ),
                      const Text('45°', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  Text(
                    '${manual ? 'manual' : 'motion'} · dpr '
                    '${mq.devicePixelRatio.toStringAsFixed(2)} · '
                    '${mq.size.width.toStringAsFixed(0)}×'
                    '${mq.size.height.toStringAsFixed(0)} lpx',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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

/// Stand-in for SwiftUI's `.ultraThinMaterial`: backdrop blur under a
/// translucent surface tint.
class _Frosted extends StatelessWidget {
  const _Frosted({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}
