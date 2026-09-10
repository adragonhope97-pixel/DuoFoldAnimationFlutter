# 001 scaffold

## Goal

When this phase is done the repo has the file layout from `context.md`, a
macOS desktop host for device-free validation, `flutter_shaders` pinned, and
the full render pipeline proven end to end: `DemoContent` is rasterised by
`AnimatedSampler`, bound to `shaders/duo_fold.frag` through the fixed uniform
table (six float slots + sampler 0), and painted back 1:1 by a pass-through
shader. A slider (`ManualTilt`) and a `--dart-define=TILT_DEGREES` launch
value drive θ into the shader, which proves the sign convention by drawing a
marker on the hinge edge. `flutter analyze`, `flutter test` and
`flutter build macos --debug` all pass, and the visual run establishes that
`FlutterFragCoord()` is in logical px under Impeller. No reprojection, blur
or dimming exists yet.

## Decisions

1. **Validation target: macOS desktop** (`flutter create --platforms=macos .`).
   No device, no signing, `flutter run -d macos` renders a first frame
   unattended. Impeller is the macOS default in this SDK (verified:
   `FlutterDartProject.mm` → `enableImpeller` returns `YES` when
   `FLTEnableImpeller` is absent; official 3.47 notes agree), and
   `shader_compiler.dart` compiles `--runtime-stage-metal` for `darwin`
   exactly as for `ios`, so the macOS build is a faithful Metal shader
   compile check. `flutter build ios --no-codesign` is deferred: it adds
   only Xcode time, the shader stage is identical.
2. **`flutter_shaders` pinned exactly at `0.1.3`** — latest on pub.dev; it
   compiles on 3.47.1 (its `set_uniforms.dart` uses `Color.opacity/red`,
   which still exist in this SDK's `dart:ui`). Only `AnimatedSampler` is
   used. Not `ShaderBuilder` (global cache, reports load failures through
   `FlutterError` instead of the widget) and not `SetUniforms` (index-free
   API hides the fixed table).
3. **Uniforms are set by index** (`setFloat(i, …)`), not via the newer
   `getUniformFloat('name')` slot API — `context.md` fixes the table by
   index and the implementer must be able to check each call against it.
4. **Phase-001 shader = pass-through + hinge marker + parameter sentinel.**
   The sentinel (`if (uEyeDistPx <= 0 || …) → magenta`) keeps all six float
   uniforms live so the compiled uniform count equals the table;
   `setFloat(5, …)` would `RangeError` if the compiler dropped an unused
   uniform. The marker consumes `uAngle` and makes the θ sign checkable by
   eye.
5. **No `IMPELLER_TARGET_OPENGLES` uv flip.** The 3.47 release notes state
   OpenGLES shaders no longer need it, and Android is not a validation
   target.
6. **GLSL header `#version 320 es` + `precision highp float;`** — the idiom of
   Flutter's own bundled `ink_sparkle.frag` / `stretch_effect.frag`, known
   to pass this SDK's `impellerc`. No `layout(location = …)` qualifiers.
7. **`FoldEffect` owns one `FragmentShader`** created from the
   process-wide `FoldShader` instance, disposed in `dispose()`. While
   loading, the child paints unmodified (`AnimatedSampler(enabled: false)`);
   on failure a red `FoldShaderError` panel replaces the child. A silent
   fallback would look exactly like "no effect".
8. **`FoldShader` caches the loaded instance, never the `Future`.** A cached
   future is bound to the zone that created it; under `flutter test` that is
   one test's FakeAsync zone, and a later test awaiting it never resumes
   (tried: the second `FoldApp` test saw `enabled == false`). Each `load()`
   call creates its own future; `FragmentProgram.fromAsset` already caches
   the compiled program, so repeat calls are cheap.
9. **The sampler builder is a fresh closure every build.** `AnimatedSampler`
   compares builders with `==` and only re-adds its layer when the builder
   changed; a method tear-off compares equal and would freeze the effect at
   the first θ.
10. **Sampler filter `FilterQuality.none`** (nearest) — matches 002's
    nearest-sampling contract; changing it later is a one-word edit.
11. **New file `lib/motion/tilt_source.dart`** (`abstract class TiltSource
    extends ChangeNotifier { double get theta; bool get isLive; }`). Not in
    the `context.md` layout; added so `ManualTilt` (001) and the sensor
    model (004) share one interface and `main.dart` never changes.
    Proposed `context.md` hunk is in `## Math`.
12. **Control panel sits outside `FoldEffect`** — flat and usable, mirroring
    the floating panel in `ContentView.swift`. Recalibrate arrives in 004.
13. **Launch tilt via `String.fromEnvironment('TILT_DEGREES')` +
    `double.tryParse`** — `double.fromEnvironment` does not exist in Dart.
    Non-finite or unparsable → 0. `ManualTilt` clamps to ±`maxTiltDeg`.
14. **`flutter test` exercises the shader, driven by `pump()`.** `test.dart`
    builds the bundle for `TargetPlatform.tester` (`--sksl
    --runtime-stage-vulkan`), and `FragmentProgram.fromAsset` completes on a
    microtask that `pump` flushes. The test therefore never awaits the
    loader before its first pump — a bare `await FoldShader.load()` there
    hung for the full 10-minute test timeout when tried. Two pumps after
    `pumpWidget` are enough for the sampler to report `enabled == true`.
15. **Baseline git commit first** (Command 0). Review mode diffs against the
    last accepted commit; without a baseline there is nothing to diff.
16. **No `--org` on `flutter create`** — the tool infers `com.debojyoti` from
    `ios/` and `android/` (both agree); passing a different value errors.
17. **`analysis_options.yaml` untouched** — it already excludes `macos/**`.
18. **Demo content is deliberately busy**: 2 px white frame (edges for 002's
    black-outside), `GridPaper` fine lines and small text (blur for 003),
    saturated tiles (dimming for 003). Pure Flutter, no platform views.
19. **`FoldEffect` fills the whole screen; `DemoContent` applies `SafeArea`
    internally.** The glass is the full screen, the interface keeps its own
    insets.
20. **Dry-run before hand-off.** Every block under `## Files` was extracted
    into a scratch package outside the repo and passed `flutter analyze`
    (clean), `flutter test` (7/7), and `impellerc` with the darwin, ios and
    tester flag sets; Metal reflection lists `uSize uAngle uEyeDistPx
    uMaxBlurPx uDimStrength uTex`. The Dart blocks are `dart format` output
    (3.13 style), so Command 3's format step should change nothing — if it
    does, report the diff.

## Files

### `pubspec.yaml` — two edits

Hunk 1 (dependencies). Before:

```yaml
  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
```

After:

```yaml
  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  # AnimatedSampler: rasterises the child into a ui.Image for the shader.
  # Exact pin per context.md.
  flutter_shaders: 0.1.3
```

Hunk 2 (flutter section). Before:

```yaml
  # the material Icons class.
  uses-material-design: true
```

After:

```yaml
  # the material Icons class.
  uses-material-design: true

  # Compiled by impellerc at build time; loaded via FragmentProgram.fromAsset
  # with exactly this key (see lib/fold/fold_shader.dart).
  shaders:
    - shaders/duo_fold.frag
```

### `macos/` — generated, not hand-written

Created by Command 1. Do not edit anything under `macos/`. Command 1 also
rewrites `.metadata` (adds a `macos` platform entry) — accept that change.

### `shaders/duo_fold.frag` — new

```glsl
#version 320 es
// duo_fold.frag — phase 001: pass-through + hinge marker.
// Reprojection arrives in phase 002, blur and dimming in 003. Not here.

precision highp float;

#include <flutter/runtime_effect.glsl>

// Uniform layout is fixed by context.md. Float slots (Dart setFloat index):
//   uSize.x       0
//   uSize.y       1
//   uAngle        2
//   uEyeDistPx    3
//   uMaxBlurPx    4
//   uDimStrength  5
// Sampler slots (Dart setImageSampler index):
//   uTex          0
uniform vec2 uSize;          // logical px size of the sampled child
uniform float uAngle;        // tilt θ, radians; θ > 0 → hinge on the RIGHT edge
uniform float uEyeDistPx;    // eye distance, logical px (used from 002)
uniform float uMaxBlurPx;    // used from 003
uniform float uDimStrength;  // 0..1, used from 003
uniform sampler2D uTex;      // the rasterised child

out vec4 fragColor;

void main() {
  // FlutterFragCoord() is the local-space position of the drawRect that
  // used this shader: logical px, origin at the top-left of the FoldEffect.
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / uSize;

  vec4 color;
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
    color = vec4(0.0, 0.0, 0.0, 1.0);  // outside the child → opaque black
  } else {
    color = texture(uTex, uv);         // 1:1 pass-through
  }

  // Hinge marker (001 only): a 3 px vertical bar on the hinge edge.
  // xh = θ > 0 ? W : 0 is the rule 002 will use for reprojection.
  float xh = uAngle > 0.0 ? uSize.x : 0.0;
  if (abs(uAngle) > 1e-4 && abs(p.x - xh) < 3.0) {
    color = mix(color, vec4(1.0, 0.85, 0.0, 1.0), 0.85);
  }

  // Parameter sentinel: keeps every uniform live and makes bad values visible.
  if (uEyeDistPx <= 0.0 || uMaxBlurPx < 0.0 ||
      uDimStrength < 0.0 || uDimStrength > 1.0) {
    color = vec4(1.0, 0.0, 1.0, 1.0);  // magenta = invalid FoldParameters
  }

  fragColor = color;
}
```

### `lib/fold/fold_parameters.dart` — new

```dart
import 'dart:math' as math;

/// Tunables for the fold effect. Mirrors `FoldParameters` in the Swift source.
///
/// Immutable; derive variants with [copyWith]. Defaults come from
/// context.md → "Tunables".
class FoldParameters {
  const FoldParameters({
    this.eyeDistanceMm = 320,
    this.maxBlurPx = 24,
    this.dimStrength = 0.6,
    this.maxTiltDeg = 35,
  });

  /// Eye-to-interface distance in millimetres (Swift default: 320).
  final double eyeDistanceMm;

  /// Disk-blur radius in logical px at the far edge (g = 1).
  final double maxBlurPx;

  /// Fraction of brightness removed at the far edge (g = 1). Range 0..1.
  final double dimStrength;

  /// Clamp on |θ| in degrees. Every tilt source applies it before notifying.
  final double maxTiltDeg;

  /// Blur tap count. A compile-time constant in `shaders/duo_fold.frag`
  /// (ceiling 24), recorded here for display only — it is not a uniform.
  static const int blurTaps = 16;

  /// Logical px per millimetre: Flutter logical px are 1/160 in by
  /// definition and there are 25.4 mm per inch. Deliberately not
  /// devicePixelRatio (context.md → coordinate conventions).
  static const double pxPerMm = 160 / 25.4;

  /// [eyeDistanceMm] in logical px — the value the shader receives
  /// as `uEyeDistPx`.
  double get eyeDistancePx => eyeDistanceMm * pxPerMm;

  /// [maxTiltDeg] in radians.
  double get maxTiltRad => maxTiltDeg * math.pi / 180;

  FoldParameters copyWith({
    double? eyeDistanceMm,
    double? maxBlurPx,
    double? dimStrength,
    double? maxTiltDeg,
  }) {
    return FoldParameters(
      eyeDistanceMm: eyeDistanceMm ?? this.eyeDistanceMm,
      maxBlurPx: maxBlurPx ?? this.maxBlurPx,
      dimStrength: dimStrength ?? this.dimStrength,
      maxTiltDeg: maxTiltDeg ?? this.maxTiltDeg,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoldParameters &&
        other.eyeDistanceMm == eyeDistanceMm &&
        other.maxBlurPx == maxBlurPx &&
        other.dimStrength == dimStrength &&
        other.maxTiltDeg == maxTiltDeg;
  }

  @override
  int get hashCode =>
      Object.hash(eyeDistanceMm, maxBlurPx, dimStrength, maxTiltDeg);

  @override
  String toString() {
    return 'FoldParameters(eyeDistanceMm: $eyeDistanceMm, '
        'maxBlurPx: $maxBlurPx, dimStrength: $dimStrength, '
        'maxTiltDeg: $maxTiltDeg)';
  }
}
```

### `lib/fold/fold_shader.dart` — new

```dart
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
```

### `lib/fold/fold_effect.dart` — new

```dart
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
      ..setFloat(4, p.maxBlurPx) // uMaxBlurPx
      ..setFloat(5, p.dimStrength) // uDimStrength
      ..setImageSampler(0, image, filterQuality: FilterQuality.none); // uTex
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
      enabled: shader != null,
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
```

### `lib/motion/tilt_source.dart` — new

```dart
import 'package:flutter/foundation.dart';

/// A source of the tilt angle θ.
///
/// θ is in radians and signed per context.md: θ > 0 means the RIGHT edge is
/// the hinge (the left edge lifts toward the viewer). Implementations clamp
/// |θ| to the configured maximum before notifying listeners.
///
/// Phase 001 provides `ManualTilt`; phase 004 adds the sensor-driven model
/// behind the same interface so main.dart's composition does not change.
abstract class TiltSource extends ChangeNotifier {
  /// Current θ in radians.
  double get theta;

  /// True when θ comes from device sensors, false for slider control.
  bool get isLive;
}
```

### `lib/motion/manual_tilt.dart` — new

```dart
import 'dart:math' as math;

import 'tilt_source.dart';

/// Slider-driven [TiltSource]: degrees in, radians out, clamped to ±[maxDeg].
///
/// This is the default source whenever no sensor stream exists (desktop,
/// simulator, tests) and the only source in phase 001.
class ManualTilt extends TiltSource {
  ManualTilt({required this.maxDeg, double initialDeg = 0})
    : _degrees = _clamp(initialDeg, maxDeg);

  /// Clamp on |θ| in degrees (FoldParameters.maxTiltDeg).
  final double maxDeg;

  double _degrees;

  static double _clamp(double deg, double maxDeg) =>
      deg.clamp(-maxDeg, maxDeg).toDouble();

  /// θ in degrees, the slider's unit. Positive → hinge on the right edge.
  double get degrees => _degrees;

  set degrees(double value) {
    final double next = _clamp(value, maxDeg);
    if (next == _degrees) {
      return;
    }
    _degrees = next;
    notifyListeners();
  }

  @override
  double get theta => _degrees * math.pi / 180;

  @override
  bool get isLive => false;

  /// Back to θ = 0.
  void reset() => degrees = 0;
}
```

### `lib/demo/demo_content.dart` — new

```dart
import 'package:flutter/material.dart';

/// The interface the fold effect looks at. Pure Flutter only: platform views
/// are not captured by AnimatedSampler (context.md → gotchas).
///
/// Deliberately busy so later phases are checkable by eye: a 2 px white frame
/// makes the edges unmistakable (002: black outside), thin grid lines and
/// small text show blur (003), saturated tiles show dimming (003).
class DemoContent extends StatelessWidget {
  const DemoContent({super.key});

  static const List<({String label, IconData icon, Color color})> _tiles = [
    (
      label: 'Messages',
      icon: Icons.chat_bubble_outline,
      color: Color(0xFF34C759),
    ),
    (label: 'Photos', icon: Icons.photo_outlined, color: Color(0xFFFF9F0A)),
    (label: 'Maps', icon: Icons.map_outlined, color: Color(0xFF0A84FF)),
    (label: 'Music', icon: Icons.music_note_outlined, color: Color(0xFFFF375F)),
    (
      label: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      color: Color(0xFFFFD60A),
    ),
    (label: 'Weather', icon: Icons.cloud_outlined, color: Color(0xFF64D2FF)),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1C1C3A), Color(0xFF0B0B14)],
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: GridPaper(
        color: Colors.white.withValues(alpha: 0.10),
        interval: 80,
        divisions: 1,
        subdivisions: 4,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _StatusRow(),
                const SizedBox(height: 20),
                Text(
                  'Frosted glass',
                  style: text.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tilt the phone. The interface stays where it is; '
                  'the glass moves.',
                  style: text.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.extent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: <Widget>[
                      for (final tile in _tiles)
                        _Tile(
                          label: tile.label,
                          icon: tile.icon,
                          color: tile.color,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Text(
          '9:41',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        Spacer(),
        Icon(Icons.signal_cellular_alt, color: Colors.white, size: 16),
        SizedBox(width: 6),
        Icon(Icons.wifi, color: Colors.white, size: 16),
        SizedBox(width: 6),
        Icon(Icons.battery_full, color: Colors.white, size: 16),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: Colors.black87, size: 26),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### `lib/demo/control_panel.dart` — new

```dart
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
```

### `lib/main.dart` — full replacement

```dart
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
```

### `test/widget_test.dart` — full replacement

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphoneduo_animation_flutter/demo/control_panel.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_effect.dart';
import 'package:iphoneduo_animation_flutter/fold/fold_parameters.dart';
import 'package:iphoneduo_animation_flutter/main.dart';
import 'package:iphoneduo_animation_flutter/motion/manual_tilt.dart';

void main() {
  group('FoldParameters', () {
    test('defaults match context.md tunables', () {
      const FoldParameters p = FoldParameters();
      expect(p.eyeDistanceMm, 320);
      expect(p.maxBlurPx, 24);
      expect(p.dimStrength, 0.6);
      expect(p.maxTiltDeg, 35);
      expect(FoldParameters.blurTaps, 16);
    });

    test('eyeDistancePx converts with 160/25.4 px per mm', () {
      expect(const FoldParameters().eyeDistancePx, closeTo(2015.748, 0.001));
      expect(
        const FoldParameters(eyeDistanceMm: 25.4).eyeDistancePx,
        closeTo(160, 1e-9),
      );
    });

    test('copyWith and equality', () {
      const FoldParameters p = FoldParameters();
      expect(p.copyWith(), p);
      expect(p.copyWith(maxBlurPx: 8), const FoldParameters(maxBlurPx: 8));
      expect(p.copyWith(maxBlurPx: 8), isNot(p));
    });
  });

  group('ManualTilt', () {
    test('clamps to ±maxDeg and reports θ in radians', () {
      final ManualTilt tilt = ManualTilt(maxDeg: 35, initialDeg: -50);
      expect(tilt.degrees, -35);
      expect(tilt.theta, closeTo(-35 * math.pi / 180, 1e-12));
      tilt.degrees = 90;
      expect(tilt.degrees, 35);
      tilt.degrees = 20;
      expect(tilt.theta, greaterThan(0)); // θ > 0 ⇒ hinge on the right edge
      tilt.dispose();
    });

    test('notifies only when the clamped value changes', () {
      final ManualTilt tilt = ManualTilt(maxDeg: 35);
      int notified = 0;
      tilt.addListener(() => notified++);
      tilt.degrees = 10;
      tilt.degrees = 10; // no change
      tilt.degrees = 40; // clamps to 35
      tilt.degrees = 50; // still 35: no change
      tilt.reset();
      expect(notified, 3);
      tilt.dispose();
    });
  });

  group('FoldApp', () {
    testWidgets('composes demo content, fold effect and panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const FoldApp(initialTiltDegrees: -20));
      await tester.pump();
      expect(find.byType(FoldEffect), findsOneWidget);
      expect(find.byType(DemoContent), findsOneWidget);
      expect(find.byType(ControlPanel), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('θ -20.0°'), findsOneWidget);
      expect(find.text('hinge left'), findsOneWidget);
    });

    testWidgets(
      'fold shader loads in the test renderer and enables the sampler',
      (WidgetTester tester) async {
        // The load is driven by pump(): FragmentProgram.fromAsset completes
        // on a microtask that pump flushes. Do not await FoldShader.load()
        // before the first pump — inside testWidgets that never resumes.
        await tester.pumpWidget(const FoldApp(initialTiltDegrees: 0));
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

## Math

Conventions, restated from `context.md` and unchanged:

- Logical px everywhere in the shader. x grows right, y grows down, z grows
  toward the viewer. Interface plane z = 0. E = (W/2, H/2, D).
- `D = uEyeDistPx = eyeDistanceMm · pxPerMm`, `pxPerMm = 160 / 25.4 =
  6.2992…`; default `320 mm → 2015.75 px`. Not `devicePixelRatio`.
- θ > 0 ⇒ the RIGHT edge is the hinge; `xh = θ > 0 ? W : 0`.
  `ManualTilt.degrees > 0 ⇒ θ > 0 ⇒ hinge right`.
- `uAngle = degrees · π / 180`, `degrees` clamped to ±`maxTiltDeg` (35).

Phase-001 shader (a strict subset of the reference; no reference math
changed):

```
p   = FlutterFragCoord().xy      // logical px, origin at FoldEffect top-left
uv  = p / uSize                  // ≡ reference at θ = 0: G = (px,py,0), t = 1, P = (px,py,0)
xh  = uAngle > 0 ? uSize.x : 0   // hinge x; marker drawn only when |θ| > 1e-4
out = uv ∈ [0,1]² ? texture(uTex, uv) : black(α = 1)
```

Why `FlutterFragCoord()` is logical px (to be confirmed by Acceptance 5a):
`runtime_effect.vert` sets `_fragCoord = position`, the untransformed local
vertex position. `AnimatedSampler` invokes the builder on a fresh
`PictureRecorder` canvas with identity transform and the picture is added to
the scene beneath the engine's DPR transform, so `drawRect(Offset.zero &
size)` spans `[0,W]×[0,H]` in logical px. The `ui.Image` handed to the
builder is `ceil(dpr·W) × ceil(dpr·H)` physical px, but `uv` is normalised
so the shader never sees `dpr`; `uSize` is the builder's logical `size`.

Failure signature if the assumption were wrong: at DPR 2 the shader would
map physical px through `uSize`, so `uv` would reach 1.0 at the window's
centre — the content would appear at 2× in the top-left quarter and the
rest would be black.

Proposed `context.md` hunk (file layout; main session routes it):

```
   motion/
+    tilt_source.dart         # TiltSource (ChangeNotifier): theta (rad, signed), isLive
     fold_motion_model.dart   # attitude → θ, calibration, prediction
     manual_tilt.dart         # slider-driven θ source (same interface)
```

## Commands

Run from the repo root, in this order. Bash tool timeouts: 120 s default is
fine except where noted.

```sh
# 0. Baseline commit so review can diff. Skip if `git log -1` already shows a commit.
git add -A && git commit -q -m "chore: flutter create scaffold baseline"

# 1. Add the macOS host. No --org: the tool infers com.debojyoti from ios/ and android/.
flutter create --platforms=macos .

# 2. Write every file in ## Files (pubspec.yaml hunks first, then the rest).

# 3. Resolve, format, analyze, test. `dart format` should report 0 changed.
flutter pub get
dart format lib test
flutter analyze
flutter test

# 4. Compile the shader through impellerc (Metal runtime stage). Timeout 600 s on first build.
flutter build macos --debug
ls build/macos/Build/Products/Debug/iphoneduo_animation_flutter.app/Contents/Frameworks/App.framework/Resources/flutter_assets/shaders/

# 5. Run once with a launch tilt. Start it in the background (Bash run_in_background:
#    true, timeout 300 s) with output to a scratch log; after ~90 s grep the log; then kill.
flutter run -d macos --dart-define=TILT_DEGREES=-20 > "$SCRATCH/duo_fold_run.log" 2>&1
grep -n "Flutter run key commands\|Error\|Exception\|impellerc" "$SCRATCH/duo_fold_run.log"
pkill -f "flutter run -d macos"; pkill -x iphoneduo_animation_flutter
```

`$SCRATCH` stands for the implementer's scratchpad directory — substitute
the real path. "Flutter run key commands." in the log means the app started
and drew; report that line and any `Error`/`Exception` lines verbatim.

## Acceptance

1. `flutter analyze` prints `No issues found!`.
2. `flutter test` prints `All tests passed!` — 7 tests (3 FoldParameters,
   2 ManualTilt, 2 FoldApp).
3. `flutter build macos --debug` ends with `✓ Built
   build/macos/Build/Products/Debug/iphoneduo_animation_flutter.app`, and
   the `ls` in Command 4 lists `duo_fold.frag` (the compiled runtime stage
   under `flutter_assets/shaders/`).
4. `git status` after the run shows only: new `shaders/`, `lib/fold/`,
   `lib/motion/`, `lib/demo/`, `macos/`, `docs/plans/001-scaffold.md`;
   modified `pubspec.yaml`, `pubspec.lock`, `.metadata`, `lib/main.dart`,
   `test/widget_test.dart`. Nothing under `android/` or `ios/`.
5. Visual, performed by the main session / human with
   `flutter run -d macos --dart-define=TILT_DEGREES=-20` (the implementer
   only reports whether the first frame rendered):
   a. The demo content fills the window edge to edge: the 2 px white frame
      is visible on all four sides, nothing is magnified or cropped, no
      black band. The panel's last line reads `dpr 2.00` (built-in Retina
      display; if it reads `1.00`, drag the window onto the built-in
      display and re-check). This is the `FlutterFragCoord()`-is-logical-px
      verification; record the finding in `## Review`.
   b. A 3 px yellow bar hugs the LEFT edge. Panel reads `θ -20.0°` and
      `hinge left`.
   c. Slider to +20: the bar moves to the RIGHT edge, `hinge right`. Slider
      to 0 or press Center: no bar, `hinge none`.
   d. No magenta anywhere (parameter sentinel never trips with defaults).
   e. Resize the window: content stays 1:1 and the frame stays at the
      window edges (`uSize` follows the sampler size).
   f. Console shows no exception, no `RangeError`, no `impellerc` output.
6. `## Implementation report` appended to this file per the implementer's
   format, including the `grep` output from Command 5.

## Out of scope

- Any reprojection, blur or dimming in the shader. The shader stays the
  pass-through above; 002 replaces it.
- Sensors: no `flutter_rotation_sensor`, no `sensors_plus`, no platform
  channels (004).
- Any edit under `android/`, `ios/`, or the generated `macos/` tree; any edit
  to `analysis_options.yaml`, `context.md`, `CLAUDE.md`, `.claude/`,
  `README.md`, or the root `fold-architect.md` / `fold-implementer.md`.
- Changing the uniform order, count, names or the shader header comment;
  adding `layout(location = …)`; using `ShaderBuilder`, `SetUniforms`,
  `getUniformFloat` / `getImageSampler`.
- `flutter pub upgrade`, `flutter pub add`, `flutter create --overwrite`,
  passing `--org`.
- Committing after the baseline commit, or pushing. The main session decides.
- Running on the iPhone. Optional for the human later; not required for
  acceptance.
- The "fluitter" typo in the pubspec description.

## Implementation report

STATUS: DONE

Files written:
- `shaders/duo_fold.frag`
- `lib/fold/fold_parameters.dart`
- `lib/fold/fold_shader.dart`
- `lib/fold/fold_effect.dart`
- `lib/motion/tilt_source.dart`
- `lib/motion/manual_tilt.dart`
- `lib/demo/demo_content.dart`
- `lib/demo/control_panel.dart`

Files edited:
- `pubspec.yaml` — hunk 1 added `flutter_shaders: 0.1.3` under `dependencies`;
  hunk 2 added the `shaders: - shaders/duo_fold.frag` entry under `flutter:`.
  Both applied verbatim.
- `lib/main.dart` — full replacement: `FoldApp`/`FoldScreen` composing
  `DemoContent` under `FoldEffect` (driven by `ManualTilt`), with
  `ControlPanel` floating outside the effect, and the `TILT_DEGREES`
  dart-define plumbed to the initial slider value.
- `test/widget_test.dart` — full replacement: 7 tests (3 `FoldParameters`, 2
  `ManualTilt`, 2 `FoldApp`).
- `.metadata` — rewritten by `flutter create --platforms=macos .` (see
  Deviations #1).

Deviations from plan:
1. `flutter create --platforms=macos .` replaced the existing `android` and
   `ios` platform entries in `.metadata`'s migration list with a single
   `macos` entry, rather than only adding `macos` alongside them as Decision
   1 / the `macos/` Files note implied. Verified with `git status`/`git diff`
   that the `android/` and `ios/` directories themselves were untouched —
   only `.metadata`'s bookkeeping list changed. Accepted per the plan's own
   instruction to "accept that change."
2. `docs/plans/001-scaffold.md` was already present in the working tree
   before Command 0 ran (supplied with `context.md` and the agent defs), so
   the baseline commit already includes it and it does not show as a new
   file in the post-run `git status` that Acceptance 4 describes. Its
   content is otherwise exactly as intended by the plan (this report is the
   only addition). No other part of Acceptance 4 differs: `git status
   --porcelain` after the run shows exactly `M .metadata`, `M lib/main.dart`,
   `M pubspec.lock`, `M pubspec.yaml`, `M test/widget_test.dart`, and
   untracked `lib/demo/`, `lib/fold/`, `lib/motion/`, `macos/`, `shaders/`.
   Nothing under `android/` or `ios/`.

Self-fixes applied: none. No analyzer issues, no compile errors, no
dependency-resolution problems — every step matched the plan's dry-run
prediction on the first try.

Command results:
```
flutter pub get        — Got dependencies! (flutter_shaders 0.1.3 resolved as pinned)
dart format lib test   — Formatted 9 files (0 changed)
flutter analyze        — No issues found!
flutter test           — All tests passed! (7/7: 3 FoldParameters, 2 ManualTilt, 2 FoldApp)
flutter build macos --debug
                        — ok: "✓ Built build/macos/Build/Products/Debug/iphoneduo_animation_flutter.app"
                          (one unrelated Xcode warning: "Run script build phase
                          'Run Script' will be run during every build ..." —
                          pre-existing Runner target script-phase config, not
                          shader-related)
ls .../flutter_assets/shaders/
                        — duo_fold.frag  ink_sparkle.frag  stretch_effect.frag
flutter run -d macos --dart-define=TILT_DEGREES=-20
                        — started and drew a first frame (DevTools URI printed,
                          "Flutter run key commands." reached), then killed via
                          pkill per instructions. grep output:
                            8:Flutter run key commands.
                          No Error/Exception/impellerc lines matched. The log
                          also contains a benign "Failed to foreground app;
                          open returned 1" line — this sandbox has no active
                          GUI session for `open` to bring a window forward;
                          unrelated to the build or shader compile, and the
                          engine/process came up normally regardless.
```

Open questions for architect:
1. Should `.metadata` keep only the `macos` migration entry (current state,
   from stock `flutter create --platforms=macos .` behaviour), or should the
   `android`/`ios` entries be restored alongside it? Either way the
   `android/` and `ios/` source trees themselves are untouched.
2. Visual Acceptance 5a–5f needs an actual on-screen window; this execution
   environment is headless (no window server for `open` to foreground the
   app), so those checks were not performed here and are left for the main
   session / human with `flutter run -d macos --dart-define=TILT_DEGREES=-20`,
   as the plan already anticipates in Acceptance 5's own wording.

## Review

STATUS: ACCEPTED

Provisional on one item: Acceptance 5a (visual confirmation that
`FlutterFragCoord()` is logical px under Impeller) has not been observed by a
human. Grounds for accepting without it, and the exact check carried into
002, are in item 4 below.

### 1. Diff against baseline `d3afb3d`, checked against the plan

Method: re-extracted every code block from `## Files` and `diff`ed it
against the working tree; `git diff HEAD` for tracked files; `git ls-files
--others --exclude-standard` for new ones.

| Path | Result |
|---|---|
| `shaders/duo_fold.frag` | byte-identical to plan |
| `lib/fold/fold_parameters.dart` | byte-identical |
| `lib/fold/fold_shader.dart` | byte-identical |
| `lib/fold/fold_effect.dart` | byte-identical |
| `lib/motion/tilt_source.dart` | byte-identical |
| `lib/motion/manual_tilt.dart` | byte-identical |
| `lib/demo/demo_content.dart` | byte-identical |
| `lib/demo/control_panel.dart` | byte-identical |
| `lib/main.dart` | byte-identical (full replacement) |
| `test/widget_test.dart` | byte-identical (full replacement) |
| `pubspec.yaml` | both hunks verbatim, nothing else changed |
| `pubspec.lock` | adds `flutter_shaders 0.1.3` (sha256 `34794aca…`), nothing else |
| `macos/` (28 committable files) | stock template. Compared against an independently generated `flutter create --platforms=macos` tree: only `PRODUCT_BUNDLE_IDENTIFIER`/`PRODUCT_COPYRIGHT` org lines differ (`com.debojyoti` here, as intended). `Flutter/ephemeral/` (absolute paths, baked `DART_DEFINES`) is excluded by `macos/.gitignore`. No `FLTEnableImpeller` key in `macos/Runner/Info.plist`, so Impeller stays on. |
| `.metadata` | see deviation 1 |
| `docs/plans/001-scaffold.md` | append-only: 88 added lines, 0 removed (`git diff` shows a single hunk at the end) |
| stray files under `lib/`, `shaders/`, `test/` | none |
| `android/`, `ios/` | untouched |

Reported deviations:

1. `.metadata` `migration.platforms` now lists `root` + `macos` instead of
   `root` + `android` + `ios`. **Accepted.** In this SDK the list is written
   by `create_base.dart` (from the `--platforms` requested) and read by
   nothing — there is no `migrate` command in `flutter_tools/lib/src/commands/`
   and no other consumer of `MigrateConfig`. It affects no build, run or
   test path. Answer to open question 1: leave it as is. (If anyone wants the
   entries back, `flutter create --platforms=android,ios,macos .` regenerates
   the list; not worth a cycle.)
2. The plan file was already in the baseline commit, so Acceptance 4's
   "new `docs/plans/001-scaffold.md`" reads as "modified". **Accepted** — my
   wording, the tree state is exactly right.

Self-fixes: none reported, none found.

### 2. Independent verification (not taken from the report)

- `flutter analyze` in the repo: `No issues found!`
- `flutter test --timeout 60s` in the repo: 7/7 passed, including the
  sampler-enabled test on the tester renderer.
- `build/macos/…/flutter_assets/shaders/duo_fold.frag` present, 4568 bytes —
  the same size as the Metal runtime stage `impellerc --sksl
  --runtime-stage-metal` produced from the plan's GLSL during the dry-run.
- Shader vs `context.md`, re-derived rather than trusting the plan:
  - Uniform order `uSize(0,1) uAngle(2) uEyeDistPx(3) uMaxBlurPx(4)
    uDimStrength(5)`, `uTex` sampler 0 — matches the fixed table.
  - `fold_effect.dart` `setFloat` indices 0–5 and `setImageSampler(0, …)`
    match that table one for one; `uEyeDistPx = eyeDistanceMm · 160/25.4`
    with no `devicePixelRatio` — matches the conversion rule.
  - Sign path: `ManualTilt.degrees > 0 → theta > 0 → xh = uSize.x` (right
    edge) — matches "θ > 0 means the right edge is the hinge".
  - `uv = p / uSize`, black with α = 1 outside `[0,1]²`, no sampler
    clamping relied on — matches the reference; with θ = 0 the reference
    gives `G = (px, py, 0)`, `t = 1`, `P = G`, i.e. exactly this
    pass-through.
  - Impeller dialect: `#include <flutter/runtime_effect.glsl>`,
    `FlutterFragCoord()`, two-argument `texture()`, no `gl_FragCoord`, no
    loops, no dynamic indexing.
  - No blur, no dim, no reprojection — phase boundary respected.

### 3. Runtime observation

The implementer's `flutter run -d macos --dart-define=TILT_DEGREES=-20`
reached "Flutter run key commands." with no `Error`/`Exception`/`impellerc`
lines: the Metal runtime stage loaded and the first frame was drawn. The
"Failed to foreground app; open returned 1" line is the sandbox lacking a
window server for `open`; the engine process itself came up.

### 4. Acceptance 5a — provisional, carried into 002

Accepted provisionally on source evidence: `runtime_effect.vert` sets
`_fragCoord = position` (the untransformed local vertex position);
`AnimatedSampler` calls the builder on a fresh `PictureRecorder` canvas with
identity transform and adds the picture beneath the engine's DPR transform;
so `drawRect(Offset.zero & size)` spans `[0, W] × [0, H]` logical px by
construction. The tester run exercises the same shader/uniform contract on
Skia (where `gl_FragCoord` is rewritten to local coordinates). What is
missing is only eyes on an Impeller frame.

Carry this into the 002 acceptance list as item 0, exactly:

> **0. (from 001) `FlutterFragCoord()` is logical px on Impeller.** On the
> built-in Retina display run
> `flutter run -d macos --dart-define=TILT_DEGREES=0`, confirm the panel's
> last line reads `dpr 2.00`, and take a window screenshot (`screencapture
> -l <windowid> shot.png`, or the main session's screenshot tooling).
> PASS: the 2 px white frame is on all four window edges and there is no
> black region; pixel probe: `(width − 1, height / 2)` and
> `(width / 2, height − 1)` are white. FAIL: the interface occupies only the
> top-left quarter at 2× with black elsewhere. Then
> `--dart-define=TILT_DEGREES=-20`: a 3 px yellow bar on the LEFT edge;
> `+20` via the slider: on the RIGHT edge. Record the result in 002's
> `## Review`; if FAIL, 002's reprojection must not be judged until the
> coordinate space is fixed (multiply `p` by `1/dpr` on the Dart side is
> NOT the fix — the shader must receive logical px; report to the
> architect).

### 5. Proposed `context.md` hunks (main session routes to the implementer)

Hunk A — file layout:

```
   motion/
+    tilt_source.dart         # TiltSource (ChangeNotifier): theta (rad, signed), isLive
     fold_motion_model.dart   # attitude → θ, calibration, prediction
     manual_tilt.dart         # slider-driven θ source (same interface)
```

Hunk B — coordinate conventions, first bullet:

```
-- Work in **logical pixels** in the shader. `uSize` is the logical size of
-  the sampled child. `FlutterFragCoord()` is in logical px on Impeller when
-  the sampler's canvas is the widget's canvas; verify once in phase 001 and
-  record the finding in the plan review.
+- Work in **logical pixels** in the shader. `uSize` is the logical size of
+  the sampled child (the `size` argument of the `AnimatedSampler` builder).
+  `FlutterFragCoord()` is the local position of the `drawRect` that used the
+  shader (`runtime_effect.vert`: `_fragCoord = position`), i.e. logical px
+  from the widget's top-left. Established from source and by the 001
+  build/test; on-screen Impeller confirmation is 002 acceptance item 0.
```

Hunk C — package targets:

```
-flutter_shaders: ^0.1.x      # AnimatedSampler, SetFloats helpers
+flutter_shaders: 0.1.3       # AnimatedSampler only; pinned in 001 (latest on pub.dev)
```

Hunk D — gotchas, append:

```
+- `AnimatedSampler` compares its builder with `==`; pass a fresh closure
+  every build (a method tear-off compares equal and freezes the effect).
+- Never cache the shader-loading `Future` in a static: it is bound to the
+  zone that created it, and under `flutter test` that is one test's
+  FakeAsync zone — later tests wait forever. Cache the loaded instance.
+- Inside `testWidgets`, never `await` the shader loader before the first
+  `pump()`; the load completes on a microtask that only `pump` flushes.
+- Flutter 3.47: the `IMPELLER_TARGET_OPENGLES` uv flip is no longer needed.
+- `double.fromEnvironment` does not exist; read `--dart-define` values with
+  `String.fromEnvironment` + `double.tryParse`.
+- `flutter create --platforms=<x> .` rewrites `.metadata`'s
+  `migration.platforms` to only the platforms named. Harmless (nothing
+  reads it in 3.47), but expect the diff.
+- macOS desktop (Impeller/Metal by default since 3.47) is the device-free
+  validation target; its build compiles the same `--runtime-stage-metal`
+  stage as iOS.
```

### 6. Notes for the 002 plan

- The hinge marker and parameter sentinel in `duo_fold.frag` are 001-only
  debug aids; 002 decides whether the marker survives (it is useful for
  judging hinge side by eye) and keeps the sentinel.
- `setImageSampler(…, filterQuality: FilterQuality.none)` already gives 002
  its nearest sampling.
- `FoldParameters.blurTaps` doc says "a compile-time constant in
  `duo_fold.frag`"; the constant does not exist until 003. Fix the comment
  in 003, not now.
