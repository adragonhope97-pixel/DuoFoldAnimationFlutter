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
