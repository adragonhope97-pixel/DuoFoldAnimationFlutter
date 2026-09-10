import 'package:flutter/material.dart';

import '../motion/manual_tilt.dart';

/// Floating panel: manual tilt slider, θ readout, hinge side, and the
/// device-pixel-ratio / logical-size readout used by phase 001 acceptance.
///
/// Composed OUTSIDE the fold effect so it stays flat and usable (mirrors the
/// floating panel in ContentView.swift). Recalibrate arrives in phase 004.
class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key, required this.tilt});

  final ManualTilt tilt;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final String geometry =
        'manual · dpr ${mq.devicePixelRatio.toStringAsFixed(2)} · '
        '${mq.size.width.toStringAsFixed(0)}×'
        '${mq.size.height.toStringAsFixed(0)} lpx';
    return ListenableBuilder(
      listenable: tilt,
      builder: (BuildContext context, Widget? child) {
        final double deg = tilt.degrees;
        final String hinge = deg > 0 ? 'right' : (deg < 0 ? 'left' : 'none');
        return Material(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'θ ${deg.toStringAsFixed(1)}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'hinge $hinge',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: tilt.reset,
                      child: const Text('Center'),
                    ),
                  ],
                ),
                Slider(
                  value: deg,
                  min: -tilt.maxDeg,
                  max: tilt.maxDeg,
                  onChanged: (double value) => tilt.degrees = value,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    geometry,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
