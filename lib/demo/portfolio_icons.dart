import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'svg_path.dart';

/// The dock's glyphs, quoted from the site's rendered markup: the
/// `fill="currentColor"` path of each `<svg viewBox="0 0 24 24">`. The
/// sibling `fill="none"` bounding-box path in each icon carries no ink and
/// is dropped.

/// `<title>document</title>` — the résumé link.
const String kIconDocument =
    'M13.586 2A2 2 0 0 1 15 2.586L19.414 7A2 2 0 0 1 20 8.414V20a2 2 0 0 1-2 '
    '2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2ZM12 4H6v16h12V10h-4.5A1.5 1.5 0 0 1 12 '
    '8.5zm3 10a1 1 0 1 1 0 2H9a1 1 0 1 1 0-2zm-5-4a1 1 0 1 1 0 2H9a1 1 0 1 1 '
    '0-2Zm4-5.586V8h3.586z';

/// `<title>github_line</title>`.
const String kIconGithub =
    'M6.315 6.176c-.25-.638-.24-1.367-.129-2.034a6.77 6.77 0 0 1 2.12 '
    '1.07c.28.214.647.283.989.18A9.343 9.343 0 0 1 12 5c.961 0 1.874.14 '
    '2.703.391.342.104.709.034.988-.18a6.77 6.77 0 0 1 2.119-1.07c.111.667.12 '
    '1.396-.128 2.033-.15.384-.075.826.208 1.14C18.614 8.117 19 9.04 19 10c0 '
    '2.114-1.97 4.187-5.134 4.818-.792.158-1.101 1.155-.495 1.726.389.366.629'
    '.882.629 1.456v3a1 1 0 0 0 2 0v-3c0-.57-.12-1.112-.334-1.603C18.683 15.35 '
    '21 12.993 21 10c0-1.347-.484-2.585-1.287-3.622.21-.82.191-1.646.111-2.28'
    '-.071-.568-.17-1.312-.57-1.756-.595-.659-1.58-.271-2.28-.032a9.081 9.081 '
    '0 0 0-2.125 1.045A11.432 11.432 0 0 0 12 3c-.994 0-1.953.125-2.851.356a'
    '9.08 9.08 0 0 0-2.125-1.045c-.7-.24-1.686-.628-2.281.031-.408.452-.493 '
    '1.137-.566 1.719l-.005.038c-.08.635-.098 1.462.112 2.283C3.484 7.418 3 '
    '8.654 3 10c0 2.992 2.317 5.35 5.334 6.397A3.986 3.986 0 0 0 8 17.98l-.168'
    '.034c-.717.099-1.176.01-1.488-.122-.76-.322-1.152-1.133-1.63-1.753-.298'
    '-.385-.732-.866-1.398-1.088a1 1 0 0 0-.632 1.898c.558.186.944 1.142 1.298 '
    '1.566.373.448.869.916 1.58 1.218.682.29 1.483.393 2.438.276V21a1 1 0 0 0 '
    '2 0v-3c0-.574.24-1.09.629-1.456.607-.572.297-1.568-.495-1.726C6.969 '
    '14.187 5 12.114 5 10c0-.958.385-1.881 1.108-2.684.283-.314.357-.756.207'
    '-1.14';

/// `<title>linkedin_line</title>`.
const String kIconLinkedIn =
    'M18 3a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3zm0 '
    '2H6a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V6a1 1 0 0 0-1-1M8 10a'
    '1 1 0 0 1 .993.883L9 11v5a1 1 0 0 1-1.993.117L7 16v-5a1 1 0 0 1 1-1m3-1a1 '
    '1 0 0 1 .984.821 5.82 5.82 0 0 1 .623-.313c.667-.285 1.666-.442 2.568-.159'
    '.473.15.948.43 1.3.907.315.425.485.942.519 1.523L17 12v4a1 1 0 0 1-1.993'
    '.117L15 16v-4c0-.33-.08-.484-.132-.555a.548.548 0 0 0-.293-.188c-.348-.11'
    '-.849-.052-1.182.09-.5.214-.958.55-1.27.861L12 12.34V16a1 1 0 0 1-1.993'
    '.117L10 16v-6a1 1 0 0 1 1-1M8 7a1 1 0 1 1 0 2 1 1 0 0 1 0-2';

/// `<title>social_x_line</title>`.
const String kIconX =
    'M19.753 4.659a1 1 0 0 0-1.506-1.317l-5.11 5.84L8.8 3.4A1 1 0 0 0 8 3H4a1 '
    '1 0 0 0-.8 1.6l6.437 8.582-5.39 6.16a1 1 0 0 0 1.506 1.317l5.11-5.841L15.2 '
    '20.6a1 1 0 0 0 .8.4h4a1 1 0 0 0 .8-1.6l-6.437-8.582 5.39-6.16ZM16.5 19 6 '
    '5h1.5L18 19z';

/// `<title>telegram_line</title>`.
const String kIconTelegram =
    'M21.84 6.056a1.5 1.5 0 0 0-2.063-1.626l-17.1 7.2c-1.192.502-1.253 2.226 0 '
    '2.746a56.46 56.46 0 0 0 3.774 1.418c1.168.386 2.442.743 3.463.844.279.334'
    '.63.656.988.95.547.45 1.205.913 1.885 1.357 1.362.89 2.873 1.741 3.891 '
    '2.295 1.217.66 2.674-.1 2.892-1.427zM4.594 12.993l15.124-6.368-2.118 '
    '12.84c-.999-.543-2.438-1.356-3.72-2.194a19.982 19.982 0 0 1-1.709-1.229 '
    '7.962 7.962 0 0 1-.426-.374l3.961-3.96a1 1 0 0 0-1.414-1.415L9.955 '
    '14.63c-.734-.094-1.756-.366-2.878-.736a48.89 48.89 0 0 1-2.482-.902Z';

/// `<title>sun_line</title>` — the theme toggle, which shows the sun in the
/// light theme this port is pinned to.
const String kIconSun =
    'M12 19a1 1 0 0 1 1 1v1a1 1 0 1 1-2 0v-1a1 1 0 0 1 1-1m6.364-2.05.707'
    '.707a1 1 0 0 1-1.414 1.414l-.707-.707a1 1 0 0 1 1.414-1.414m-12.728 0a1 1 '
    '0 0 1 1.497 1.32l-.083.094-.707.707a1 1 0 0 1-1.497-1.32l.083-.094zM12 6a6 '
    '6 0 1 1 0 12 6 6 0 0 1 0-12m0 2a4 4 0 1 0 0 8 4 4 0 0 0 0-8m-8 3a1 1 0 0 1 '
    '.117 1.993L4 13H3a1 1 0 0 1-.117-1.993L3 11zm17 0a1 1 0 1 1 0 2h-1a1 1 0 1 '
    '1 0-2zM4.929 4.929a1 1 0 0 1 1.32-.083l.094.083.707.707a1 1 0 0 1-1.32 '
    '1.497l-.094-.083-.707-.707a1 1 0 0 1 0-1.414m14.142 0a1 1 0 0 1 0 1.414l'
    '-.707.707a1 1 0 1 1-1.414-1.414l.707-.707a1 1 0 0 1 1.414 0M12 2a1 1 0 0 1 '
    '1 1v1a1 1 0 1 1-2 0V3a1 1 0 0 1 1-1';

/// Parsed paths, keyed by their data. Parsing is a few hundred `double
/// .parse` calls; the dock repaints on every sampler frame, so it happens
/// once per glyph for the life of the process.
final Map<String, ui.Path> _cache = <String, ui.Path>{};

ui.Path _pathFor(String d) => _cache.putIfAbsent(d, () => parseSvgPath(d));

/// A filled glyph from 24×24 SVG path data, drawn at [size] in [color].
class SvgIcon extends StatelessWidget {
  const SvgIcon(
    this.data, {
    super.key,
    required this.size,
    required this.color,
  });

  final String data;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SvgIconPainter(_pathFor(data), color, size)),
    );
  }
}

class _SvgIconPainter extends CustomPainter {
  _SvgIconPainter(this.path, this.color, this.extent);

  final ui.Path path;
  final Color color;
  final double extent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(extent / 24);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SvgIconPainter old) =>
      old.path != path || old.color != color || old.extent != extent;
}
