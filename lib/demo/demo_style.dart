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
