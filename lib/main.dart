import 'package:flutter/material.dart';

import 'demo/control_panel.dart';
import 'demo/demo_content.dart';
import 'fold/fold_effect.dart';
import 'fold/fold_parameters.dart';
import 'motion/manual_tilt.dart';

/// Launch-time tilt for screenshots on targets without motion data:
///
///     flutter run -d macos --dart-define=TILT_DEGREES=-20
///
/// Read as a string: `double.fromEnvironment` does not exist.
const String _tiltDegreesDefine = String.fromEnvironment(
  'TILT_DEGREES',
  defaultValue: '0',
);

/// The `TILT_DEGREES` dart-define as a finite double; 0 when absent or bad.
double launchTiltDegrees() {
  final double? value = double.tryParse(_tiltDegreesDefine);
  return value != null && value.isFinite ? value : 0;
}

void main() {
  runApp(const FoldApp());
}

class FoldApp extends StatelessWidget {
  const FoldApp({
    super.key,
    this.params = const FoldParameters(),
    this.initialTiltDegrees,
  });

  final FoldParameters params;

  /// Overrides the dart-define; tests pass this explicitly.
  final double? initialTiltDegrees;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duo Fold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: FoldScreen(
        params: params,
        initialTiltDegrees: initialTiltDegrees ?? launchTiltDegrees(),
      ),
    );
  }
}

/// Full-screen glass ([FoldEffect] over [DemoContent]) with the flat
/// [ControlPanel] floating at the bottom, outside the effect.
class FoldScreen extends StatefulWidget {
  const FoldScreen({
    super.key,
    required this.params,
    required this.initialTiltDegrees,
  });

  final FoldParameters params;
  final double initialTiltDegrees;

  @override
  State<FoldScreen> createState() => _FoldScreenState();
}

class _FoldScreenState extends State<FoldScreen> {
  late final ManualTilt _tilt = ManualTilt(
    maxDeg: widget.params.maxTiltDeg,
    initialDeg: widget.initialTiltDegrees,
  );

  @override
  void dispose() {
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ListenableBuilder(
            listenable: _tilt,
            builder: (BuildContext context, Widget? child) {
              return FoldEffect(
                angle: _tilt.theta,
                params: widget.params,
                child: child!,
              );
            },
            child: const DemoContent(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ControlPanel(tilt: _tilt),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
