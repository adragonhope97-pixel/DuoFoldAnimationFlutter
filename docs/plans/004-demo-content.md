# 004 demo-content

## Goal

When this phase is done, the thing under the fold effect is
`DemoContentView.swift`, not a placeholder: an iOS light "Today" screen with a
date + `Today` + gradient "ES" avatar header, a clipped row of six capsule
chips, a blue→purple→pink gradient hero card carrying twelve white bars, a 2×2
grid of stat tiles, a `Recent` title, and a four-row list with coloured icon
squares and hairline dividers inset by 60 pt — same sections, same strings,
same colours, same geometry as the Swift. The app theme switches to light (the
switch 003 deferred), the status bar draws dark glyphs, and the floating
control panel's frosted material is retinted for a light background. Nothing
under the sampler is a platform view. No shader, uniform, parameter or motion
code is touched, so this phase's acceptance stands whether or not the motion
sign turns out to need a fix.

## Decisions

1. **The Swift is transcribed, not reinterpreted.** Every string, spacing,
   padding, corner radius, colour and font size below is read off
   `DemoContentView.swift` (fetched verbatim this phase). Where SwiftUI has no
   Flutter equivalent (SF Symbols, semantic colours, `.background.secondary`)
   the substitution is named here and nowhere else.
2. **Light appearance, hard-coded.** The original sets no
   `preferredColorScheme`, so it follows the system; `Docs/demo.png` (the
   README's photo, inspected this phase) shows it running in **light**
   appearance — light grey page, white-ish cards, dark labels. The port pins
   light: `DemoContent` hard-codes the light values of the UIColor semantic
   names and reads `Theme.of(context)` **nowhere**, so a later theme change
   cannot move the reference screen. `MaterialApp.theme` also becomes light
   (assessment §1) and its seed becomes `#007AFF` (systemBlue = SwiftUI's
   default `.accentColor`) so the panel's Material controls stop being purple.
3. **`.background.secondary` → `#F2F2F7`.** SwiftUI's hierarchical background
   style resolves to the secondary system background, which in light
   appearance is `#F2F2F7` — the same colour as the page's
   `systemGroupedBackground`. The stat tiles and the Recent list are therefore
   *almost invisible cards* in light mode. That is what the original does (and
   it matches the photo, where no card edge is visible); it is not a bug, and
   the implementer must not "improve" it to white. The chips are different:
   they ask for `secondarySystemGroupedBackground` = `#FFFFFF`, which does read
   against the page.
4. **Content is laid out at natural height and clipped at the bottom.** Summed
   at 390×844 the sections need ≈ 860 pt against ≈ 763 pt of padded safe area,
   so on a short screen the last Recent rows fall off the bottom. SwiftUI does
   exactly this (the `VStack` overflows the `.frame(maxHeight: .infinity,
   alignment: .top)` and `ContentView`'s `.clipped()` cuts it). Flutter's
   `Column` would instead throw a `RenderFlex` overflow, so the root column
   sits in a `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`:
   natural height, top-aligned, hard-edge clip, no scrolling, no error. Do not
   "fix" a cut-off bottom by shrinking text or enabling scrolling.
5. **Header avatar rides high, on purpose.** `HStack(alignment:
   .firstTextBaseline)` with a `Circle` — a view with no text — falls back to
   the circle's **bottom edge** as its baseline, so the avatar's bottom lands
   on the date's first baseline and the text column is pushed down. Flutter's
   `CrossAxisAlignment.baseline` instead top-aligns baseline-less children, so
   the offset is applied explicitly as a 29.7 pt top inset on the text column
   (derivation in `## Math`). This is the one place where a magic constant
   encodes SwiftUI behaviour; it is named `DemoHeader.textTopInset`.
6. **No `height:` on any `TextStyle`.** SwiftUI's `Text` takes its box from
   the font's line height (≈ 1.163 em for SF Pro), not from the HIG's larger
   "line height" column. Leaving `height` null gives Flutter the same
   font-metric box on the device and an exactly-1.0-em box under the widget
   test font, which keeps the test's geometry assertions deterministic.
7. **SF Symbols → the closest available glyph, spelled out.** `CupertinoIcons`
   *is* the SF Symbols set and is already a dependency (`cupertino_icons`
   1.0.9, verified in `pubspec.lock`), so it is used wherever the symbol
   exists; three symbols have no Cupertino equivalent and fall back to
   Material pictograms that draw the same subject:

   | SF Symbol | Flutter | Note |
   |---|---|---|
   | `sparkles` | `CupertinoIcons.sparkles` | exact |
   | `arrow.up.right` | `CupertinoIcons.arrow_up_right` | exact |
   | `chevron.right` | `CupertinoIcons.chevron_right` | exact |
   | `calendar` | `CupertinoIcons.calendar` | exact |
   | `airplane` | `CupertinoIcons.airplane` | exact |
   | `book.fill` | `CupertinoIcons.book_fill` | exact |
   | `drop.fill` | `CupertinoIcons.drop_fill` | exact |
   | `moon.zzz.fill` | `CupertinoIcons.moon_zzz_fill` | exact |
   | `figure.walk` | `Icons.directions_walk` | no Cupertino walking figure |
   | `figure.run` | `Icons.directions_run` | no Cupertino running figure |
   | `brain.head.profile` | `Icons.psychology` | head profile + brain |

   All eleven names were checked against the installed Flutter 3.47.1 SDK.
   Icon `size` = round(1.2 × the SF font size the symbol inherits): 20 for the
   17 pt contexts, 16 for the 13 pt chevron.
8. **Three files, not one.** The port is ~390 lines; it is split into
   `demo_style.dart` (colours + text styles), `demo_content.dart` (root,
   header, chips, hero card) and `demo_sections.dart` (stat grid, Recent
   list), each under 200 lines. Section widgets are public so the test can
   count them. `context.md`'s file layout gains the two new names.
9. **Panel retint only.** The frosted material in `control_panel.dart` was
   `colorScheme.surface` at 62 % on a dark scheme; it becomes an explicit iOS
   light `.ultraThinMaterial` stand-in (62 % `#F2F2F7`, 12 % black hairline)
   so it does not follow the M3 seed and does not go dark over the now-light
   content. Slider/Switch/Button tint fidelity is **006**, not this phase.
10. **Status bar.** The page is light, so the status bar needs dark glyphs:
    `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.dark)`
    around the `Scaffold` (`.dark` = dark icons / `statusBarBrightness:
    Brightness.light`, verified in the SDK).
11. **Acceptance is taken at θ = 0.** Everything checkable about this phase is
    checkable with the manual slider at 0°, where the shader is the identity.
    The checklist deliberately contains no statement about which edge is the
    hinge, so a later motion-sign correction cannot invalidate it.
12. **Divider thickness 0.5 pt** (a hairline is `1/3` pt at 3×; 0.5 is within
    a subpixel of it and keeps the widget test resolution-independent).

## Files

### 1. NEW `lib/demo/demo_style.dart`

```dart
import 'package:flutter/widgets.dart';

/// The light-appearance values of the UIColor semantic names
/// `DemoContentView.swift` asks for, plus the iOS text styles it uses.
///
/// The demo screen is pinned to the iOS light appearance (004), so these are
/// literals: nothing in `demo_content.dart` or `demo_sections.dart` may read
/// `Theme.of(context)`, or the reference screen would move when the app theme
/// changes.

// ---------------------------------------------------------------- fills ----

/// `Color(.systemGroupedBackground)` — the page.
const Color kSystemGroupedBackground = Color(0xFFF2F2F7);

/// `Color(.secondarySystemGroupedBackground)` — the unselected chips.
const Color kSecondarySystemGroupedBackground = Color(0xFFFFFFFF);

/// `.background.secondary` — the stat tiles and the Recent list. In light
/// appearance this equals the page colour; the cards are meant to be nearly
/// invisible. See the plan's decision 3.
const Color kBackgroundSecondary = Color(0xFFF2F2F7);

// --------------------------------------------------------------- labels ----

/// `.primary` / `UIColor.label`.
const Color kLabel = Color(0xFF000000);

/// `.secondary` / `UIColor.secondaryLabel` (#3C3C43 at 60 %).
const Color kSecondaryLabel = Color(0x993C3C43);

/// `.tertiary` / `UIColor.tertiaryLabel` (#3C3C43 at 30 %).
const Color kTertiaryLabel = Color(0x4D3C3C43);

/// `Divider()` / `UIColor.separator` (#3C3C43 at 29 %).
const Color kSeparator = Color(0x493C3C43);

// ---------------------------------------------------------------- tints ----

/// `Color.accentColor` — the app tint, which defaults to systemBlue.
const Color kAccentColor = Color(0xFF007AFF);
const Color kSystemBlue = Color(0xFF007AFF);
const Color kSystemGreen = Color(0xFF34C759);
const Color kSystemIndigo = Color(0xFF5856D6);
const Color kSystemOrange = Color(0xFFFF9500);
const Color kSystemCyan = Color(0xFF32ADE6);
const Color kSystemRed = Color(0xFFFF3B30);
const Color kSystemBrown = Color(0xFFA2845E);
const Color kSystemPink = Color(0xFFFF2D55);
const Color kSystemPurple = Color(0xFFAF52DE);

const Color kWhite = Color(0xFFFFFFFF);

/// `.opacity(0.9)` on the hero card's body text.
const Color kWhite90 = Color(0xE6FFFFFF);

/// `.white.opacity(0.85)` — the hero card's bars.
const Color kWhite85 = Color(0xD9FFFFFF);

// ----------------------------------------------------------------- text ----
// Sizes and weights are the iOS text styles at the default Dynamic Type size.
// `height` is deliberately left null: SwiftUI's Text takes its box from the
// font's line height, which is what Flutter does with no override.

/// `.largeTitle.bold()`
const TextStyle kLargeTitleBold = TextStyle(
  fontSize: 34,
  fontWeight: FontWeight.w700,
  color: kLabel,
);

/// `.title2.weight(.semibold)`
const TextStyle kTitle2Semibold = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w600,
  color: kLabel,
);

/// `.title3.weight(.semibold)`
const TextStyle kTitle3Semibold = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: kLabel,
);

/// `.headline` on white content.
const TextStyle kHeadlineWhite = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  color: kWhite,
);

/// `.body.weight(.medium)`
const TextStyle kBodyMedium = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w500,
  color: kLabel,
);

/// `.subheadline` + `.foregroundStyle(.secondary)`
const TextStyle kSubheadlineSecondary = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w400,
  color: kSecondaryLabel,
);

/// `.subheadline.weight(.medium)`
const TextStyle kSubheadlineMedium = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: kLabel,
);

/// `.subheadline.weight(.medium)` on the selected chip.
const TextStyle kSubheadlineMediumWhite = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: kWhite,
);

/// `.subheadline` + `.opacity(0.9)` on the hero card.
const TextStyle kSubheadlineWhite90 = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w400,
  color: kWhite90,
);

/// `.footnote` + `.foregroundStyle(.secondary)`
const TextStyle kFootnoteSecondary = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: kSecondaryLabel,
);
```

### 2. REPLACE `lib/demo/demo_content.dart` (whole file)

```dart
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
```

### 3. NEW `lib/demo/demo_sections.dart`

```dart
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
```

### 4. EDIT `lib/main.dart` — three hunks

**4a. imports.** Before:

```dart
import 'package:flutter/material.dart';

import 'demo/control_panel.dart';
```

After:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'demo/control_panel.dart';
```

**4b. theme.** Before:

```dart
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
```

After:

```dart
      // Light, like the original running in the light appearance (see
      // Docs/demo.png). Seeded with systemBlue because SwiftUI's default
      // `.accentColor` is systemBlue; the demo content itself hard-codes
      // every colour and does not read this theme.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
        ),
      ),
```

**4c. status bar.** Before:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ListenableBuilder(
            listenable: _model,
            builder: (BuildContext context, Widget? child) {
              return FoldEffect(
                angle: _model.theta,
                params: widget.params,
                child: child!,
              );
            },
            child: const DemoContent(),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(child: ControlPanel(model: _model)),
          ),
        ],
      ),
    );
  }
```

After:

```dart
  @override
  Widget build(BuildContext context) {
    // Dark status-bar glyphs over the light demo content. `.dark` names the
    // icon brightness, not the background's.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Black is what the shader paints where a ray misses the interface.
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ListenableBuilder(
              listenable: _model,
              builder: (BuildContext context, Widget? child) {
                return FoldEffect(
                  angle: _model.theta,
                  params: widget.params,
                  child: child!,
                );
              },
              child: const DemoContent(),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(child: ControlPanel(model: _model)),
            ),
          ],
        ),
      ),
    );
  }
```

### 5. EDIT `lib/demo/control_panel.dart` — one hunk

Before:

```dart
/// Stand-in for SwiftUI's `.ultraThinMaterial`: backdrop blur under a
/// translucent surface tint.
class _Frosted extends StatelessWidget {
  const _Frosted({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

After:

```dart
/// Stand-in for SwiftUI's `.ultraThinMaterial` in the **light** appearance:
/// backdrop blur under a translucent light tint. Explicit colours, not
/// scheme-derived, so the panel stays neutral over the light demo content and
/// over the black the shader paints outside the interface (004, decision 9).
class _Frosted extends StatelessWidget {
  const _Frosted({required this.radius, required this.child});

  /// iOS light `.ultraThinMaterial` ≈ 62 % of #F2F2F7 over a heavy blur.
  static const Color _tint = Color(0x9EF2F2F7);
  static const Color _hairline = Color(0x1F000000);

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _hairline),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### 6. NEW `test/demo_content_test.dart`

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_sections.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_style.dart';

/// Lays the demo screen out at iPhone-13 metrics: 390 x 844 logical px with
/// the portrait safe-area insets.
Future<void> pumpDemo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Builder(
      builder: (BuildContext context) {
        return MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: DemoContent(),
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets('DemoContentView strings are all present', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);

    for (final String s in <String>[
      'Wednesday, 10 Sep',
      'Today',
      'ES',
      'All',
      'Health',
      'Work',
      'Reading',
      'Travel',
      'Music',
      'Frosted glass fold',
      'Steps',
      '8,412',
      'Sleep',
      '7h 20m',
      'Focus',
      '3h 05m',
      'Water',
      '1.8 L',
      'Recent',
      'Morning run',
      '5.2 km · 27 min',
      'Design review',
      '10:30 · Room 4B',
      'Flight to Lisbon',
      'Fri 18:45 · Gate 22',
      'Read 20 pages',
      'The Left Hand of Darkness',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text(DemoHeroCard.body), findsOneWidget);
    expect(find.byType(DemoStatTile), findsNWidgets(4));
    expect(find.byType(DemoListRow), findsNWidgets(4));
    expect(find.byType(DemoRowDivider), findsNWidgets(3));
  });

  testWidgets('the page is the light grouped background', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    expect(tester.getSize(find.byType(DemoContent)), const Size(390, 844));
    final ColoredBox page = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(DemoContent),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(page.color, kSystemGroupedBackground);
  });

  testWidgets('header geometry: avatar in the top-trailing corner', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    final Finder avatar = find.byKey(const Key('demo-avatar'));
    expect(tester.getSize(avatar), const Size(44, 44));
    // x: 390 − 20 (horizontal padding) − 44. y: 47 (safe area) + 12 (padding).
    expect(tester.getTopLeft(avatar), const Offset(326, 59));
  });

  testWidgets('chips start at the leading padding, below the header', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    final Finder all = find.byKey(const Key('demo-chip-All'));
    final Offset topLeft = tester.getTopLeft(all);
    expect(topLeft.dx, 20);
    // 59 (content top) + 29.7 + 15 + 4 + 34 (header, test font) + 20 (spacing).
    expect(topLeft.dy, moreOrLessEquals(161.7, epsilon: 0.01));
    // 8 + 15 (test-font line box) + 8.
    expect(tester.getSize(all).height, moreOrLessEquals(31, epsilon: 0.01));
  });

  testWidgets('the hero card has twelve bars of 18 + (i * 37) % 46', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);
    for (int i = 0; i < 12; i++) {
      final double expected = (18 + (i * 37) % 46).toDouble();
      expect(
        tester.getSize(find.byKey(Key('demo-hero-bar-$i'))).height,
        expected,
        reason: 'bar $i',
      );
    }
  });
}
```

### 7. EDIT `context.md` — two hunks

**7a. file layout.** Before:

```
  demo/
    demo_content.dart        # the interface being looked at
    control_panel.dart       # floating panel
```

After:

```
  demo/
    demo_content.dart        # DemoContentView port: root, header, chips, hero
    demo_sections.dart       # DemoContentView port: stat grid, Recent list
    demo_style.dart          # iOS light system colours + text styles
    control_panel.dart       # floating panel
```

**7b. gotchas.** Append these bullets to the end of `## Gotchas already known`:

```
- The demo screen is pinned to the iOS **light** appearance (004). It hard-codes
  the light values of the UIColor semantic names and reads `Theme.of(context)`
  nowhere, so theme changes cannot move the reference screen. `MaterialApp`'s
  theme is light and seeded with `#007AFF` from 004 on.
- `.background.secondary` (the stat tiles and the Recent list) is `#F2F2F7` in
  light appearance — the same colour as the page. The near-invisible cards are
  the original's, not a porting bug.
- The content is taller than the screen at 390x844. It is laid out at natural
  height in a `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`
  and clipped at the bottom, which is what SwiftUI's overflowing top-aligned
  `VStack` plus `ContentView`'s `.clipped()` does. Do not shrink it to fit.
- SwiftUI's `.firstTextBaseline` uses a shape's **bottom edge** as its baseline,
  so `DemoContentView`'s avatar sits high; Flutter's `CrossAxisAlignment
  .baseline` top-aligns baseline-less children instead, so the offset is an
  explicit `DemoHeader.textTopInset = 29.7`.
- SwiftUI `Text` boxes come from the font's line height (~1.163 em), not from
  the HIG "line height" column; leave `TextStyle.height` null in the demo.
```

## Math

No shader, uniform or angle maths changes this phase. `uSize`, `uAngle`,
`uEyeDistPx`, `uMaxBlurPx`, `uDimStrength` and the θ > 0 ⇒ hinge-on-the-right
convention in `context.md` are untouched, and nothing here reads θ.

**1. Bar heights (verbatim from Swift).** For `index` in 0…11:

```
barHeight(index) = 18 + (index * 37) % 46
```

giving, in order: 18, 55, 46, 37, 28, 19, 56, 47, 38, 29, 20, 57. The twelve
bars share the card's inner width with 6 pt gaps: each is
`(W_card − 2·18 − 11·6) / 12` wide, i.e. `Expanded` in a `Row`. The `HStack`'s
default alignment is `.center`, so short bars are vertically centred, not
bottom-aligned; `Row`'s default `CrossAxisAlignment.center` matches.

**2. Header baseline lift (`DemoHeader.textTopInset`).** SwiftUI resolves
`VerticalAlignment.firstTextBaseline` for a view with no text to its bottom
edge, so:

```
avatarBottom_y = dateFirstBaseline_y
textColumnTop_y = avatarDiameter − ascent(15 pt)
                = 44 − 0.9508 × 15
                = 44 − 14.26
                = 29.74  → textTopInset = 29.7
```

where 0.9508 em is SF Pro Text's ascent. Header height is therefore
`29.7 + h(date) + 4 + h(Today)` ≈ 90.7 pt on the device (SF line boxes 17.4
and 39.6) and exactly `29.7 + 15 + 4 + 34 = 82.7` pt under the widget-test
font, whose line box is 1.0 em. The avatar's top edge is the top of the
header either way; the avatar's own box is 44 × 44 and its right edge is at
`W − 20`.

**3. Section stack.** Top to bottom, from the padded safe-area origin
`(20, 12)` inside the safe area:

```
header, 20, chips, 20, heroCard, 20, statGrid, 20, "Recent", 20, recentList
```

with per-section geometry:

| Section | Geometry (pt) |
|---|---|
| chips | text + 14 horizontal / 8 vertical padding, capsule, 8 between |
| heroCard | 18 padding, radius 20, inner spacing 12, bar gap 6 |
| statGrid | 2 columns, 12 column gap, 12 row gap; tile padding 14, radius 16, inner spacing 10, icon→title gap 8 |
| recentList | radius 16; row padding 14 horizontal / 10 vertical; icon square 34 radius 8; icon→text gap 14; title→subtitle gap 2; divider 0.5 tall inset 60 from the leading edge |

Summed at 390 pt wide this is ≈ 860 pt against ≈ 763 pt of padded safe area,
so the bottom of the Recent list is clipped on a 844 pt screen — see decision
4; this matches the original, which overflows and is `.clipped()`.

**4. Colour derivations.** SwiftUI semantic name → light-appearance sRGB:

```
systemGroupedBackground          #F2F2F7
secondarySystemGroupedBackground #FFFFFF
.background.secondary            #F2F2F7   (secondarySystemBackground)
label / .primary                 #000000
.secondary                       #3C3C43 @ 60 %  → 0x993C3C43
.tertiary                        #3C3C43 @ 30 %  → 0x4D3C3C43
separator                        #3C3C43 @ 29 %  → 0x493C3C43
accentColor / systemBlue         #007AFF
systemGreen  #34C759   systemIndigo #5856D6   systemOrange #FF9500
systemCyan   #32ADE6   systemRed    #FF3B30   systemBrown  #A2845E
systemPink   #FF2D55   systemPurple #AF52DE
white 0.9 → 0xE6FFFFFF     white 0.85 → 0xD9FFFFFF
```

Gradients are both `startPoint: .topLeading, endPoint: .bottomTrailing`, i.e.
`begin: Alignment.topLeft, end: Alignment.bottomRight`: avatar
`[pink, orange]`, hero `[blue, purple, pink]` with equal stops.

## Commands

Run in order, from the repo root:

```sh
flutter analyze
flutter test
flutter build ios --debug --no-codesign
```

All three must succeed before the report is written. For the human's visual
pass afterwards (not the implementer's job to interpret):

```sh
flutter run -d 00008120-000278980AE3601E --dart-define=MANUAL_TILT=true
```

## Acceptance

**Tree-checkable (implementer).**

- T1 `flutter analyze` reports no issues.
- T2 `flutter test` passes, including the five new tests in
  `test/demo_content_test.dart` and the untouched 002/003 suites.
- T3 `flutter build ios --debug --no-codesign` succeeds.
- T4 `git diff --stat` shows exactly: `lib/demo/demo_style.dart` (new),
  `lib/demo/demo_sections.dart` (new), `test/demo_content_test.dart` (new),
  `lib/demo/demo_content.dart`, `lib/main.dart`, `lib/demo/control_panel.dart`,
  `context.md`, `docs/plans/004-demo-content.md`. Nothing under `shaders/`,
  `ios/`, `lib/fold/`, `lib/motion/` or `pubspec.yaml`.
- T5 `grep -rn "Theme.of" lib/demo/demo_content.dart lib/demo/demo_sections.dart
  lib/demo/demo_style.dart` returns nothing.

**Visual, on the iPhone, with the panel open, Manual tilt on and the slider at
0.0° (identity shader — nothing below depends on the motion sign).**

- H1 The whole screen is light: page `#F2F2F7` edge to edge, including behind
  the status bar and below the home indicator. No dark surface anywhere under
  the effect.
- H2 Status-bar glyphs are dark.
- H3 Top to bottom, in this order: grey "Wednesday, 10 Sep" then large black
  "Today"; a pink→orange circle with white "ES" at the trailing edge, sitting
  **higher** than the "Today" line (its bottom is level with the date's
  baseline); a row of capsule chips beginning with a blue "All" with white
  text, the rest white with black text, the last chip cut off by the trailing
  screen edge; a full-width blue→purple→pink rounded card with a sparkles
  icon, "Frosted glass fold", an arrow-up-right icon, three or four lines of
  body text and twelve white bars of alternating heights, the last bar the
  tallest; a 2×2 group of stat tiles — Steps 8,412 (green), Sleep 7h 20m
  (indigo), Focus 3h 05m (orange), Water 1.8 L (cyan); "Recent"; a list of
  Morning run / Design review / Flight to Lisbon / Read 20 pages with green,
  red, blue and brown icon squares, each with a subtitle and a faint chevron.
- H4 The stat tiles and the Recent list have **no visible card edge** against
  the page. This is correct (decision 3).
- H5 If the Recent list is cut off by the bottom of the screen, that is
  expected (decision 4). Report which row is the last fully visible one so 006
  can compare against the original.
- H6 The floating control panel reads as a light frosted sheet with dark,
  legible text, both where it overlaps the content and where it overlaps
  black. It is not tinted purple.
- H7 Sweep the manual slider to ±20°: the whole screen still shows this
  content, reprojected, with black only at the lifted edge. No smearing at the
  borders, no dark-theme flash. **Do not judge which edge is the hinge here** —
  that is 003's device checklist.

## Out of scope

- `shaders/duo_fold.frag`, the uniform table, `FoldParameters`, `FoldEffect`,
  `fold_shader.dart` — untouched. No blur, no dimming (005).
- `lib/motion/**`, `ios/Runner/AppDelegate.swift`, the tilt sign, calibration
  and the 003 device checklist — untouched.
- `pubspec.yaml` and `pubspec.lock`: no new packages (`cupertino_icons` is
  already a direct dependency and `CupertinoIcons` ships with the framework).
- The control panel beyond `_Frosted`'s colours: the Slider/Switch/Button
  tints, the panel's typography and its transition are 006's parity sweep.
- Dark-appearance support, Dynamic Type, localisation, orientation handling.
- Do not add a `Scrollable` the user can actually scroll, a `ListView`, a
  `GridView`, or any platform view.

## Implementation report
STATUS: DONE
Files written:
- lib/demo/demo_style.dart
- lib/demo/demo_sections.dart
- test/demo_content_test.dart

Files edited:
- lib/demo/demo_content.dart — replaced whole file with the DemoContentView port (header, chips, hero card), as given in the plan.
- lib/main.dart — added `flutter/services.dart` import, switched `MaterialApp.theme` to light seeded with `#007AFF`, wrapped `FoldScreen`'s `Scaffold` in `AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.dark)`.
- lib/demo/control_panel.dart — replaced `_Frosted`'s scheme-derived tint/border with explicit light constants (`_tint = 0x9EF2F2F7`, `_hairline = 0x1F000000`); dropped the now-unused `Theme.of(context)` lookup.
- context.md — added the three new demo files to the file-layout table; appended the four new gotchas bullets.

Deviations from plan: none.
Self-fixes applied: none.
Command results:
  flutter analyze — clean (No issues found!)
  flutter test — clean; all 17 tests pass across reprojection_test.dart (4), widget_test.dart (8) and the 5 new tests in demo_content_test.dart (concurrent compact-reporter output interleaves/overwrites some progress lines when piped, but `--concurrency=1` confirms all three suites load and all 17 tests pass)
  flutter build ios --debug --no-codesign — ok (`Built build/ios/iphoneos/Runner.app`)
  flutter run — not run (per orchestrator instruction; human visual pass is separate)

git diff --stat / status matches T4 exactly: context.md, lib/demo/control_panel.dart, lib/demo/demo_content.dart, lib/main.dart modified; lib/demo/demo_sections.dart, lib/demo/demo_style.dart, test/demo_content_test.dart new. Nothing under shaders/, ios/, lib/fold/, lib/motion/ or pubspec.yaml touched.
`grep -rn "Theme.of" lib/demo/demo_content.dart lib/demo/demo_sections.dart lib/demo/demo_style.dart` returns only doc-comment mentions, no code usage (T5 satisfied).

Open questions for architect: none.

## Review

STATUS: ACCEPTED

Reviewed: `git diff ad99def` (4 modified, 3 untracked-new), the three new/replaced
Dart files read in full, and the original Swift re-fetched this review
(`DemoContentView.swift` in four pieces, `ContentView.swift`, and
`Assets.xcassets/AccentColor.colorset/Contents.json`). `Docs/demo.png` was
re-downloaded and inspected at 4–8× on three crops (status bar, chips row, hero
bars). `flutter test` was not re-run here (read-only mandate); the report's
17/17 is accepted, and the four numeric expectations in the new test were
re-derived by hand instead — see 3.6.

### 1. Diff vs plan

1.1 `lib/demo/demo_style.dart`, `lib/demo/demo_sections.dart`,
`test/demo_content_test.dart`, `lib/demo/demo_content.dart` — byte-identical to
the plan's file bodies, including comments and key strings.
1.2 `lib/main.dart` — the three hunks applied exactly (services import, light
scheme seeded `0xFF007AFF`, `AnnotatedRegion<SystemUiOverlayStyle>` wrapper with
both comments).
1.3 `lib/demo/control_panel.dart` — hunk applied exactly; the now-dead
`Theme.of(context)` local removed, which the plan implied and analyze required.
1.4 `context.md` — both hunks applied exactly.
1.5 T4 holds: nothing under `shaders/`, `ios/`, `lib/fold/`, `lib/motion/`,
`pubspec.yaml`, `pubspec.lock`. Report's "deviations: none" is true.

### 2. Source fidelity (checked against the Swift, not against the report)

Verified verbatim from `DemoContentView.swift`:

- root: `VStack(alignment:.leading, spacing:20){header;chips;heroCard;LazyVGrid;
  Text("Recent").font(.title3.weight(.semibold));VStack(spacing:0){rows};
  Spacer(minLength:0)}.padding(.horizontal,20).padding(.vertical,12)
  .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
  .background(Color(.systemGroupedBackground))` — section order, both paddings,
  spacing 20, page colour all match the port.
- `columns = [GridItem(.flexible(), spacing: 12) ×2]`, `LazyVGrid(spacing: 12)`.
  `GridItem.spacing` is the gap **after** the item, so the column gap is 12 once,
  i.e. tile width `(W−12)/2`. The port's `Expanded / SizedBox(12) / Expanded` is
  exactly that, not `(W−24)/2`. Correct.
- `chips`: `HStack(spacing:8)` over `["All","Health","Work","Reading","Travel",
  "Music"]`, `.font(.subheadline.weight(.medium)).lineLimit(1).fixedSize()
  .padding(.horizontal,14).padding(.vertical,8)`, background
  `label=="All" ? Color.accentColor : Color(.secondarySystemGroupedBackground)`
  in `.capsule`, foreground `.white`/`.primary`, then
  `.frame(minWidth:0,maxWidth:.infinity,alignment:.leading).clipped()`. The port
  (non-scrollable horizontal `SingleChildScrollView`, `Clip.hardEdge`,
  `maxLines:1, softWrap:false`) is layout-equivalent: natural chip widths,
  leading-aligned, trailing chip cut. Photo confirms the trailing cut (crop 3).
- `heroCard`: `VStack(alignment:.leading, spacing:12)`, title `HStack` at
  `.font(.headline)`, body `.subheadline.opacity(0.9)`, bars
  `HStack(spacing:6){ForEach(0..<12){RoundedRectangle(cornerRadius:3)
  .fill(.white.opacity(0.85)).frame(height: CGFloat(18 + (index*37) % 46))}}`,
  `.foregroundStyle(.white).padding(18)`, gradient `[.blue,.purple,.pink]`
  topLeading→bottomTrailing in `.rect(cornerRadius:20)`. All present in the port.
- `StatTile`: `VStack(spacing:10){HStack{Image(tint);Text(title).subheadline
  .secondary;Spacer()};Text(value).title2.weight(.semibold)}.padding(14)
  .background(.background.secondary, in:.rect(cornerRadius:16))` — matches.
- `ListRow`: `HStack(spacing:14)`, icon `.system(size:17,weight:.semibold)`
  white in `34×34` tinted `.rect(cornerRadius:8)`, `VStack(spacing:2)` with
  `.body.weight(.medium)` / `.footnote.secondary`, `Spacer()`, chevron
  `.footnote.weight(.semibold)` `.tertiary`, `.padding(.horizontal,14)
  .padding(.vertical,10)` — matches, including the 14 on **both** sides of the
  text column.
- `rows` — all four titles, subtitles, symbols and tints match the port
  character for character (`5.2 km · 27 min`, `10:30 · Room 4B`,
  `Fri 18:45 · Gate 22`, `The Left Hand of Darkness`; green/red/blue/brown).
- `header` — `HStack(alignment:.firstTextBaseline){VStack(spacing:4){date
  .subheadline.secondary; Text("Today").largeTitle.bold()}; Spacer();
  Circle().fill(LinearGradient([.pink,.orange], topLeading→bottomTrailing))
  .frame(44,44).overlay{Text("ES").headline.white}}`. `.overlay` does not
  contribute an alignment guide, so the circle's guide is the default fallback
  (its bottom edge). Decision 5 is confirmed against the source, not assumed.
- `ContentView`: `DemoContentView().safeAreaPadding(insets)
  .frame(size + insets).clipped().foldEffect(angle:).ignoresSafeArea()`. So the
  content is inset by the safe area while the page colour reaches the physical
  edges, and the overflow is hard-clipped — exactly the port's
  `ColoredBox → SafeArea → Padding(20,12) → non-scrollable SingleChildScrollView`.
  Decision 4 is confirmed by `.clipped()` plus the flexible `Spacer(minLength:0)`
  that collapses to 0 before the inflexible Texts give way.

### 3. Geometry, recomputed independently

3.1 **Bar heights.** `18 + (index*37) % 46`; `*` and `%` are equal precedence and
left-associative in both Swift and Dart, and the Dart port parenthesises the
product anyway. Sequence 18, 55, 46, 37, 28, 19, 56, 47, 38, 29, 20, 57 — matches
`## Math` §1 and the test's independent recomputation. Index 11 = 57 is the
tallest, and the photo shows the right-most bar clearly the tallest. Correct.
3.2 **Bar cross-axis alignment.** The Swift's `.frame(maxWidth:.infinity,
alignment:.bottom)` is on the *frame*, not the HStack's internal alignment, which
stays `.center`. Crop 2 of the photo confirms it: bar 11 (57) and bar 10 (20)
share a midline, they are not bottom-aligned. `Row`'s default
`CrossAxisAlignment.center` is right. `## Math` §1 was correct.
3.3 **Header inset.** Recomputed from UIFont system-font metrics
(ascender/size = 0.9531, descender/size = 0.2283, i.e. ascent 14.30 pt at 15 pt):
`textTopInset = 44 − 14.30 = 29.70`. The plan's 0.9508 em gives 29.74. Both round
to the shipped **29.7**; the constant is correct and is insensitive to which of
the two ascent figures is used (Δ = 0.04 pt). The doc comment in
`demo_content.dart` ("44 − 14.3") uses the better of the two numbers.
3.4 **Content origin.** SwiftUI: safe-area 47 then `.padding(.vertical,12)` → 59.
Port: `SafeArea` then `contentPadding` → 59. Avatar x = 390−20−44 = 326. Header
cross-extent = max(29.7+15+4+34, 44) = 82.7 under the test font, so
`CrossAxisAlignment.start` puts the avatar at y = 59. Test's `Offset(326, 59)` is
right.
3.5 **Chips y.** 59 + 82.7 + 20 = 161.7; chip height 8+15+8 = 31. Test is right.
3.6 **Widths under `CrossAxisAlignment.start`** (the one place a literal port can
silently shrink a card): hero card, stat grid and Recent list each contain a
`Row` with `MainAxisSize.max`, so each takes the full 350 pt; the childless
`Container` divider takes the `ConstrainedBox(expand)` path and spans 350−60. No
section collapses to intrinsic width. Matches the SwiftUI `.frame(maxWidth:
.infinity)` / `Spacer()` behaviour in every section.
3.7 **Overflow.** Recomputed at 390×844 with device line boxes: content ≈ 868 pt
against 844−47−34−24 = **739 pt** of padded safe area (the plan's `## Math` §3
said 763, having forgotten the 12 pt vertical padding at both ends — errata, no
code impact; the conclusion is unchanged and the clip is deeper, not shallower).
The Recent list starts ≈ 695.8 pt down and the viewport ends at ≈ 798, so
**expect only "Morning run" fully visible and "Design review" cut mid-row**.
This is the same in the original — same numbers, same `.clipped()`.

### 4. Colours, against the photo and the asset catalog

4.1 The photo is unambiguously **light** appearance: near-white page, and the
trailing status-bar glyphs (silent/wifi/battery) are **dark on light** in crop 1.
Decision 2 and decision 10 (`SystemUiOverlayStyle.dark` = dark glyphs,
`statusBarBrightness: Brightness.light`) are confirmed by evidence, not taste.
4.2 `AccentColor.colorset/Contents.json` defines a universal colour with **no
components**, so `Color.accentColor` falls through to systemBlue. `kAccentColor
= #007AFF` and the `#007AFF` seed are correct.
4.3 Hero gradient reads blue → purple → magenta-pink left-to-right in the photo,
avatar reads pink-orange: consistent with `[blue,purple,pink]` and
`[pink,orange]` topLeading→bottomTrailing.
4.4 No card edge is visible anywhere below the hero card in the photo, which is
the positive evidence for `.background.secondary` = `#F2F2F7` = the page colour
in light appearance. Decision 3 stands; H4 is expected to pass, not to look odd.
4.5 Semantic literals spot-checked: label #000, secondary/tertiary/separator
`#3C3C43` at 60/30/29 %, `0x99/0x4D/0x49` = 153/77/73 ≈ .60/.30/.29 ✓;
white .9 → 0xE6, .85 → 0xD9 ✓; systemGroupedBackground #F2F2F7 ✓;
secondarySystemGroupedBackground #FFFFFF ✓; the nine tints ✓.

### 5. Motion independence (explicitly re-checked)

5.1 No file under `lib/motion/`, `ios/`, `lib/fold/` or `shaders/` is in the
diff; `uAngle` and the uniform table are untouched.
5.2 Nothing in `demo_style.dart`, `demo_content.dart`, `demo_sections.dart`
reads `theta`, `FoldEffect` or `MotionChannel`.
5.3 The only changed widget above the sampler is `main.dart`'s theme/status-bar
wrapper, neither of which feeds the shader.
5.4 The acceptance checklist is taken at 0.0° and H7 explicitly forbids judging
the hinge side. So a later sign correction in 003's device pass cannot
invalidate anything accepted here, and this content is a valid fixed reference
for the 005 blur evidence. As designed.

### 6. Deviations from the *Swift* accepted here (all are plan-sanctioned, none
### are deviations from the plan)

6.1 `maxLines: 1` + ellipsis added on list/tile/chip text that the Swift leaves
unlimited. Accepted: every string fits at 390 pt on-device, so device rendering
is identical; it exists to stop the fixed-width widget-test font from wrapping.
6.2 No 8 pt gap between the hero title's `Expanded` text and the trailing
`arrow.up.right`, where SwiftUI's `Spacer()` guarantees ≥ 8. Accepted: the slack
is ~116 pt, so the gap is never the binding constraint.
6.3 `IntrinsicHeight` + `stretch` in the stat grid where `LazyVGrid` would
centre an item in its row. Accepted: all four tiles have identical intrinsic
heights (one line each, same styles), so the two layouts coincide — and the card
fill is the page colour anyway.
6.4 Divider layout height 0.5 pt where SwiftUI's `Divider()` occupies ≈ 1 pt.
Accepted per decision 12: total content height changes by 1.5 pt out of 868.
6.5 `Spacer(minLength: 0)` dropped. Accepted: the content overflows, so the
Spacer is 0 pt in the original too.
6.6 Material `Icons.directions_walk` / `directions_run` / `psychology` for
`figure.walk` / `figure.run` / `brain.head.profile`. Accepted per decision 7;
flagged for 006's parity sweep as the only non-SF pictograms on the screen.

### 7. Errata in this plan (documentation only, no code change)

7.1 `## Math` §3: "≈ 763 pt of padded safe area" → 739 pt (see 3.7).
7.2 `## Math` §2: "header height ≈ 90.7 pt on the device (SF line boxes 17.4 and
39.6)" → ≈ 91.6 pt (line boxes 17.7 and 40.2) with the 1.1814 em SF line box.
7.3 Acceptance H5: the expected answer is "Morning run" is the last fully
visible row. If the human reports the whole list visible, something is shrinking
the content and that *is* a defect — re-open.

### 8. Proposed `context.md` hunk (for the main session to route; not applied here)

Replace the last gotcha bullet added by 004:

Before:
```
- SwiftUI `Text` boxes come from the font's line height (~1.163 em), not from
  the HIG "line height" column; leave `TextStyle.height` null in the demo.
```

After:
```
- SwiftUI `Text` boxes come from the font's line height, not from the HIG
  "line height" column; leave `TextStyle.height` null in the demo. SF's system
  font metrics are ascent ≈ 0.953 em, descent ≈ 0.228 em (line box ≈ 1.181 em);
  the ascent is what `DemoHeader.textTopInset = 44 − 0.953 × 15 = 29.7` is
  derived from, so do not "round" it away.
```

Reason: the 1.163 em figure is a stale intermediate; the ascent ratio is the
load-bearing number for the one magic constant on this screen, and a later phase
recomputing a text box from 1.163 would be ~1.5 % short.
