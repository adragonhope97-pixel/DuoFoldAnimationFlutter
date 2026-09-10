#version 320 es
// duo_fold.frag — phase 002: perspective reprojection, nearest sampling,
// black outside the interface. No blur, no dimming (003).
//
// Model (context.md, verified against DuoFold.metal in 002): the interface
// lies on z = 0; the eye E sits on the plane normal through the screen centre
// at uEyeDistPx; the glass rotates by |θ| around the hinge edge (right edge
// when θ > 0, left when θ < 0), rising toward the eye. Each pixel is placed
// on the rotated glass, a ray from E through it is continued to z = 0, and
// the interface is sampled at the hit point.

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
uniform float uEyeDistPx;    // eye distance D, logical px
uniform float uMaxBlurPx;    // used from 003
uniform float uDimStrength;  // 0..1, used from 003
uniform sampler2D uTex;      // the rasterised child

out vec4 fragColor;

const vec4 kBlack = vec4(0.0, 0.0, 0.0, 1.0);

// Interface colour at logical position q, opaque (alpha dropped: the
// sampled layer is composited over black, as in the Metal original).
vec4 sampleInterface(vec2 q) {
  return vec4(texture(uTex, q / uSize).rgb, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;   // logical px, origin top-left
  float tilt = abs(uAngle);

  vec4 color;
  if (tilt < 1e-5) {
    color = sampleInterface(p);     // untilted glass: identity
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
      if (any(lessThan(hit, vec2(0.0))) || any(greaterThan(hit, uSize))) {
        color = kBlack;                        // ray misses the interface
      } else {
        color = sampleInterface(hit);          // nearest sampling (Dart side)
      }
    }
  }

  // Parameter sentinel: keeps every uniform live and makes bad values visible.
  if (uEyeDistPx <= 0.0 || uMaxBlurPx < 0.0 ||
      uDimStrength < 0.0 || uDimStrength > 1.0) {
    color = vec4(1.0, 0.0, 1.0, 1.0);          // magenta = invalid FoldParameters
  }

  fragColor = color;
}
