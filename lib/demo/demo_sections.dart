import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'demo_style.dart';

/// The `LazyVGrid` of four `StatTile`s: two flexible columns, spacing 12 in
/// both axes. `IntrinsicHeight` + `CrossAxisAlignment.stretch` gives the two
/// tiles in a row the equal heights a grid row has.
class DemoStatGrid extends StatelessWidget {
  const DemoStatGrid({super.key});

  static const double spacing = 12;

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: DemoStatTile(
                  title: 'Steps',
                  value: '8,412',
                  icon: Icons.directions_walk,
                  tint: kSystemGreen,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: DemoStatTile(
                  title: 'Sleep',
                  value: '7h 20m',
                  icon: CupertinoIcons.moon_zzz_fill,
                  tint: kSystemIndigo,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: DemoStatTile(
                  title: 'Focus',
                  value: '3h 05m',
                  icon: Icons.psychology,
                  tint: kSystemOrange,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: DemoStatTile(
                  title: 'Water',
                  value: '1.8 L',
                  icon: CupertinoIcons.drop_fill,
                  tint: kSystemCyan,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `StatTile`: `.padding(14)` on a 16 pt rounded `.background.secondary` card.
class DemoStatTile extends StatelessWidget {
  const DemoStatTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kBackgroundSecondary,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: tint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kSubheadlineSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kTitle2Semibold,
            ),
          ],
        ),
      ),
    );
  }
}

/// The `Recent` list: four rows in a 16 pt rounded `.background.secondary`
/// card, separated by hairlines inset 60 pt from the leading edge.
class DemoRecentList extends StatelessWidget {
  const DemoRecentList({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: kBackgroundSecondary,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DemoListRow(
            title: 'Morning run',
            subtitle: '5.2 km · 27 min',
            icon: Icons.directions_run,
            tint: kSystemGreen,
          ),
          DemoRowDivider(),
          DemoListRow(
            title: 'Design review',
            subtitle: '10:30 · Room 4B',
            icon: CupertinoIcons.calendar,
            tint: kSystemRed,
          ),
          DemoRowDivider(),
          DemoListRow(
            title: 'Flight to Lisbon',
            subtitle: 'Fri 18:45 · Gate 22',
            icon: CupertinoIcons.airplane,
            tint: kSystemBlue,
          ),
          DemoRowDivider(),
          DemoListRow(
            title: 'Read 20 pages',
            subtitle: 'The Left Hand of Darkness',
            icon: CupertinoIcons.book_fill,
            tint: kSystemBrown,
          ),
        ],
      ),
    );
  }
}

/// `Divider().padding(.leading, 60)`.
class DemoRowDivider extends StatelessWidget {
  const DemoRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    // A childless ColoredBox would collapse to zero width (context.md →
    // gotchas); a childless Container expands.
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 60),
      color: kSeparator,
    );
  }
}

/// `ListRow`: a 34 pt tinted icon square, title + subtitle, and a chevron.
class DemoListRow extends StatelessWidget {
  const DemoListRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(icon, size: 20, color: kWhite),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kBodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kFootnoteSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: kTertiaryLabel,
          ),
        ],
      ),
    );
  }
}
