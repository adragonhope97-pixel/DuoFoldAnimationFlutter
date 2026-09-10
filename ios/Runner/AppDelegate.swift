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
