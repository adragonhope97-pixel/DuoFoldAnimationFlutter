import 'dart:ui' as ui;

/// Loads the fold [ui.FragmentProgram] once per process and hands out
/// [ui.FragmentShader] instances.
///
/// [assetKey] must equal the entry under `flutter: shaders:` in pubspec.yaml.
class FoldShader {
  FoldShader._(this._program);

  static const String assetKey = 'shaders/duo_fold.frag';

  static FoldShader? _instance;

  final ui.FragmentProgram _program;

  /// Resolves to the process-wide instance, loading the program on first use.
  ///
  /// The instance is cached, not the future: every call creates a new future
  /// in the caller's zone. A cached future would be bound to the zone that
  /// created it, which under `flutter test` is one test's FakeAsync zone —
  /// later tests would wait on it forever. `FragmentProgram.fromAsset` already
  /// caches the compiled program, so repeat calls are cheap. A failed load
  /// caches nothing, so the next call retries.
  static Future<FoldShader> load() async {
    final FoldShader? cached = _instance;
    if (cached != null) {
      return cached;
    }
    final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
      assetKey,
    );
    return _instance ??= FoldShader._(program);
  }

  /// A new shader instance. The caller owns it and must call `dispose()`.
  ui.FragmentShader createShader() => _program.fragmentShader();
}
