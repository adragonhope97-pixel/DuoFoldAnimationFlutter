import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Dark glyphs over the light page, and transparent bars on Android so the
/// Flutter view — and with it the area the shader samples — is the whole
/// screen, as the iOS window is under the status bar and home indicator.
/// `SystemUiOverlayStyle.dark` would paint the Android navigation bar opaque
/// black (its `systemNavigationBarColor` is `0xFF000000`). On iOS only
/// `statusBarBrightness` applies, and it is what `.dark` set there too.
const SystemUiOverlayStyle kSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw under the status and navigation bars so the sampled area is the
  // whole screen on every Android version (15+ enforces this; older versions
  // inset the view by default). On iOS this only re-asserts the visible
  // status bar and home indicator.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
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
      title: 'DuoLikeAnimation',
      debugShowCheckedModeBanner: false,
      // Light, like the original running in the light appearance (see
      // Docs/demo.png). Seeded with systemBlue because SwiftUI's default
      // `.accentColor` is systemBlue; the demo content itself hard-codes
      // every colour and does not read this theme.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOverlayStyle,
      child: Scaffold(
        // Black is what the shader paints where a ray misses the interface.
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
      ),
    );
  }
}
