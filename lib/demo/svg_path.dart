import 'dart:ui' show Offset, Path, Radius;

/// A minimal SVG path-data parser, enough for the seven glyphs in
/// `portfolio_icons.dart`.
///
/// Supported commands: `M m L l H h V v C c A a Z z`. That is exactly the
/// set those paths use — no quadratics, no smooth curves — so anything else
/// throws rather than silently drawing the wrong shape. Arcs go straight to
/// [Path.arcToPoint], which takes SVG endpoint-arc parameters as they are:
/// `rotation` is in degrees, and `clockwise` is the sweep flag.
///
/// Fill rule: the caller gets the default [PathFillType.nonZero], which is
/// SVG's default `fill-rule` too, so the counters in the document and
/// telegram glyphs come out right.
final RegExp _token = RegExp(
  r'[MmLlHhVvCcAaZz]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',
);

final RegExp _letter = RegExp(r'^[A-Za-z]$');

/// Parses [d] into a [Path] in the source viewBox's coordinates.
Path parseSvgPath(String d) {
  final List<String> tokens = _token
      .allMatches(d)
      .map((RegExpMatch m) => m.group(0)!)
      .toList(growable: false);
  final Path path = Path();
  double cx = 0;
  double cy = 0;
  double sx = 0;
  double sy = 0;
  String command = '';
  int i = 0;

  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (_letter.hasMatch(tokens[i])) {
      command = tokens[i++];
    } else if (command == 'M') {
      command = 'L';
    } else if (command == 'm') {
      command = 'l';
    } else if (command.isEmpty) {
      throw FormatException('svg path starts with a number', d);
    }

    switch (command) {
      case 'Z':
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
      case 'M':
        cx = next();
        cy = next();
        sx = cx;
        sy = cy;
        path.moveTo(cx, cy);
      case 'm':
        cx += next();
        cy += next();
        sx = cx;
        sy = cy;
        path.moveTo(cx, cy);
      case 'L':
        cx = next();
        cy = next();
        path.lineTo(cx, cy);
      case 'l':
        cx += next();
        cy += next();
        path.lineTo(cx, cy);
      case 'H':
        cx = next();
        path.lineTo(cx, cy);
      case 'h':
        cx += next();
        path.lineTo(cx, cy);
      case 'V':
        cy = next();
        path.lineTo(cx, cy);
      case 'v':
        cy += next();
        path.lineTo(cx, cy);
      case 'C':
        final double x1 = next();
        final double y1 = next();
        final double x2 = next();
        final double y2 = next();
        cx = next();
        cy = next();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
      case 'c':
        final double x1 = cx + next();
        final double y1 = cy + next();
        final double x2 = cx + next();
        final double y2 = cy + next();
        cx += next();
        cy += next();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
      case 'A':
      case 'a':
        final double rx = next();
        final double ry = next();
        final double rotation = next();
        final bool largeArc = next() != 0;
        final bool clockwise = next() != 0;
        final double dx = next();
        final double dy = next();
        if (command == 'A') {
          cx = dx;
          cy = dy;
        } else {
          cx += dx;
          cy += dy;
        }
        path.arcToPoint(
          Offset(cx, cy),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: clockwise,
        );
      default:
        throw FormatException('unsupported svg command "$command"', d);
    }
  }
  return path;
}
