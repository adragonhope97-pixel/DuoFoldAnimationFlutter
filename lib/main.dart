import 'package:flutter/material.dart';

import 'demo/control_panel.dart';
import 'demo/demo_content.dart';
import 'fold/fold_effect.dart';
import 'fold/fold_parameters.dart';
import 'motion/fold_motion_channel.dart';
import 'motion/fold_motion_model.dart';

/// Launch-time overrides, mirroring FoldMotionModel.swift's
/// `TILT_DEGREES` environment variable and `manualTilt` default:
///
///     flutter run -d <device> --dart-define=TILT_DEGREES=-20 --dart-define=MANUAL_TILT=true
///
/// `double.fromEnvironment` does not exist; the angle is parsed from a string.
const String _tiltDegreesDefine = String.fromEnvironment(
  'TILT_DEGREES',
  defaultValue: '0',
);
const bool _manualTiltDefine = bool.fromEnvironment('MANUAL_TILT');

/// The `TILT_DEGREES` dart-define as a finite double; 0 when absent or bad.
double launchTiltDegrees() {
  final double? value = double.tryParse(_tiltDegreesDefine);
  return value != null && value.isFinite ? value : 0;
}

/// The `MANUAL_TILT` dart-define; false when absent.
bool launchManualTilt() => _manualTiltDefine;

void main() {
  runApp(const FoldApp());
}

class FoldApp extends StatelessWidget {
  const FoldApp({
    super.key,
    this.params = const FoldParameters(),
    this.motionChannel = const PlatformMotionChannel(),
    this.initialTiltDegrees,
    this.forceManual,
  });

  final FoldParameters params;

  /// Injected by tests; the real bridge otherwise.
  final MotionChannel motionChannel;

  /// Overrides the dart-defines; tests pass these explicitly.
  final double? initialTiltDegrees;
  final bool? forceManual;

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
        motionChannel: motionChannel,
        initialTiltDegrees: initialTiltDegrees ?? launchTiltDegrees(),
        forceManual: forceManual ?? launchManualTilt(),
      ),
    );
  }
}

/// ContentView.swift: full-screen glass ([FoldEffect] over [DemoContent])
/// with the floating controls at the bottom-trailing corner, outside the
/// effect. Motion starts on appear and stops on disappear.
class FoldScreen extends StatefulWidget {
  const FoldScreen({
    super.key,
    required this.params,
    required this.motionChannel,
    required this.initialTiltDegrees,
    required this.forceManual,
  });

  final FoldParameters params;
  final MotionChannel motionChannel;
  final double initialTiltDegrees;
  final bool forceManual;

  @override
  State<FoldScreen> createState() => _FoldScreenState();
}

class _FoldScreenState extends State<FoldScreen> {
  late final FoldMotionModel _model = FoldMotionModel(
    channel: widget.motionChannel,
    initialManualDegrees: widget.initialTiltDegrees,
    forceManual: widget.forceManual,
  );

  @override
  void initState() {
    super.initState();
    _model.start();
  }

  @override
  void dispose() {
    _model.dispose();
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
            listenable: _model,
            builder: (BuildContext context, Widget? child) {
              return FoldEffect(
                angle: _model.theta,
                params: widget.params,
                child: child!,
              );
            },
            child: const DemoContent(),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(child: ControlPanel(model: _model)),
          ),
        ],
      ),
    );
  }
}
