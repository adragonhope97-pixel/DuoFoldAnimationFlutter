# 003 motion

## Goal

When this phase is done the tilt fed to the shader comes from the iPhone's
gyroscope-fused attitude exactly as in the original: `FoldMotionModel.swift`
runs verbatim inside the iOS Runner (Core Motion at 120 Hz, reference pose
latched on the first sample, rotation-matrix handedness resolved against
gravity, 0.04 s gyro prediction, 0.7 smoothing) and streams the tilt to Dart
over an `EventChannel`; Dart chooses between that stream and the manual
slider with the original's mode rules. The floating controls are
`ContentView.swift`'s: a frosted round button that reveals a frosted panel
with the readout, Recalibrate, a Manual-tilt switch and a −45…45° slider.
`FoldParameters` adopts the original's `pointsPerMillimeter = 6` (eye
distance 1920 px) and loses the clamp the original never had. The
implementer proves the build with `flutter build ios --debug --no-codesign`;
a human proves the effect on the iPhone against the checklist in
`## Acceptance`, which also carries the 002 review's H0–H5.

## Decisions

1. **The original repo is the bar.** Every choice below is "what the Swift
   does", and `context.md` gets a proposed hunk wherever it said otherwise
   (`## Math`, end).
2. **Motion = the original Swift, run natively.** `FoldMotionModel.swift`
   is ported line for line into `ios/Runner/AppDelegate.swift` as
   `FoldMotionBridge`, minus SwiftUI observation; its `motionTilt` is
   streamed to Dart. Same sensor (`CMMotionManager.startDeviceMotionUpdates`
   in the `xArbitraryZVertical` frame at `1/120` s), same gravity-based
   handedness latch (`|rowsScore − columnsScore| > 0.2`), same prediction
   (`rotationRate·screenY × 0.04`), same smoothing (`0.7`). No pub package
   can be "exactly like this": `flutter_rotation_sensor` gives an attitude
   but not the gravity vector the handedness resolution needs, and would
   force re-deriving axis conventions; `sensors_plus` would force our own
   fusion. The target is iOS only now.
3. **The bridge lives in `AppDelegate.swift`, no new Swift file.** Adding a
   file means editing `project.pbxproj` by hand; one file replacement does
   not. `CoreMotion` and `simd` auto-link from the imports. No
   `NSMotionUsageDescription`: `CMMotionManager` device motion needs none
   (only activity/pedometer APIs do).
4. **Messenger from the 3.47 UIScene template.** The Runner's
   `AppDelegate` already implements `FlutterImplicitEngineDelegate`; the
   bridge is created in `didInitializeImplicitFlutterEngine` from
   `engineBridge.applicationRegistrar.messenger()` (`FlutterApplicationRegistrar`
   is a `FlutterBaseRegistrar`, which vends the messenger — checked in
   `Flutter.framework/Headers/FlutterEngine.h` and `FlutterPlugin.h`).
   `SceneDelegate.swift` is untouched.
5. **Channels.** `duo_fold/motion` (method): `isAvailable → Bool`,
   `recalibrate → nil`. `duo_fold/motion/tilt` (event): `Double` radians,
   positive = right edge is the hinge, already smoothed and predicted,
   ~120 Hz while listened to. `onListen` starts device motion, `onCancel`
   stops it. `recalibrate` clears the reference, zeroes `motionTilt` and
   emits `0.0` so the readout snaps immediately.
6. **Dart `FoldMotionModel` mirrors the Swift class's surface**
   (`tiltAngle`, `usesManualTilt`, `manualDegrees`, `isMotionAvailable`,
   `motionTilt`, `start`, `stop`, `recalibrate`) and adds nothing else.
   Filtering stays native. The stream keeps running in manual mode as in
   the original (`start()` is unconditional there); Dart merely stops
   notifying while the slider is in charge, so the UI does not rebuild at
   120 Hz for a value it is not showing.
7. **Mode rule.** Manual iff `--dart-define=MANUAL_TILT=true` or motion is
   unavailable — the original's `defaults.bool("manualTilt") ||
   !isDeviceMotionAvailable`; the simulator/desktop/test case is covered by
   "unavailable" (the bridge is absent → `MissingPluginException` → false).
   Slider range −45…45° in 0.5° steps (`divisions: 180`), the original's.
   `TILT_DEGREES` keeps seeding `manualDegrees`.
8. **`ManualTilt` deleted**; its role is absorbed by `FoldMotionModel`, as
   in the original where one model has both modes. `TiltSource`
   (`theta`, `isLive`) stays as the interface `FoldEffect`'s caller reads.
9. **`FoldParameters` → the original's fields**: `eyeDistanceMm = 320`,
   `pointsPerMm = 6` (Flutter logical px equal iOS points; 6 pt/mm is the
   original's constant and the closer figure for 460 ppi @3x panels), so
   `eyeDistancePx = 1920`. `maxTiltDeg`, `maxTiltRad`, `pxPerMm`,
   `blurTaps` removed (the original clamps nothing; taps are the blur
   phase's business). `maxBlurPx`/`dimStrength` remain as placeholders for
   uniform slots 4/5 until the blur phase adopts `blurSpread`/`darkening`.
10. **Controls parity with `ContentView.swift`.** Bottom-trailing, 16 px
    padding: a 44×44 frosted circle button (`Icons.tune` ↔
    `slider.horizontal.3`, `Icons.close` ↔ `xmark`) toggling a 280 px
    frosted panel (corner radius 20, padding 16) containing: the readout
    `tiltAngle` in degrees to one decimal with tabular figures + `°`;
    `Recalibrate` with `Icons.center_focus_strong` (↔ `scope`), disabled
    when manual or motion is unavailable; `Manual tilt` switch, disabled
    when motion is unavailable; the slider with `-45°`/`45°` labels,
    disabled unless manual. Panel appears with fade + slide-from-bottom over
    250 ms (↔ `.move(edge: .bottom).combined(with: .opacity)`, `.snappy`).
    "Frosted" = `BackdropFilter` blur σ 24 under a 62 % surface tint (↔
    `.ultraThinMaterial`); the panel sits outside the effect, so the
    backdrop is the shaded frame.
11. **One acknowledged extra**: an 11 pt footer line in the panel
    (`motion|manual · dpr · W×H lpx`). The checklist needs it and the panel
    is hidden by default, so the default look still matches. The parity
    sweep removes it.
12. **Readout is `Expanded` with `maxLines: 1`.** In the test font every
    glyph is `fontSize` wide, so "Recalibrate" alone is 154 px; the dry-run
    overflowed the row by 53 px. Real fonts fit; the row is now robust
    either way.
13. **Tests**: a `FakeMotionChannel` drives `FoldMotionModel` (manual when
    unavailable, follows the stream, recalibrate, forced manual, stop
    cancels); `FoldApp` composes with the panel closed and opens it; the
    reprojection probes are re-derived for D = 1920 (all margins ≥ 9 px)
    and gain the dpr-2 probe test the 002 review specified.
14. **Validation split.** Implementer: `flutter build ios --debug
    --no-codesign` compiles Dart + Swift + the Metal shader stage and links
    CoreMotion; the plan checks the linked dylib for the framework and the
    channel names. Human, on the iPhone: `## Acceptance` item 5. This
    sandbox has no window server; macOS is no longer a run target.
15. **Theme stays dark** until 004 ports `DemoContentView` (light).
16. **Lifecycle as the original**: start on screen init, stop on dispose
    (`onAppear`/`onDisappear`); no background/foreground handling.
17. **Dry-run before hand-off**: all blocks below were placed in a scratch
    copy of the 002 tree with an iOS host: `flutter analyze` clean,
    `flutter test` 11/11, `dart format` 0 changes, `flutter build ios
    --debug --no-codesign` OK; `Runner.debug.dylib` links
    `CoreMotion.framework`, carries 69 `FoldMotionBridge` symbols and both
    channel strings; the Metal-only shader stage is 2768 bytes.

## Files

### `ios/Runner/AppDelegate.swift` — full replacement

```swift
import CoreMotion
import Flutter
import UIKit
import simd

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var motionBridge: FoldMotionBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    motionBridge = FoldMotionBridge(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Port of FoldMotionModel.swift (elijah-semyonov/DuoLikeAnimation) minus the
/// SwiftUI observation. The algorithm is unchanged; the result is streamed to
/// Dart, which only chooses between this stream and the manual slider.
///
/// Channels:
///   duo_fold/motion       method   isAvailable → Bool,  recalibrate → nil
///   duo_fold/motion/tilt  event    Double, radians, positive = the right edge
///                                  is the hinge; smoothed and gyro-predicted;
///                                  ~120 Hz while listened to.
final class FoldMotionBridge: NSObject, FlutterStreamHandler {
  private let motionManager = CMMotionManager()
  private let methods: FlutterMethodChannel
  private let events: FlutterEventChannel
  private var sink: FlutterEventSink?

  private var reference: simd_double3x3?
  /// Whether `CMRotationMatrix` rows hold the device axes expressed in the reference frame.
  /// Resolved empirically against the gravity vector on the first informative sample.
  private var rowsAreDeviceAxes: Bool?
  /// Fraction of the remaining error closed per sample. Kept high: the attitude is already
  /// fused, and every extra frame of filtering is visible as lag between the hand and the screen.
  private let smoothing = 0.7
  /// How far ahead to extrapolate with the gyroscope, to cover sensor and display latency.
  private let predictionInterval = 0.04
  private var motionTilt = 0.0

  init(messenger: FlutterBinaryMessenger) {
    methods = FlutterMethodChannel(name: "duo_fold/motion", binaryMessenger: messenger)
    events = FlutterEventChannel(name: "duo_fold/motion/tilt", binaryMessenger: messenger)
    super.init()
    events.setStreamHandler(self)
    methods.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "isAvailable":
        result(self.motionManager.isDeviceMotionAvailable)
      case "recalibrate":
        self.recalibrate()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    sink = eventSink
    start()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    sink = nil
    return nil
  }

  // MARK: - FoldMotionModel (verbatim logic)

  private func start() {
    guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
    // Gyro-only reference frame: the magnetometer-corrected variants trade latency for
    // long-term yaw stability, and yaw is exactly the axis this effect tracks.
    motionManager.deviceMotionUpdateInterval = 1.0 / 120.0
    motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
      guard let self, let motion else { return }
      self.process(motion)
    }
  }

  private func stop() {
    motionManager.stopDeviceMotionUpdates()
  }

  /// Makes the current pose the zero-tilt pose: the plane the UI stays in.
  private func recalibrate() {
    reference = nil
    motionTilt = 0
    sink?(0.0)
  }

  private func process(_ motion: CMDeviceMotion) {
    let deviceToReference = deviceToReferenceMatrix(motion)
    guard let reference else {
      self.reference = deviceToReference
      return
    }

    // Current device axes expressed in the calibrated device frame.
    let relative = reference.transpose * deviceToReference
    let normal = relative.columns.2                     // current screen normal
    let (screenX, screenY) = screenAxesInDeviceSpace()
    let measured = atan2(simd_dot(normal, screenX), normal.z)

    // Extrapolate along the rotation rate around the screen's Y axis.
    let rate = SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
    let predicted = measured + simd_dot(rate, screenY) * predictionInterval

    motionTilt += (predicted - motionTilt) * smoothing
    sink?(motionTilt)
  }

  /// Rotation taking device-frame vectors to reference-frame vectors (column-vector convention).
  private func deviceToReferenceMatrix(_ motion: CMDeviceMotion) -> simd_double3x3 {
    let m = motion.attitude.rotationMatrix
    let asRows = simd_double3x3(rows: [
      SIMD3(m.m11, m.m12, m.m13),
      SIMD3(m.m21, m.m22, m.m23),
      SIMD3(m.m31, m.m32, m.m33),
    ])

    if rowsAreDeviceAxes == nil {
      // Gravity is reported in the device frame and points down (-Z in a Z-vertical reference).
      // Compare it against what each matrix convention predicts and latch the better match.
      let gravity = simd_normalize(SIMD3(motion.gravity.x, motion.gravity.y, motion.gravity.z))
      let down = SIMD3(0.0, 0.0, -1.0)
      let rowsScore = simd_dot(gravity, asRows * down)
      let columnsScore = simd_dot(gravity, asRows.transpose * down)
      if abs(rowsScore - columnsScore) > 0.2 {
        rowsAreDeviceAxes = rowsScore > columnsScore
      }
    }
    return (rowsAreDeviceAxes ?? true) ? asRows.transpose : asRows
  }

  /// Screen-space X (right) and Y (up) axes of the interface, in device coordinates.
  private func screenAxesInDeviceSpace() -> (x: SIMD3<Double>, y: SIMD3<Double>) {
    let orientation = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.interfaceOrientation ?? .portrait
    switch orientation {
    case .landscapeLeft:        return (SIMD3(0, 1, 0), SIMD3(-1, 0, 0))
    case .landscapeRight:       return (SIMD3(0, -1, 0), SIMD3(1, 0, 0))
    case .portraitUpsideDown:   return (SIMD3(-1, 0, 0), SIMD3(0, -1, 0))
    default:                    return (SIMD3(1, 0, 0), SIMD3(0, 1, 0))
    }
  }
}
```

### `lib/fold/fold_parameters.dart` — full replacement

```dart
/// Physical parameters of the frosted-glass fold. Mirrors `FoldParameters`
/// in FoldEffect.swift (elijah-semyonov/DuoLikeAnimation) field for field.
///
/// Immutable; derive variants with [copyWith].
class FoldParameters {
  const FoldParameters({
    this.eyeDistanceMm = 320,
    this.pointsPerMm = 6,
    this.maxBlurPx = 24,
    this.dimStrength = 0.6,
  });

  /// Distance from the viewer's eyes to the untilted screen, looking at it
  /// head-on. The eye stays there while the device tilts. A typical
  /// hand-held distance is about 30 cm. (Swift: `eyeDistanceMillimeters`.)
  final double eyeDistanceMm;

  /// Approximate density of logical px (iOS points) on current iPhone panels:
  /// about 460 ppi at 3x and 326 ppi at 2x, both close to 6 pt/mm.
  /// (Swift: `pointsPerMillimeter`.) Deliberately not devicePixelRatio.
  final double pointsPerMm;

  /// Placeholder for uniform slot 4 until the blur phase adopts the
  /// original's `blurSpread`. Unused by the shader before then.
  final double maxBlurPx;

  /// Placeholder for uniform slot 5 until the blur phase adopts the
  /// original's `darkening`. Range 0..1. Unused by the shader before then.
  final double dimStrength;

  /// [eyeDistanceMm] in logical px — the value the shader receives as
  /// `uEyeDistPx`. 320 mm × 6 px/mm = 1920 px, as in the original.
  double get eyeDistancePx => eyeDistanceMm * pointsPerMm;

  FoldParameters copyWith({
    double? eyeDistanceMm,
    double? pointsPerMm,
    double? maxBlurPx,
    double? dimStrength,
  }) {
    return FoldParameters(
      eyeDistanceMm: eyeDistanceMm ?? this.eyeDistanceMm,
      pointsPerMm: pointsPerMm ?? this.pointsPerMm,
      maxBlurPx: maxBlurPx ?? this.maxBlurPx,
      dimStrength: dimStrength ?? this.dimStrength,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoldParameters &&
        other.eyeDistanceMm == eyeDistanceMm &&
        other.pointsPerMm == pointsPerMm &&
        other.maxBlurPx == maxBlurPx &&
        other.dimStrength == dimStrength;
  }

  @override
  int get hashCode =>
      Object.hash(eyeDistanceMm, pointsPerMm, maxBlurPx, dimStrength);

  @override
  String toString() {
    return 'FoldParameters(eyeDistanceMm: $eyeDistanceMm, '
        'pointsPerMm: $pointsPerMm, maxBlurPx: $maxBlurPx, '
        'dimStrength: $dimStrength)';
  }
}
```

### `lib/motion/fold_motion_channel.dart` — new

```dart
import 'package:flutter/services.dart';

/// The native Core Motion bridge (ios/Runner/AppDelegate.swift).
///
/// The Swift side runs the original FoldMotionModel algorithm — reference
/// pose, gravity-resolved matrix handedness, gyro prediction, smoothing —
/// and streams the resulting tilt in radians. Dart only chooses between that
/// stream and the manual slider. Abstract so tests can inject a fake.
abstract class MotionChannel {
  /// Whether device motion exists on this platform.
  Future<bool> isAvailable();

  /// Tilt in radians, signed per context.md (positive: right edge is the
  /// hinge), already smoothed and predicted, ~120 Hz while listened to.
  Stream<double> tiltStream();

  /// Makes the current pose the zero-tilt pose.
  Future<void> recalibrate();
}

/// [MotionChannel] over the real platform channels. Reports "unavailable"
/// wherever the bridge is not registered (macOS, tests, web).
class PlatformMotionChannel implements MotionChannel {
  const PlatformMotionChannel();

  static const MethodChannel _methods = MethodChannel('duo_fold/motion');
  static const EventChannel _events = EventChannel('duo_fold/motion/tilt');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _methods.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Stream<double> tiltStream() {
    return _events.receiveBroadcastStream().map(
      (Object? event) => (event! as num).toDouble(),
    );
  }

  @override
  Future<void> recalibrate() async {
    try {
      await _methods.invokeMethod<void>('recalibrate');
    } on MissingPluginException {
      // No bridge on this platform; nothing to reset.
    }
  }
}
```

### `lib/motion/fold_motion_model.dart` — new

```dart
import 'dart:async';
import 'dart:math' as math;

import 'fold_motion_channel.dart';
import 'tilt_source.dart';

/// Dart half of FoldMotionModel.swift: chooses between the native motion
/// stream and the manual slider, and exposes the same surface the original
/// control panel binds to (`tiltAngle`, `usesManualTilt`, `manualDegrees`,
/// `isMotionAvailable`, `start`, `stop`, `recalibrate`).
///
/// Filtering and prediction live on the native side; the stream is used as is.
class FoldMotionModel extends TiltSource {
  FoldMotionModel({
    this._channel = const PlatformMotionChannel(),
    double initialManualDegrees = 0,
    this._forceManual = false,
  }) : _manualDegrees = _clampDegrees(initialManualDegrees);

  /// Slider range in ContentView.swift: −45…45° in 0.5° steps.
  static const double maxManualDegrees = 45;

  final MotionChannel _channel;
  final bool _forceManual;

  bool _started = false;
  bool _isMotionAvailable = false;
  bool _usesManualTilt = true;
  double _manualDegrees;
  double _motionTilt = 0;
  StreamSubscription<double>? _subscription;

  static double _clampDegrees(double degrees) =>
      degrees.clamp(-maxManualDegrees, maxManualDegrees).toDouble();

  /// Tilt fed to the shader, radians. Positive: the right edge is the hinge.
  double get tiltAngle =>
      _usesManualTilt ? _manualDegrees * math.pi / 180 : _motionTilt;

  @override
  double get theta => tiltAngle;

  @override
  bool get isLive => !_usesManualTilt && _isMotionAvailable;

  bool get isMotionAvailable => _isMotionAvailable;

  /// Latest native tilt, radians (0 until the first sample after calibration).
  double get motionTilt => _motionTilt;

  bool get usesManualTilt => _usesManualTilt;

  set usesManualTilt(bool value) {
    final bool next = value || !_isMotionAvailable;
    if (next == _usesManualTilt) {
      return;
    }
    _usesManualTilt = next;
    notifyListeners();
  }

  double get manualDegrees => _manualDegrees;

  set manualDegrees(double value) {
    final double next = _clampDegrees(value);
    if (next == _manualDegrees) {
      return;
    }
    _manualDegrees = next;
    notifyListeners();
  }

  /// Queries availability, picks the initial mode (manual when motion is
  /// missing or [forceManual]), and subscribes to the native stream. The
  /// stream runs even in manual mode, as in the original, so switching back
  /// is instant.
  Future<void> start() async {
    _started = true;
    final bool available = await _channel.isAvailable();
    if (!_started) {
      return; // stopped while awaiting
    }
    _isMotionAvailable = available;
    _usesManualTilt = _forceManual || !available;
    notifyListeners();
    if (available && _subscription == null) {
      _subscription = _channel.tiltStream().listen(
        _onTilt,
        onError: _onStreamError,
      );
    }
  }

  void stop() {
    _started = false;
    _subscription?.cancel();
    _subscription = null;
  }

  /// Makes the current pose the zero-tilt pose: the plane the UI stays in.
  Future<void> recalibrate() async {
    _motionTilt = 0;
    notifyListeners();
    await _channel.recalibrate();
  }

  void _onTilt(double radians) {
    _motionTilt = radians;
    if (!_usesManualTilt) {
      notifyListeners();
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _isMotionAvailable = false;
    _usesManualTilt = true;
    _subscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
```

### `lib/motion/manual_tilt.dart` — delete

`git rm lib/motion/manual_tilt.dart`. Nothing else references it after the
replacements below.

### `lib/demo/control_panel.dart` — full replacement

```dart
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
```

### `lib/main.dart` — full replacement

```dart
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
```

### `test/widget_test.dart` — full replacement

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    });

    test('copyWith and equality', () {
      const FoldParameters p = FoldParameters();
      expect(p.copyWith(), p);
      expect(p.copyWith(pointsPerMm: 6.3), isNot(p));
      expect(p.copyWith(eyeDistanceMm: 400).eyeDistancePx, 2400);
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
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byType(Slider), findsNothing); // panel closed by default

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('-20.0°'), findsOneWidget);
      expect(find.text('Recalibrate'), findsOneWidget);
      expect(find.text('Manual tilt'), findsOneWidget);
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, -20);
      expect(slider.min, -45);
      expect(slider.max, 45);
      expect(slider.onChanged, isNotNull); // manual mode: slider enabled
    });

    testWidgets(
      'fold shader loads in the test renderer and enables the sampler',
      (WidgetTester tester) async {
        // Driven by pump(): never await the loader before the first pump.
        await tester.pumpWidget(
          FoldApp(motionChannel: FakeMotionChannel(available: false)),
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
  });
}
```

### `test/reprojection_test.dart` — full replacement

```dart
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
  testWidgets('θ = 0 is the identity: split at the centre, no black', (
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
```

Unchanged this phase: `shaders/duo_fold.frag`, `lib/fold/fold_effect.dart`,
`lib/fold/fold_shader.dart`, `lib/motion/tilt_source.dart`,
`lib/demo/demo_content.dart`, `pubspec.yaml`, `ios/Runner/SceneDelegate.swift`,
`ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`.

## Math

### Motion model (native, verbatim from `FoldMotionModel.swift`)

Frames: the device frame has x right, y up, z out of the screen toward the
viewer. `M` is Core Motion's `attitude.rotationMatrix` in the
`xArbitraryZVertical` reference frame (gravity along −Z of the reference).

```
R      = rowsAreDeviceAxes ? Mᵀ : M          // device → reference, column-vector convention
R_ref  = R at the first sample after (re)calibration
rel    = R_refᵀ · R                          // current device axes in the calibrated device frame
n      = rel.columns.2                       // current screen normal
θ_meas = atan2(n · x_s, n_z)                 // x_s = screen right in device coords (portrait: +x)
θ_pred = θ_meas + (ω · y_s) · 0.04           // ω = rotationRate (rad/s), y_s = screen up (portrait: +y)
θ     += (θ_pred − θ) · 0.7                  // per sample at 120 Hz; this θ is streamed
```

Handedness latch, once, on the first sample where it is decisive:
`g = normalize(gravity)`, `down = (0, 0, −1)`,
`rowsScore = g · (M·down)`, `columnsScore = g · (Mᵀ·down)`; if
`|rowsScore − columnsScore| > 0.2` then `rowsAreDeviceAxes = rowsScore >
columnsScore`; until then `Mᵀ` is assumed.

Sign check against `context.md`: tilting the right edge away from the
viewer turns the screen normal toward the viewer's right, i.e. `n · x_s >
0`, so `θ > 0` ⇒ hinge on the right edge — the same convention the shader
uses (`xh = θ > 0 ? W : 0`). The original's own doc comment says the same
("Positive: the right edge is farther from the viewer").

Landscape axes as in the original (`screenAxesInDeviceSpace`); this phase
is accepted in portrait only.

### Eye distance

`D = eyeDistanceMm · pointsPerMm = 320 · 6 = 1920 px` (was 2015.7). All 002
formulas hold with the new `D`; wedge height at the lifted edge
`h_w(W) = H·W·sin|θ| / (2D)`:

| Case | 20° | 45° |
|---|---|---|
| test 400×300 | 10.7 px (rows 0–10 / 289–299 black) | — |
| iPhone 393×852 | 29.8 px | 61.7 px |
| iPhone 390×844 | 29.4 px | 60.8 px |

Probe re-derivation (θ = −20°, W 400, H 300, D 1920): far edge `|u| =
399.5`, `G.z = 136.64`, `t = 1920/1783.36 = 1.07663`; rows 0, 5 →
`hit.y = −11.1, −5.6` black; row 20 → 10.6 inside; row 280 → 290.5 inside;
rows 294, 299 → 305.6, 311.0 black. Centre `|u| = 200.5`, `t = 1.03704`,
`hit.x = 188.0` (θ<0) / `213.0` (θ>0). Hinge column `t = 1.00009`. Smallest
margin 9.5 px. At dpr 2 the physical pixel `(798, y)` has logical centre
`x = 399.25` and the predictions move by < 0.1 px; probes at physical
`(2x, 2y)` therefore hold.

### Proposed `context.md` hunks (main session routes to the implementer)

Hunk A — Flutter mapping table, motion row:

```
-| `CMMotionManager` attitude | Preferred: `flutter_rotation_sensor` (game-rotation-vector on Android, `CMDeviceMotion` on iOS). Fallback: `sensors_plus` gyro + accelerometer with our own complementary filter. Last resort: a small `MethodChannel`/`EventChannel` to `CMMotionManager` (`XArbitraryZVertical`) and Android `TYPE_GAME_ROTATION_VECTOR`. The architect chooses in phase 004. |
+| `CMMotionManager` attitude | `FoldMotionModel.swift` ported verbatim into `ios/Runner/AppDelegate.swift` (`FoldMotionBridge`), streamed over `EventChannel` `duo_fold/motion/tilt`; `MethodChannel` `duo_fold/motion` for `isAvailable`/`recalibrate`. Dart `FoldMotionModel` only switches between the stream and the slider. iOS only; chosen in 003 for exact fidelity. |
```

Hunk B — coordinate conventions, eye-distance bullet:

```
-- Eye distance is converted from mm to logical px on the Dart side:
-  `pxPerMm = 160 / 25.4` (Flutter logical px are 1/160 in by definition).
-  Do **not** use `devicePixelRatio` for this.
+- Eye distance is converted from mm to logical px on the Dart side with the
+  original's constant: `pointsPerMm = 6` (Flutter logical px equal iOS
+  points; ≈ 6 pt/mm on current panels), so the default eye is 1920 px.
+  Do **not** use `devicePixelRatio` for this.
```

Hunk C — tilt convention bullet, last sentence:

```
-  `xh = θ > 0 ? W : 0`. The motion model is responsible for producing θ in
-  this convention after resolving the rotation-matrix handedness against
-  gravity (see gotchas).
+  `xh = θ > 0 ? W : 0`. The native motion bridge produces θ in this
+  convention (the original's `atan2(n·screenX, n.z)` after resolving the
+  rotation-matrix handedness against gravity). θ is not clamped; only the
+  manual slider is bounded (−45…45°, 0.5° steps), as in the original.
```

Hunk D — tunables table:

```
-| eyeDistanceMm | 320 | from the Swift default |
+| eyeDistanceMm | 320 | Swift `eyeDistanceMillimeters` |
+| pointsPerMm | 6 | Swift `pointsPerMillimeter`; eye = 1920 px |
 …
-| blurTaps | 16 | compile-time constant in GLSL; 24 is the ceiling. Metal: clamp(int(radius·2), 6, 32) adaptive taps, Vogel disk, per-pixel hash rotation. |
-| maxTiltDeg | 35 | clamp on |θ| from the motion model |
+| (blur taps) | — | the blur phase uses the original's `clamp(int(radius·2), 6, 32)` under a constant loop bound; no Dart tunable |
```

Hunk E — package targets:

```
-flutter_rotation_sensor: latest   # phase 004, architect confirms
-sensors_plus: latest         # fallback only
+# No sensor package: motion is the original Swift in ios/Runner (003).
```

Hunk F — file layout:

```
   motion/
     tilt_source.dart         # TiltSource (ChangeNotifier): theta (rad, signed), isLive
-    fold_motion_model.dart   # attitude → θ, calibration, prediction
-    manual_tilt.dart         # slider-driven θ source (same interface)
+    fold_motion_channel.dart # MotionChannel + PlatformMotionChannel (method/event channels)
+    fold_motion_model.dart   # mode logic: native stream vs manual slider; recalibrate
+ios/Runner/AppDelegate.swift # FoldMotionBridge: FoldMotionModel.swift verbatim + channels
```

Hunk G — gotchas, append:

```
+- 3.47 iOS template is UIScene-based: app-level channels are created in
+  `didInitializeImplicitFlutterEngine` from
+  `engineBridge.applicationRegistrar.messenger()`. `SceneDelegate.swift`
+  stays empty.
+- A debug iOS build's `Runner` executable is a stub that loads
+  `Runner.debug.dylib`; check linked frameworks and symbols on the dylib.
+- `CMMotionManager` device motion needs no Info.plist usage key.
+- Widget-test text uses a fixed-width test font (glyph width = font size);
+  size rows for it or they overflow in tests only.
```

Proposed `CLAUDE.md` hunk — phases 3–5:

```
-3. `003-blur-dim` — variable-radius disk blur and dimming proportional to
-   glass–plane gap. Tap-count budget respected.
-4. `004-motion` — device attitude → tilt angle. Calibrate zero pose on
-   first sample, recalibrate button, gyro prediction, hinge side resolved
-   against gravity at runtime.
-5. `005-polish` — floating control panel (recalibrate / manual mode /
-   slider), tunables surface, demo content screen.
+3. `003-motion` — the original's Core Motion model run natively and
+   streamed to Dart; ContentView's controls; original parameters.
+4. `004-demo-content` — `DemoContentView` ported to pure Flutter.
+5. `005-blur-dim` — the original's Vogel-disk blur and darkening, exact
+   constants, under a constant loop bound.
+6. `006-parity` — whatever a human still sees differ on the iPhone.
```

## Commands

Run from the repo root, in this order (002 is committed; the main session
commits after review).

```sh
# 1. Write the files in ## Files; remove the absorbed source.
git rm -q lib/motion/manual_tilt.dart

# 2. Format, analyze, test. `dart format` should report 0 changed.
dart format lib test
flutter analyze
flutter test

# 3. Compile Dart + Swift + the Metal shader stage for the device, no signing.
flutter build ios --debug --no-codesign
ls build/ios/iphoneos/Runner.app/Frameworks/App.framework/flutter_assets/shaders/
otool -L build/ios/iphoneos/Runner.app/Runner.debug.dylib | grep CoreMotion
strings build/ios/iphoneos/Runner.app/Runner.debug.dylib | grep "duo_fold/motion"

# 4. Confirm the change set.
git status --short
```

Not for the implementer — the main session / human, with the phone
unlocked, on the same Wi-Fi, held upright in portrait:

```sh
flutter run -d 00008120-000278980AE3601E
# and once, for the manual-mode check:
flutter run -d 00008120-000278980AE3601E --dart-define=MANUAL_TILT=true --dart-define=TILT_DEGREES=-20
```

## Acceptance

1. `flutter analyze` prints `No issues found!`.
2. `flutter test` prints `All tests passed!` — 11 tests (2 FoldParameters,
   3 FoldMotionModel, 2 FoldApp, 4 reprojection incl. dpr 2).
3. `flutter build ios --debug --no-codesign` ends with `✓ Built
   build/ios/iphoneos/Runner.app`; the `ls` lists `duo_fold.frag`; `otool`
   prints the `CoreMotion.framework` line; `strings` prints both
   `duo_fold/motion` and `duo_fold/motion/tilt`.
4. `git status --short` shows exactly: `M ios/Runner/AppDelegate.swift`,
   `M lib/demo/control_panel.dart`, `M lib/fold/fold_parameters.dart`,
   `M lib/main.dart`, `D lib/motion/manual_tilt.dart`,
   `M test/reprojection_test.dart`, `M test/widget_test.dart`,
   `?? lib/motion/fold_motion_channel.dart`,
   `?? lib/motion/fold_motion_model.dart`, `?? docs/plans/003-motion.md`
   (plus `M` on it once the report is appended). Nothing else; nothing under
   `android/`, `macos/`, or `ios/` other than `AppDelegate.swift`.
5. **Device checklist** — human, iPhone `00008120-000278980AE3601E`, record
   PASS/FAIL per line in this file's `## Review`.

   ```
   H0  flutter run -d 00008120-000278980AE3601E. First frame. Tap the round
       button at the bottom-right: the panel opens; its last line reads
       "motion · dpr 3.00 · 393×852 lpx" (or your model's numbers). Note them.

   H1  [002 item 0]  With the phone held still the readout is near 0.0° and
       the demo interface fills the screen edge to edge: 2 px white frame on
       all four edges, nothing drawn at 2×/3× in the top-left, no black.
       FAIL = the interface shrunk into the top-left quarter/ninth with black
       elsewhere. If FAIL, stop and report; judge nothing below.

   M1  Panel state on launch: "Manual tilt" switch OFF, Recalibrate enabled,
       slider greyed out.

   M2  [sign]  Slowly turn the phone about its vertical axis so the RIGHT
       edge moves away from you (left edge toward you): the readout goes
       POSITIVE; the right border and the content along the right edge stay
       unchanged; black triangles grow at the top-LEFT and bottom-LEFT
       corners. Turn the LEFT edge away: readout NEGATIVE, wedges top-RIGHT
       and bottom-RIGHT, left border unchanged. (A wrong sign shows wedges
       on the edge you moved away — report it as "sign inverted".)

   M3  [tracking]  Rock the phone gently ±20°: the picture follows the hand
       with no visible lag and no jitter when you hold still. Hold at about
       20°: wedges ≈ 30 px tall at the lifted edge (about two lines of
       body text); at 45° ≈ 60 px.

   M4  [recalibrate]  Hold the phone tilted ~20°, tap Recalibrate: readout
       snaps to 0.0° and the picture flattens; further motion is measured
       from the new pose (turn back to upright: readout ≈ −20°).

   M5  [manual switch]  Toggle "Manual tilt" ON: slider enabled, Recalibrate
       greyed; drag the slider to −20: readout −20.0°, wedges at the right.
       Toggle OFF: motion resumes immediately from the live pose.

   M6  [stability]  Hold still for 10 s at ~15°: readout drifts by < 0.5°.
       Leave the app (home), come back: effect still follows the hand.

   M7  [manual launch]  Second run with --dart-define=MANUAL_TILT=true
       --dart-define=TILT_DEGREES=-20: opens at −20.0° with the switch ON.

   H5  Console: no exception, no RangeError, no impellerc line, no
       MissingPluginException during any of the above.
   ```

   H1 closes the 002 review's item 0 (Impeller `FlutterFragCoord()`); the
   002 review's H2–H4 (wedge geometry, keystone, sweep) are covered by M2,
   M3 and M5 and need not be repeated.
6. `## Implementation report` appended to this file.

## Out of scope

- Blur, dimming, any change to `shaders/duo_fold.frag`,
  `fold_effect.dart`, `fold_shader.dart`, the uniform table.
- The `DemoContentView` port (004); the light theme.
- `ios/Runner/SceneDelegate.swift`, `Info.plist`, `project.pbxproj`,
  `Podfile`; anything under `android/` or `macos/`.
- Adding pub packages; `pubspec.yaml` is untouched.
- Landscape/upside-down acceptance (the axes logic is ported; not judged).
- Background/foreground lifecycle handling beyond the original's
  appear/disappear.
- Removing the panel's debug footer line (parity sweep).
- Applying the proposed `context.md`/`CLAUDE.md` hunks (routed by the main
  session); committing or pushing.

## Implementation report

STATUS: DONE

Files written:
- `lib/motion/fold_motion_channel.dart`
- `lib/motion/fold_motion_model.dart`

Files edited:
- `ios/Runner/AppDelegate.swift` — full replacement per plan: `FoldMotionBridge`
  (Core Motion, verbatim `FoldMotionModel.swift` algorithm) wired into the
  UIScene-template `AppDelegate` via `didInitializeImplicitFlutterEngine`.
- `lib/fold/fold_parameters.dart` — full replacement: `eyeDistanceMm`/`pointsPerMm`
  fields, `maxBlurPx`/`dimStrength` kept as placeholders, `maxTiltDeg` etc. removed.
- `lib/demo/control_panel.dart` — full replacement: frosted round button + panel
  (readout, Recalibrate, Manual tilt switch, slider, debug footer line).
- `lib/main.dart` — full replacement: `FoldApp`/`FoldScreen` compose `FoldMotionModel`,
  `ControlPanel`, dart-define launch overrides.
- `test/widget_test.dart` — full replacement: `FakeMotionChannel`, `FoldMotionModel`
  and `FoldApp` tests.
- `test/reprojection_test.dart` — full replacement: probes re-derived for D = 1920.

Files deleted:
- `lib/motion/manual_tilt.dart` (`git rm`)

Deviations from plan: none.

Self-fixes applied: none — dry run in the plan's `## Decisions` (item 17)
already exercised this exact file set; no compile or analyzer issues arose.

Command results:
  dart format lib test — 0 changed (11 files)
  flutter analyze — clean (No issues found!)
  flutter test — All tests passed! (11/11: 2 FoldParameters, 3 FoldMotionModel,
    2 FoldApp, 4 reprojection incl. dpr 2)
  flutter build ios --debug --no-codesign — ok: "✓ Built build/ios/iphoneos/Runner.app"
  ls .../flutter_assets/shaders/ — duo_fold.frag, ink_sparkle.frag, stretch_effect.frag
  otool -L Runner.debug.dylib | grep CoreMotion — /System/Library/Frameworks/CoreMotion.framework/CoreMotion present
  strings Runner.debug.dylib | grep "duo_fold/motion" — both `duo_fold/motion` and
    `duo_fold/motion/tilt` present
  git status --short — matches Acceptance item 4 exactly (before this report's edit)
  flutter run … — not run (device acceptance deferred to the user per instructions)

Open questions for architect: none.

## Review

STATUS: REVISE

Scope of what was checked: `git diff 158f96d` plus the two untracked `lib/motion/`
files; every code block in `## Files` extracted and `diff`ed against the file on
disk (**all eight byte-identical**, `manual_tilt.dart` deleted, nothing else
touched); `flutter analyze` re-run here (`No issues found!`); `flutter test`
re-run here (`+11 All tests passed!`); the D = 1920 probe arithmetic re-derived
from the shader source; `FoldMotionModel.swift`, `FoldEffect.swift` and
`ContentView.swift` re-fetched from the source repo and compared against the
port. The implementer's report is accurate: **zero deviations**. The three
corrections below are defects in the plan I wrote, not in its execution.

### A. Swift check — `FoldMotionBridge` vs `FoldMotionModel.swift`, line by line

Original re-fetched from
`raw.githubusercontent.com/elijah-semyonov/DuoLikeAnimation/main/DuoLikeAnimation/FoldMotionModel.swift`.

| Original | Port | Verdict |
|---|---|---|
| `guard let reference else { reference = deviceToReference; return }` | same, with explicit `self.` | identical (implicit `self` in the original; the shadowed binding is out of scope in the `else`) |
| `let relative = reference.transpose * deviceToReference` | same | identical |
| `let normal = relative.columns.2` | same | identical |
| `atan2(simd_dot(normal, screenX), normal.z)` | same | identical |
| `measured + simd_dot(rate, screenY) * predictionInterval` | same | identical |
| `motionTilt += (predicted - motionTilt) * smoothing` | same | identical |
| `smoothing = 0.7`, `predictionInterval = 0.04` | same literals, same types | identical |
| `deviceMotionUpdateInterval = 1.0 / 120.0`, `.xArbitraryZVertical`, `to: .main` | same | identical |
| `guard isMotionAvailable, !motionManager.isDeviceMotionActive` | `guard motionManager.isDeviceMotionAvailable, !…isDeviceMotionActive` | equivalent (the original caches the same property in `init`) |
| `MainActor.assumeIsolated { self?.process(motion) }` | `guard let self, let motion else { return }; self.process(motion)` | equivalent: `to: .main` already delivers on the main thread, which is also the platform thread the sink requires |
| `asRows = simd_double3x3(rows: [m11…m33])` | same | identical |
| `gravity = simd_normalize(...)`, `down = (0,0,-1)` | same | identical |
| `rowsScore = g·(asRows*down)`, `columnsScore = g·(asRowsᵀ*down)` | same | identical |
| `if abs(rowsScore - columnsScore) > 0.2 { rowsAreDeviceAxes = rowsScore > columnsScore }` | same | identical, including the 0.2 threshold and the "latch once, never reset" behaviour |
| `return (rowsAreDeviceAxes ?? true) ? asRows.transpose : asRows` | same | identical (Mᵀ assumed until the latch is decisive) |
| `screenAxesInDeviceSpace()` four cases | same four cases, same vectors | identical |
| `recalibrate() { reference = nil; motionTilt = 0 }` | same **+ `sink?(0.0)`** | accepted: plan Decision 5; required so the Dart readout snaps without waiting for the next sample. Linear in θ, no effect on the filter state |
| (no streaming) | `sink?(motionTilt)` at the end of `process` | accepted: the reason the port exists |

Sign convention, derived here rather than taken from the report:
`R_refᵀ·R` maps current-device coordinates into the calibrated-device frame;
`columns.2` is therefore the current screen normal in that frame.
`R_y(φ)·(0,0,1) = (sin φ, 0, cos φ)`, so `θ = atan2(n·x_s, n_z) = φ` for a
rotation of `+φ` about the device up-axis; the same rotation sends the right
edge `(1,0,0) → (cos φ, 0, −sin φ)`, i.e. **away from the viewer** (viewer at
+z). So `θ > 0` ⇔ right edge farther ⇔ right edge is the hinge ⇔ shader
`xh = uSize.x`. This agrees with `context.md`, with the original's own doc
comment ("Positive means the right edge is farther from the viewer"), and with
the `θ = +20°` probe in `test/reprojection_test.dart` (black at `(0,0)`).
Prediction sign agrees: `ω·y_s > 0` is exactly `dφ/dt > 0`.

Consequence worth recording (finding, drives correction 4 below): if the
handedness latch picks the wrong branch, the code computes
`R_ref·Rᵀ = (R·R_refᵀ)ᵀ`, the *inverse* relative rotation — i.e. a wrong latch
manifests as **θ inverted, nothing else**. The latch is resolved from live data
at the first decisive sample, so it is not provable at build time and can in
principle differ between launches/poses. The sign check is therefore the single
load-bearing device test, and it must be run **at rest** (the 0.04 s prediction
adds up to ±6° transiently at 100 °/s) and **repeated after a cold relaunch in a
different starting attitude**.

### B. Parity check against the other two Swift files

`FoldEffect.swift` re-fetched: `eyeDistanceMillimeters = 320`,
`pointsPerMillimeter = 6`, `blurSpread = 0.12`, `darkening = 0.015`,
`eyeDistancePoints = 320 × 6 = 1920`. `FoldParameters` here matches the first
two exactly; `maxBlurPx`/`dimStrength` remain as slot-4/5 placeholders per
Decision 9 — correct for this phase, replaced in 005.

`ContentView.swift` re-fetched: `VStack(alignment: .trailing, spacing: 10)`,
44×44 circle, `.ultraThinMaterial`, `.move(edge:.bottom).combined(with:.opacity)`,
panel `.padding(16).frame(width: 280).background(…, in: .rect(cornerRadius: 20))`,
readout `.precision(.fractionLength(1))` + `monospacedDigit()`, `Recalibrate`
`.disabled(usesManualTilt || !isMotionAvailable)`, `Toggle("Manual tilt")`
`.disabled(!isMotionAvailable)`, `Slider(in: -45...45, step: 0.5)` with
`"-45°"`/`"45°"` labels `.disabled(!usesManualTilt)`. `control_panel.dart`
reproduces all of it. Two cosmetic gaps, deferred to the parity sweep, **not**
corrections now: (i) the original's `spacing: 12` between the three panel rows
is absent (Material rows supply their own height); (ii) the original does not
clamp `manualDegrees` at init while `_clampDegrees` does — ours is the safer
behaviour and is pinned by a test.

Dart mode rule matches the original's
`defaults.bool("manualTilt") || !isDeviceMotionAvailable`, and the original's
`#if targetEnvironment(simulator) usesManualTilt = true` is reproduced for free
(the simulator reports device motion unavailable).

### C. Math check

Re-derived independently from `shaders/duo_fold.frag` (unchanged this phase)
with D = 1920, W = 400, H = 300, |θ| = 20°:
far edge `u = 399.5`, `G.z = 136.637`, `t = 1.076618` (plan: 1.07663 ✓);
`hit.y` at `py = 0.5, 5.5, 20.5, 280.5, 294.5, 299.5` = `−10.95, −5.57, 10.10,
290.51, 305.60, 310.98` — the probes sit 5.5–10.1 px clear of a boundary, as
claimed; far-edge `hit.x = 388.9 < 400` so the blue probes are legitimately
inside. Centre `t = 1.037038`, `hit.x = 187.98` (plan: 188.0 ✓), 12 px clear of
the split. Hinge column `t = 1.000089`. At dpr 2 the logical fragment centres
are `x = 399.25 / 200.25`, moving every prediction by < 0.35 px; all ten 2×
probes hold. Wedge height `h_w = H·W·sin|θ| / (2D)` re-derived from
`hit.y(py) = 0` → 29.8 px at 20° and 61.7 px at 45° on 393×852. All confirmed.

### Corrections (apply verbatim, then re-run `dart format lib test`, `flutter analyze`, `flutter test`)

1. **`lib/motion/fold_motion_model.dart`, lines 114–119** — a stream error
   orphans the subscription instead of cancelling it, so `onCancel` never
   reaches Swift, Core Motion keeps running at 120 Hz for the life of the
   process, and `stop()` can no longer reach it.

   Current:
   ```dart
     void _onStreamError(Object error, StackTrace stackTrace) {
       _isMotionAvailable = false;
       _usesManualTilt = true;
       _subscription = null;
       notifyListeners();
     }
   ```
   Required:
   ```dart
     /// A platform error ends the stream's usefulness: cancel it — which stops
     /// Core Motion through the bridge's `onCancel` — and fall back to the
     /// slider for good. Cancelling from inside `onError` is legal.
     void _onStreamError(Object error, StackTrace stackTrace) {
       _subscription?.cancel();
       _subscription = null;
       _isMotionAvailable = false;
       _usesManualTilt = true;
       notifyListeners();
     }
   ```

2. **`lib/motion/tilt_source.dart`, lines 5–10** — the doc contract now names a
   deleted class and promises a clamp that this phase deliberately removed.

   Current:
   ```dart
   /// θ is in radians and signed per context.md: θ > 0 means the RIGHT edge is
   /// the hinge (the left edge lifts toward the viewer). Implementations clamp
   /// |θ| to the configured maximum before notifying listeners.
   ///
   /// Phase 001 provides `ManualTilt`; phase 004 adds the sensor-driven model
   /// behind the same interface so main.dart's composition does not change.
   ```
   Required:
   ```dart
   /// θ is in radians and signed per context.md: θ > 0 means the RIGHT edge is
   /// the hinge (the left edge lifts toward the viewer). θ is NOT clamped: the
   /// original clamps nothing, and only the manual slider is bounded (±45°).
   ///
   /// `FoldMotionModel` is the only implementation: it switches between the
   /// native Core Motion stream and the manual slider behind this interface,
   /// so main.dart's composition does not change.
   ```

3. **`test/widget_test.dart`** — pin correction 1. Insert the following block
   between line 119 (`    });`, the end of the `forceManual` test) and line 120
   (`  });`, the end of the `FoldMotionModel` group), keeping the blank line:

   ```dart

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
   ```

   `## Acceptance` item 2 is amended by this review: **12** tests
   (2 FoldParameters, 4 FoldMotionModel, 2 FoldApp, 4 reprojection).

4. **`## Acceptance` item 5 is superseded by the checklist below.** No file
   changes; the implementer does nothing for this item. The plan's M2 asked for
   one PASS/FAIL over two independent observations (readout sign and wedge
   side), which cannot distinguish "native θ inverted" from "shader hinge side
   inverted", did not say to judge at rest, and did not defend the reference
   pose — the zero pose is latched on the *first sample after launch*, so a
   phone lying on a desk when `flutter run` attaches calibrates to that pose and
   the first pick-up can read anything (near 90° of relative pitch, `n_z → 0`
   and `atan2` is degenerate). The replacement fixes all three.

   ```
   D0  Hold the phone in portrait, screen facing you at arm's ease, BEFORE the
       app's first frame appears. Launch:
         flutter run -d 00008120-000278980AE3601E
       If the first frame looks skewed or black-wedged while you are holding it
       square, that is the reference pose, not a bug: open the panel, tap
       Recalibrate, and note "D0 recalibrated".

   D1  Tap the round button at the bottom-right. Panel opens. Record its last
       line verbatim, e.g. "motion · dpr 3.00 · 393×852 lpx".

   D2  [identity; closes 002 acceptance 0 / H1]  Holding still and square, the
       readout is within ±1.0° of 0.0 and the demo interface fills the screen:
       2 px white frame visible on all four edges, no black anywhere, nothing
       drawn at 2×/3× scale in the top-left. FAIL here = stop, report, judge
       nothing below.

   D3  [mode]  Switch "Manual tilt" is OFF, Recalibrate is enabled, the slider
       is greyed out.

   D4  [SIGN — the load-bearing test]  Slowly turn the phone about its vertical
       axis so the RIGHT edge moves AWAY from you and the left edge comes
       toward you, roughly 20°. STOP and hold still for two seconds before
       judging (the 0.04 s gyro prediction overshoots while you are moving).
       Record two things separately, as observations, not as PASS/FAIL:
         D4a  the sign of the readout:            POSITIVE / NEGATIVE
         D4b  which corners the black triangles are in:  LEFT / RIGHT
       Then read off the verdict:
         POSITIVE + LEFT   → PASS, the whole chain is correct.
         NEGATIVE + RIGHT  → "native sign inverted": Swift θ has the wrong
                             sign; the shader is fine.
         POSITIVE + RIGHT  → "shader hinge inverted": a 002 regression; the
                             Swift is fine.
         NEGATIVE + LEFT   → both inverted.
       Also confirm, at the same pose, that the RIGHT border of the white frame
       is unbroken and the content along it is unshifted (the hinge edge samples
       itself).

   D5  [mirror]  Turn the other way, LEFT edge away, ~20°, hold, judge: the
       readout must be NEGATIVE and the triangles must be in the RIGHT corners,
       with the LEFT border unbroken. If D4 and D5 do not mirror each other,
       report both readings.

   D6  [magnitude]  Note the motion-mode readout while holding a pose (say
       −20.0°). Toggle "Manual tilt" ON and drag the slider until it reads the
       same number. The picture must look the same in both modes: same wedge
       height, same shift. A visible difference means the streamed radians are
       being scaled somewhere. Wedge height at 20° should be ≈ 30 logical px at
       the lifted edge (two lines of body text); at 45°, ≈ 60 px.

   D7  [tracking]  Back in motion mode, rock the phone gently ±20° for five
       seconds: the picture follows the hand with no perceptible lag, and stops
       dead — no jitter, no creep — when you stop.

   D8  [recalibrate]  Hold at about +20° (right edge away), tap Recalibrate:
       the readout snaps to 0.0° and the picture flattens. Now turn back to
       square-to-your-face: the readout must go to about −20°, wedges on the
       RIGHT. (Sign here is a second, independent check of D4.)

   D9  [manual switch]  Toggle "Manual tilt" ON: slider enabled, Recalibrate
       greyed. Drag to −20: readout −20.0°, wedges on the RIGHT. Sweep the
       slider end to end: continuous, no popping through 0. Toggle OFF: motion
       resumes immediately from the live pose.

   D10 [cold relaunch, different pose]  Quit the app. Hold the phone pitched
       back about 30° (as if reading in bed), still portrait, and launch again.
       Repeat D4 exactly. It must give the same verdict as the first run. This
       is the only way to exercise the runtime gravity/handedness latch a second
       time; a differing verdict means the latch is not decisive in that pose
       and must be reported with both readings.

   D11 [stability]  Hold still for 10 s at about 15°: the readout drifts less
       than 0.5°. Press home, wait 5 s, return: the effect still follows the
       hand. (Expect the readout to keep its old zero pose across a hot restart
       too — that is by design; tap Recalibrate after one.)

   D12 [launch overrides]  Second run:
         flutter run -d 00008120-000278980AE3601E \
           --dart-define=MANUAL_TILT=true --dart-define=TILT_DEGREES=-20
       Opens with the switch ON, readout −20.0°, wedges on the RIGHT, motion
       ignored.

   D13 [console]  Across all of the above: no exception, no RangeError, no
       MissingPluginException, no impellerc line in the flutter run output.
   ```

   Report format: one line per item, `D4a POSITIVE / D4b LEFT` style for D4.
   Any FAIL comes back to the architect as a debug request with the item id,
   the two observations, and the panel's D1 line — not as prose.

## Implementation report (revision)

STATUS: DONE

Files written: none (all files pre-existed; only edits below).

Files edited:
- `lib/motion/fold_motion_model.dart` — correction 1: `_onStreamError` now
  cancels `_subscription` (and nulls it) before falling back to manual, so a
  platform error reaches Swift's `onCancel` and stops Core Motion.
- `lib/motion/tilt_source.dart` — correction 2: doc comment no longer names
  the deleted `ManualTilt` class or promises a clamp; now says θ is
  unclamped and names `FoldMotionModel` as the sole implementation.
- `test/widget_test.dart` — correction 3: added the
  `'a stream error cancels the subscription and falls back'` test to the
  `FoldMotionModel` group, pinning correction 1.
- `context.md` — all nine proposed hunks applied: A (motion mapping row),
  B (eye-distance bullet), C (tilt convention bullet), D (tunables table:
  eyeDistanceMm/pointsPerMm rows, blur-taps row), E (package targets), F
  (file layout: fold_motion_channel.dart, AppDelegate.swift), G (gotchas:
  UIScene channel creation, dylib stub, no Info.plist key, fixed-width test
  font), H (gotchas: zero-pose latch on first sample, handedness-latch
  inversion behaviour, hot-restart survival), I (tunables: maxBlurPx/
  dimStrength reworded as slot placeholders with the confirmed
  blurSpread/darkening constants). Hunks D and I both target the tunables
  table rows for maxBlurPx/dimStrength; applied as one final edit matching
  I's text (I supersedes D's wording for those two rows; D's
  eyeDistanceMm/pointsPerMm/blur-taps rows applied as given).

Deviations from plan: none. `CLAUDE.md` not touched, per instruction.

Self-fixes applied: none.

Command results:
  dart format lib test — 0 changed (11 files)
  flutter analyze — clean (No issues found!)
  flutter test — All tests passed! (12/12: 2 FoldParameters, 4 FoldMotionModel,
    2 FoldApp, 4 reprojection incl. dpr 2)
  flutter build ios --debug --no-codesign — ok: "✓ Built build/ios/iphoneos/Runner.app"
  ls .../flutter_assets/shaders/ — duo_fold.frag, ink_sparkle.frag, stretch_effect.frag
  otool -L Runner.debug.dylib | grep CoreMotion — CoreMotion.framework present
  strings Runner.debug.dylib | grep "duo_fold/motion" — both `duo_fold/motion` and
    `duo_fold/motion/tilt` present
  git status --short — M context.md, M ios/Runner/AppDelegate.swift,
    M lib/demo/control_panel.dart, M lib/fold/fold_parameters.dart, M lib/main.dart,
    D lib/motion/manual_tilt.dart, M lib/motion/tilt_source.dart,
    M test/reprojection_test.dart, M test/widget_test.dart, ?? docs/plans/003-motion.md,
    ?? lib/motion/fold_motion_channel.dart, ?? lib/motion/fold_motion_model.dart.
    Not committed, per instruction.

Open questions for architect: none.

### Proposed `context.md` hunks

Hunks A–G in this plan's `## Math` are still unapplied (`context.md` at
`158f96d` still advertises `flutter_rotation_sensor`, `pxPerMm = 160/25.4`,
`maxTiltDeg = 35` and `blurTaps`); they remain correct as written — route them.
Two more, from this review:

Hunk H — "Gotchas already known", append:

```
+- The zero pose is latched on the first Core Motion sample after launch or
+  after Recalibrate, in `FoldMotionBridge`. Launching with the phone flat on
+  a desk calibrates to that pose; θ is then measured from it and `atan2`
+  degenerates as the relative pitch approaches 90°. Hold the phone as you
+  intend to use it before the first frame, or recalibrate.
+- The handedness latch is resolved from live gravity data at the first
+  decisive sample and is never reset. A wrong latch computes the inverse
+  relative rotation, i.e. it shows up as θ inverted and nothing else — which
+  is why the device sign check is repeated after a cold relaunch in a
+  different attitude.
+- The reference pose and the latch survive a Dart hot restart (they live in
+  the native bridge); re-listening only replaces the event sink. Tap
+  Recalibrate after a hot restart.
```

Hunk I — "Tunables", replace the `maxBlurPx` / `dimStrength` rows (confirmed
verbatim from `FoldEffect.swift`: `blurSpread = 0.12`, `darkening = 0.015`):

```
-| maxBlurPx | 24 | logical px at g = 1. Metal instead: blurSpread = 0.12 px per px of gap → 26.8 px at 35° on a 390-wide screen. 003 decides which semantics to keep. |
-| dimStrength | 0.6 | fraction removed at g = 1. Metal instead: darkening = 0.015 per px of blur radius → 0.40 removed at the same point. 003 decides. |
+| maxBlurPx | 24 | placeholder holding uniform slot 4 since 003. Slot 5's `darkening` semantics win in 005: `radius = blurSpread · gap`, `blurSpread = 0.12`. |
+| dimStrength | 0.6 | placeholder holding uniform slot 5 since 003. 005 adopts `attenuation = max(1 − darkening · radius, 0)`, `darkening = 0.015`. |
```

### Out of scope for the revision

`ios/Runner/AppDelegate.swift` (verified correct — do not touch),
`shaders/duo_fold.frag`, `lib/fold/`, `lib/main.dart`, `lib/demo/`,
`test/reprojection_test.dart`, `pubspec.yaml`, `context.md`, `CLAUDE.md`.
Only corrections 1–3 change files.

## Review (revision)

STATUS: ACCEPTED (everything checkable from the tree). The device checklist
D0–D13 is unrun and stays **PENDING** — it is the user's, not the
implementer's, and no status below depends on it.

### What was checked, and how

Not from the report. Every code block in `## Files` was re-extracted from the
plan and byte-compared against the file on disk; the only differences are
corrections 1 and 3, verbatim. `git diff context.md` was compared hunk by hunk
against the nine proposed hunks. The build artefacts were inspected directly.
The new test was proved to pin the fix by breaking the fix in a throwaway copy
of the tree (`/private/tmp/.../scratchpad/proj`, never the repo) and watching
it fail.

### Corrections 1–3

| # | File | Verdict |
|---|---|---|
| 1 | `lib/motion/fold_motion_model.dart` 114–123 | applied verbatim, including the three-line doc comment; `_subscription?.cancel()` precedes `_subscription = null`, which precedes the two flag writes and `notifyListeners()` |
| 2 | `lib/motion/tilt_source.dart` 5–11 | applied verbatim; no reference to `ManualTilt` or to a clamp survives anywhere in `lib/` or `test/` (`grep -rn 'ManualTilt'` matches only `usesManualTilt`/`launchManualTilt`), and `lib/motion/manual_tilt.dart` is staged deleted |
| 3 | `test/widget_test.dart` 120–134 | applied verbatim at sibling indentation, inside the `FoldMotionModel` group, after the `forceManual` test |

**Correction 3 pins correction 1 — proved, not assumed.** In a copy of the tree
I removed exactly the `_subscription?.cancel();` line and re-ran:

```
FoldMotionModel a stream error cancels the subscription and falls back [E]
  Expected: false
    Actual: <true>
```

i.e. the test fails on `expect(channel.tilt.hasListener, isFalse)`. The
mechanism is the right one: `listen(onError:)` defaults to
`cancelOnError: false`, so on a broadcast controller the subscription survives
an error and the native `onCancel` — the thing that stops Core Motion — is
never sent. The test observes the subscription's existence at the controller,
which is the closest Dart-side proxy for "the bridge got `onCancel`". The three
flag assertions that follow (`isMotionAvailable`, `usesManualTilt`, `isLive`)
still pass without the fix, so they are ballast, not the pin; the `hasListener`
line is load-bearing and is the one that fails. Accepted.

No other file changed. `dart format --set-exit-if-changed lib test` → 0 changed
(11 files); `flutter analyze` → `No issues found!`; `flutter test` → `+12 All
tests passed!` (2 FoldParameters, 4 FoldMotionModel, 2 FoldApp, 4
reprojection). All three re-run here, not taken from the report.

### The nine `context.md` hunks

| Hunk | Target | Verdict |
|---|---|---|
| A | Flutter-mapping motion row | byte-identical to the proposal |
| B | eye-distance bullet (`pointsPerMm = 6`, 1920 px) | byte-identical |
| C | tilt-convention bullet (bridge produces θ; no clamp; slider ±45°/0.5°) | byte-identical |
| D | tunables: `eyeDistanceMm` reworded, `pointsPerMm` row added, `blurTaps` + `maxTiltDeg` rows replaced by the `(blur taps)` row | byte-identical; the `…` elision resolved correctly (rows kept in table order, `maxTiltDeg` gone) |
| E | package targets: both sensor packages replaced by the one comment line | byte-identical |
| F | file layout: `fold_motion_channel.dart`, `fold_motion_model.dart` reworded, `manual_tilt.dart` removed, `ios/Runner/AppDelegate.swift` line added | byte-identical |
| G | four gotchas (UIScene messenger, debug dylib stub, no Info.plist key, fixed-width test font) | byte-identical, appended in order |
| H | three gotchas (zero pose latched on first sample, wrong latch ⇒ θ inverted only, latch survives hot restart) | byte-identical, appended after G |
| I | tunables `maxBlurPx` / `dimStrength` rows | byte-identical |

D and I both target the `maxBlurPx`/`dimStrength` rows; the implementer applied
I's text and D's other rows, and said so. **Accepted** — that is the resolution
D's `…` elision implied and I's later authorship confirms. Nothing else in
`context.md` moved: the diff is exactly five edited regions plus the two
appended gotcha groups, and the uniform table, the file-layout shader/docs
lines and the reference-math block are untouched.

### New findings in `context.md` — my authorship debt, not the implementer's

The nine hunks landed correctly but were not a complete sweep: four places in
`context.md` still describe the world as it was before this phase, and one of
them instructs a future agent to build something that now exists in Swift.
`context.md` is read by both agents at the top of every phase, so these are
fixed **before the `phase 003: motion` commit**, in one implementer pass.
Apply verbatim; no code, no test, no plan file changes.

Hunk J — "Gotchas already known", the Core Motion handedness bullet
(currently lines 154–158):

```
-- On iOS the Core Motion rotation-matrix handedness must be resolved at
-  runtime against the gravity vector so the hinge lands on the correct
-  side; the Swift repo notes it doesn't trust the docs for this. Do the
-  same in Dart: on calibration, record which screen edge gravity favours
-  and derive the sign of θ from that, not from an assumed axis.
+- On iOS the Core Motion rotation-matrix handedness must be resolved at
+  runtime against the gravity vector so the hinge lands on the correct
+  side; the Swift repo notes it doesn't trust the docs for this. Done in
+  `FoldMotionBridge` since 003, in Swift, not in Dart: `rowsScore` vs
+  `columnsScore` against normalised gravity, latched once when they differ
+  by more than 0.2. Dart receives θ already in the sign convention above
+  and must never re-derive or re-sign it.
```

Hunk K — "Reference math", the `g` line (currently lines 79–84):

```
-g   = gap / (W·sin(maxTiltRad))     // 0..1; = 1 only at the far edge at max tilt.
-                                    // PROVISIONAL, 003 finalises. Metal uses the
-                                    // absolute gap (radius = blurSpread·gap); the old
-                                    // gap/(W·sin|θ|) made blur independent of tilt
-                                    // magnitude, which is wrong.
+r   = blurSpread · gap              // blur radius in logical px; blurSpread = 0.12.
+                                    // The ABSOLUTE gap, as in DuoFold.metal: no
+                                    // normalisation, because there is no maximum tilt
+                                    // any more — 003 deleted maxTiltDeg/maxTiltRad.
+                                    // Settled in the 003 review; 005 implements it.
```

and, immediately below the same code fence, the two bullets (currently lines
88–93):

```
-- Blur radius `r = uMaxBlurPx · g`. Disk blur with N taps (N ≤ 24), taps
-  on a golden-angle spiral or a fixed Poisson set; scale offsets by `r`.
-  Taps that land outside [0,1]² contribute black, not clamped edge.
-- Dim: `rgb *= 1 - uDimStrength · g` (linear is fine for v1; architect may
-  swap for a curve in 003).
+- Blur: golden-angle (Vogel) disk of radius `r`, tap count
+  `clamp(int(r·2), 6, 32)` evaluated under a constant GLSL loop bound; the
+  005 plan fixes the bound and the offset schedule. Taps that land outside
+  [0,1]² contribute black, not clamped edge.
+- Dim: `rgb *= max(1 − darkening · r, 0)` with `darkening = 0.015` (Metal's
+  `attenuation`). Slots 4 and 5 carry `blurSpread` and `darkening` from 005;
+  the uniform table is renamed by that plan, not before it.
```

and the first gotcha bullet, which names a tunable that no longer exists
(currently lines 152–153):

```
-- `AnimatedSampler` re-rasterises its child every frame the shader
-  repaints. Fine for a phone screen; keep `blurTaps` modest.
+- `AnimatedSampler` re-rasterises its child every frame the shader
+  repaints. Fine for a phone screen; keep the tap count modest.
```

Hunk L — "Tunables", the `maxBlurPx` row: my hunk I says "Slot 5's" where it
means slot 4's, in the slot-4 row.

```
-| maxBlurPx | 24 | placeholder holding uniform slot 4 since 003. Slot 5's `darkening` semantics win in 005: `radius = blurSpread · gap`, `blurSpread = 0.12`. |
+| maxBlurPx | 24 | placeholder holding uniform slot 4 since 003. In 005 the slot becomes `blurSpread = 0.12` with the Metal semantics: `radius = blurSpread · gap`. |
```

Hunk M — "Gotchas already known", the build-validation bullet (currently
lines 181–184); 003 Decision 14 retired the macOS route:

```
-- Build/compile validation: `flutter build macos --debug` (device-free;
-  compiles the same `--runtime-stage-metal` stage as iOS). Visual and
-  motion validation: `flutter run -d 00008120-000278980AE3601E` with a
-  human holding the phone and reporting against the plan's checklist.
+- Build/compile validation since 003: `flutter build ios --debug
+  --no-codesign` (device-free; compiles the Dart, the Swift bridge and the
+  same `--runtime-stage-metal` shader stage, and links CoreMotion). Visual
+  and motion validation: `flutter run -d 00008120-000278980AE3601E` with a
+  human holding the phone and reporting against the plan's checklist.
```

Not routed by me: `CLAUDE.md`'s phase list still reads "003-blur-dim /
004-motion / 005-polish" while the tree now holds 003 = motion. The plan's
proposed `CLAUDE.md` hunk is still unapplied and stays a decision for the user;
no agent edits `CLAUDE.md` on an agent's say-so.

### Build artefacts — verified here, not reported

On `build/ios/Debug-iphoneos/Runner.app/Runner.debug.dylib` (built 00:22 today,
i.e. after the corrections):

- `otool -L` → `/System/Library/Frameworks/CoreMotion.framework/CoreMotion`.
- `strings -a | grep duo_fold/motion` → exactly `duo_fold/motion` and
  `duo_fold/motion/tilt`.
- `nm -U | grep -c FoldMotionBridge` → 69 symbols.
- `Frameworks/App.framework/flutter_assets/shaders/` → `duo_fold.frag`
  (+ the two engine shaders).

Note for the record: in Flutter 3.47 the dylib is under
`build/ios/Debug-iphoneos/Runner.app/`, not `build/ios/iphoneos/Runner.app/`
(the latter has only the stub `Runner`). Immaterial to the result.

### Math re-check

`shaders/duo_fold.frag` is untouched this phase (`git status` clean for it) and
was re-read here: `xh = uAngle > 0.0 ? uSize.x : 0.0`, `u = p.x - xh`,
`G = (xh + u·cos|θ|, p.y, |u|·sin|θ|)`, `t = E.z / (E.z - G.z)` with the
`depth <= 1e-3` guard, black outside `[0,uSize]`, identity below `1e-5` — the
`context.md` reference math, unchanged. `fold_effect.dart` still binds
`setFloat` 0..5 in the fixed order with `p.eyeDistancePx` at slot 3, which is
now 1920, and `setImageSampler(0, …, FilterQuality.none)`. The Swift sign
derivation (`θ > 0` ⇔ right edge farther ⇔ hinge right ⇔ `xh = W`) was done in
the first review from `R_refᵀ·R` and is unaffected by the corrections.

### Acceptance ledger

| Item | Result |
|---|---|
| 1 `flutter analyze` | PASS — `No issues found!`, re-run here |
| 2 `flutter test` | PASS — 12/12, re-run here; the count amendment from the first review holds |
| 3 iOS build + artefacts | PASS — dylib, CoreMotion, both channel strings, `duo_fold.frag`, all verified here |
| 4 `git status --short` | PASS — the ten expected entries plus `M context.md`, which is the routed-hunks task, expected and correct |
| 5 device checklist D0–D13 | PENDING (user) |
| 6 report appended | PASS |

### Before the commit

1. Apply hunks J, K (three edits), L, M to `context.md`. Nothing else.
2. `flutter analyze` and `flutter test` are unaffected by doc edits; no re-run
   required.
3. Commit `phase 003: motion` with `context.md` included.
4. Run D0–D13 on the iPhone. Any FAIL comes back to me as a debug request with
   the item id, the two D4 observations and the D1 panel line.
