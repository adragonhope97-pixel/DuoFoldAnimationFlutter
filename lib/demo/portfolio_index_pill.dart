import 'package:flutter/widgets.dart';

import 'portfolio_tokens.dart';

/// The site's floating "Index" control, rendered in its settled, collapsed
/// state only.
///
/// This screen is wallpaper for the fold shader to sample; it does not need
/// to work, it needs to look right. The scroll-progress binding, the
/// expanding section-jump menu and the chevron rotation are dropped — only
/// the static geometry and colours the plan specifies remain: a 190×40
/// black capsule holding a 0 %-progress ring, the "Index" label, a
/// down-pointing chevron and a "0%" badge.
///
/// Geometry and colours, quoted from the bundle (see the plan's `## Math`
/// for the derivations):
///
/// * pill `collapsed {width:190, height:40, borderRadius:24}`;
/// * ring: `w-6 h-6` svg, `-rotate-90`, `cx=12 cy=12 r=10 strokeWidth=4`,
///   track `opacity-30`;
/// * header `w-full px-1.5 h-10 flex items-center justify-between`, left
///   group `flex items-center gap-2`, chevron `w-4 h-4`;
/// * badge `px-4 py-1 rounded-full text-sm font-medium bg-zinc-600`.
class IndexPill extends StatelessWidget {
  const IndexPill({super.key});

  static const double width = 190;
  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kBlack,
        borderRadius: BorderRadius.circular(24),
        boxShadow: kShadowLg,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(painter: _RingPainter()),
                ),
                SizedBox(width: 8),
                Text('Index', style: kPillLabel),
                SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CustomPaint(painter: _ChevronPainter()),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: const BoxDecoration(
                color: kZinc600,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: const Text('0%', style: kPillBadge),
            ),
          ],
        ),
      ),
    );
  }
}

/// The track circle of `<svg class="-rotate-90">`: `cx=12 cy=12 r=10
/// strokeWidth=4` at `opacity-30`.
///
/// The white progress arc is not drawn and this painter takes no progress.
/// The screen is static at 0 %, and a painter that stored a value it can
/// never vary reads as live wiring that is not there. Restoring the arc
/// means restoring the scroll binding that fed it — see `## Review`,
/// judgement call 2.
class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      const Offset(12, 12),
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x4DFFFFFF), // white at opacity-30
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}

/// lucide `ChevronDown`, `d="m6 9 6 6 6-6"` on a 24 grid, `stroke-width:2`,
/// round cap and join. Always pointing down: the chevron only flips when
/// the panel expands, which this static render never does.
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(6, 9)
        ..lineTo(12, 15)
        ..lineTo(18, 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = kWhite,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => false;
}
