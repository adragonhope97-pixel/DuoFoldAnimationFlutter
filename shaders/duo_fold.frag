#version 320 es
// duo_fold.frag — phase 005: perspective reprojection (002) + variable-radius
// Vogel-disk blur and dimming. A transcription of duoFold in DuoFold.metal
// (elijah-semyonov/DuoLikeAnimation); every constant here is that file's.
//
// Model (context.md): the interface lies on z = 0; the eye E sits on the plane
// normal through the screen centre at uEyeDistPx; the glass rotates by |θ|
// around the hinge edge (right edge when θ > 0, left when θ < 0), rising toward
// the eye. Each pixel is placed on the rotated glass, a ray from E through it
// is continued to z = 0, and the interface is sampled around the hit point with
// a disk whose radius grows with the glass-to-plane gap. Frosted glass also
// absorbs, so the same radius dims the result.

precision highp float;

#include <flutter/runtime_effect.glsl>

// Uniform layout is fixed by context.md. Float slots (Dart setFloat index):
//   uSize.x       0
//   uSize.y       1
//   uAngle        2
//   uEyeDistPx    3
//   uBlurSpread   4
//   uDarkening    5
// Sampler slots (Dart setImageSampler index):
//   uTex          0
uniform vec2 uSize;         // logical px size of the sampled child
uniform float uAngle;       // tilt θ, radians; θ > 0 → hinge on the RIGHT edge
uniform float uEyeDistPx;   // eye distance D, logical px
uniform float uBlurSpread;  // blur radius per logical px of gap (0.12)
uniform float uDarkening;   // light lost per logical px of blur radius (0.015)
uniform sampler2D uTex;     // the rasterised child

out vec4 fragColor;

const int kBlurTaps = 32;                          // Metal kBlurTaps
const float kGoldenAngle = 2.39996322972865332;    // Vogel disk spacing, radians
const float kTwoPi = 6.28318530717958648;
const vec4 kBlack = vec4(0.0, 0.0, 0.0, 1.0);

// Metal's hash21: a per-pixel value in [0,1) used to rotate the disk so the
// Vogel banding becomes frosted-glass grain.
float hash21(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Interface colour at logical position q; black outside the interface, as
// SwiftUI's layer.sample is transparent outside the layer (maxSampleOffset is
// .zero in FoldEffect.swift). Branchless: the fetch is unconditional and the
// result is selected, so no tap relies on sampler clamping, which would smear
// the border.
vec3 sampleRgb(vec2 q) {
  vec3 rgb = texture(uTex, q / uSize).rgb;
  bool inside = all(greaterThanEqual(q, vec2(0.0))) &&
                all(lessThanEqual(q, uSize));
  return inside ? rgb : vec3(0.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;   // logical px, origin top-left
  float tilt = abs(uAngle);

  vec4 color;
  if (tilt < 1e-5) {
    color = vec4(sampleRgb(p), 1.0);           // untilted glass: identity
  } else {
    float xh = uAngle > 0.0 ? uSize.x : 0.0;   // hinge x
    float u = p.x - xh;                        // signed distance from hinge
    // Pixel on the rotated glass: foreshortened toward the hinge, lifted by
    // |u|·sin(tilt) toward the eye.
    vec3 G = vec3(xh + u * cos(tilt), p.y, abs(u) * sin(tilt));
    vec3 E = vec3(uSize * 0.5, uEyeDistPx);
    float depth = E.z - G.z;
    if (depth <= 1e-3) {
      color = kBlack;                          // glass at/behind the eye
    } else {
      float t = E.z / depth;                   // ray E→G continued to z = 0
      vec2 hit = E.xy + (G.xy - E.xy) * t;     // hit point on the interface
      float gap = G.z;                         // glass-to-plane separation
      float radius = uBlurSpread * gap;        // blur radius, logical px
      if (any(lessThan(hit, vec2(-radius))) ||
          any(greaterThan(hit, uSize + vec2(radius)))) {
        color = kBlack;                        // the whole kernel misses the UI
      } else {
        float attenuation = max(1.0 - uDarkening * radius, 0.0);
        if (radius < 0.5) {
          color = vec4(sampleRgb(hit) * attenuation, 1.0);   // one tap
        } else {
          // Vogel disk, area-uniform in i, rotated per pixel. Small kernels
          // need few taps; the loop bound is the constant kBlurTaps and the
          // live count is honoured by the break.
          float tapsF = clamp(floor(radius * 2.0), 6.0, float(kBlurTaps));
          int taps = int(tapsF);
          float rotation = hash21(p) * kTwoPi;
          vec3 sum = vec3(0.0);
          for (int i = 0; i < kBlurTaps; ++i) {
            if (i >= taps) {
              break;
            }
            float ri = radius * sqrt((float(i) + 0.5) / tapsF);
            float ai = float(i) * kGoldenAngle + rotation;
            sum += sampleRgb(hit + ri * vec2(cos(ai), sin(ai)));
          }
          color = vec4(sum / tapsF * attenuation, 1.0);
        }
      }
    }
  }

  // Parameter sentinel: makes a mis-wired uniform slot visible instead of
  // subtle. darkening is a per-px coefficient, not a 0..1 knob.
  if (uEyeDistPx <= 0.0 || uBlurSpread < 0.0 || uDarkening < 0.0) {
    color = vec4(1.0, 0.0, 1.0, 1.0);          // magenta = invalid FoldParameters
  }

  fragColor = color;
}
