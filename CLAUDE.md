# duo_fold — Flutter port of DuoLikeAnimation

Port of https://github.com/elijah-semyonov/DuoLikeAnimation (SwiftUI + Metal
`layerEffect` + Core Motion) to Flutter (fragment shader + `flutter_shaders`
`AnimatedSampler` + device rotation sensor). Read `context.md` before doing
anything — it holds the physical model, the uniform layout, the file layout,
and the known gotchas. It is the single source of truth for both agents.

## Two-agent rule (non-negotiable)

This project is worked by two subagents with different models. The main
session is an orchestrator only: it routes, it does not think or type.

| Work | Agent | Model |
|---|---|---|
| Math, shader design, sensor-fusion decisions, architecture, debugging a *visually wrong* result, reviewing a diff | `fold-architect` | fable |
| Writing/editing files, running `flutter` commands, wiring packages, fixing compile/analyzer errors that the plan already covers | `fold-implementer` | sonnet |

Rules for the main session:

1. Never write Dart or GLSL yourself. Never derive geometry yourself.
2. Every unit of work goes architect → implementer → architect (review).
   Do not skip the review step.
3. Pass work between agents **through files**, not through your own
   summary. Subagents do not see this conversation. The architect writes
   `docs/plans/NNN-<slug>.md`; the implementer reads it, executes it, and
   appends an `## Implementation report` section to the same file; the
   architect reads the report + `git diff` and appends `## Review`.
4. If the implementer's report says `STATUS: BLOCKED`, send the plan back
   to the architect with the report — do not try to unblock it yourself.
5. When invoking either agent, tell it the plan path and nothing else it
   needs to re-derive. Keep delegation prompts short; the plan file is
   the contract.

## Phases

Work is done in this order. Each phase is one plan file. Do not start a
phase until the previous one has a `## Review` with `STATUS: ACCEPTED`.

1. `001-scaffold` — Flutter project, packages, shader registered in
   pubspec, `AnimatedSampler` wrapper widget that passes through unchanged
   (identity shader). Runs on a device or the macOS desktop target.
2. `002-reprojection` — perspective reprojection in the shader driven by
   a manual tilt slider. No blur, no dim. Black outside the interface.
3. `003-blur-dim` — variable-radius disk blur and dimming proportional to
   glass–plane gap. Tap-count budget respected.
4. `004-motion` — device attitude → tilt angle. Calibrate zero pose on
   first sample, recalibrate button, gyro prediction, hinge side resolved
   against gravity at runtime.
5. `005-polish` — floating control panel (recalibrate / manual mode /
   slider), tunables surface, demo content screen.

## Conventions

- `flutter analyze` must be clean before a report is written.
- Shader lives at `shaders/duo_fold.frag` and is declared under
  `flutter: shaders:` in `pubspec.yaml`. Nothing else goes in `shaders/`.
- Uniform order is fixed in `context.md`. Changing it requires a plan
  revision from the architect, not an ad-hoc edit.
- Nothing under the sampler may be a platform view (WebView, native map).
- No `localStorage`-style hacks, no `dart:io` in shader code paths, no
  Skia-only APIs — Impeller is the target renderer.
- Commit after each accepted phase: `git commit -am "phase NNN: <slug>"`.
