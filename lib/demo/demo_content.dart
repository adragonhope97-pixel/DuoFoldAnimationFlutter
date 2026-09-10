import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import 'demo_sections.dart';
import 'demo_style.dart';

/// `DemoContentView.swift` — the interface the fold effect looks at.
///
/// Pure Flutter on purpose: platform views are not rasterised into the
/// `AnimatedSampler`'s image (context.md → gotchas), exactly as UIKit-backed
/// SwiftUI views are not rasterised into a `layerEffect` layer.
///
/// Pinned to the iOS light appearance: every colour and size is a literal from
/// `demo_style.dart` and nothing here reads `Theme.of(context)`.
class DemoContent extends StatelessWidget {
  const DemoContent({super.key});

  /// `.padding(.horizontal, 20)` + `.padding(.vertical, 12)`.
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 12,
  );

  /// The root `VStack(alignment: .leading, spacing: 20)`.
  static const double sectionSpacing = 20;

  @override
  Widget build(BuildContext context) {
    // The page colour fills the whole screen including the safe areas (the
    // background is behind the status bar in the original); only the content
    // is inset. The non-scrolling scroll view reproduces SwiftUI's
    // top-aligned overflow + `.clipped()` without a RenderFlex overflow.
    return const ColoredBox(
      color: kSystemGroupedBackground,
      child: SafeArea(
        child: Padding(
          padding: contentPadding,
          child: SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DemoHeader(),
                SizedBox(height: sectionSpacing),
                DemoChips(),
                SizedBox(height: sectionSpacing),
                DemoHeroCard(),
                SizedBox(height: sectionSpacing),
                DemoStatGrid(),
                SizedBox(height: sectionSpacing),
                Text('Recent', style: kTitle3Semibold),
                SizedBox(height: sectionSpacing),
                DemoRecentList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `header`: the date and "Today" on the left, the "ES" avatar on the right.
///
/// SwiftUI aligns this row on `.firstTextBaseline`; a `Circle` has no text
/// baseline, so SwiftUI uses its bottom edge, putting the avatar's bottom on
/// the date's first baseline. Flutter's baseline alignment top-aligns
/// baseline-less children instead, so the offset is applied as an explicit top
/// inset on the text column ([textTopInset], see the plan's ## Math).
class DemoHeader extends StatelessWidget {
  const DemoHeader({super.key});

  /// 44 (avatar diameter) − 14.3 (first baseline of the 15 pt date line).
  static const double textTopInset = 29.7;

  static const double avatarDiameter = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: textTopInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Wednesday, 10 Sep', style: kSubheadlineSecondary),
                SizedBox(height: 4),
                Text('Today', style: kLargeTitleBold),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          key: const Key('demo-avatar'),
          width: avatarDiameter,
          height: avatarDiameter,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[kSystemPink, kSystemOrange],
            ),
          ),
          child: const Text('ES', style: kHeadlineWhite),
        ),
      ],
    );
  }
}

/// `chips`: six capsules, `HStack(spacing: 8)`, left-aligned and `.clipped()`
/// at the trailing edge — the row is wider than the screen and the last chip
/// is meant to be cut off.
class DemoChips extends StatelessWidget {
  const DemoChips({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: NeverScrollableScrollPhysics(),
      child: Row(
        children: <Widget>[
          DemoChip(key: Key('demo-chip-All'), label: 'All', selected: true),
          SizedBox(width: 8),
          DemoChip(key: Key('demo-chip-Health'), label: 'Health'),
          SizedBox(width: 8),
          DemoChip(key: Key('demo-chip-Work'), label: 'Work'),
          SizedBox(width: 8),
          DemoChip(key: Key('demo-chip-Reading'), label: 'Reading'),
          SizedBox(width: 8),
          DemoChip(key: Key('demo-chip-Travel'), label: 'Travel'),
          SizedBox(width: 8),
          DemoChip(key: Key('demo-chip-Music'), label: 'Music'),
        ],
      ),
    );
  }
}

/// One chip: `.padding(.horizontal, 14).padding(.vertical, 8)` in a capsule.
class DemoChip extends StatelessWidget {
  const DemoChip({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? kAccentColor : kSecondarySystemGroupedBackground,
        // Radii larger than half the height are scaled down when painted, so
        // this is a capsule at any height.
        borderRadius: const BorderRadius.all(Radius.circular(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: selected ? kSubheadlineMediumWhite : kSubheadlineMedium,
        ),
      ),
    );
  }
}

/// `heroCard`: the blue→purple→pink gradient card with the title row, the
/// body copy and twelve bars.
class DemoHeroCard extends StatelessWidget {
  const DemoHeroCard({super.key});

  static const String body =
      'Tilt the phone around its vertical axis. The interface stays put in '
      'space while the screen becomes a tilted pane of frosted glass.';

  /// `18 + (index * 37) % 46`, index 0…11 — the bar heights, verbatim.
  static double barHeight(int index) => (18 + (index * 37) % 46).toDouble();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[kSystemBlue, kSystemPurple, kSystemPink],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(CupertinoIcons.sparkles, size: 20, color: kWhite),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Frosted glass fold', style: kHeadlineWhite),
                ),
                Icon(CupertinoIcons.arrow_up_right, size: 20, color: kWhite),
              ],
            ),
            const SizedBox(height: 12),
            const Text(body, style: kSubheadlineWhite90),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                for (int i = 0; i < 12; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      key: Key('demo-hero-bar-$i'),
                      height: barHeight(i),
                      decoration: const BoxDecoration(
                        color: kWhite85,
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
