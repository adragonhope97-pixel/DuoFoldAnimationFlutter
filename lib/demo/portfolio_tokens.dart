import 'package:flutter/widgets.dart';

/// Design tokens for the debojyoticodes.in port (007).
///
/// Colours are the `:root` custom properties of the site's compiled
/// stylesheet converted from HSL to sRGB (see the plan's `## Math`), plus
/// the handful of Tailwind palette entries and one hex literal the markup
/// names directly. Sizes are the **mobile** column of the responsive
/// scale: a 390 pt phone is below the site's `sm` (640 px) breakpoint, so
/// `sm:` and `xl:` variants never apply.
///
/// The screen is pinned to the light theme. Nothing here or in the files
/// that import it reads `Theme.of(context)`.

// --------------------------------------------------------------- family ----

/// `--font-sans: var(--font-geist-sans)`. Six static weights, declared in
/// `pubspec.yaml`.
const String kFont = 'Geist';

// -------------------------------------------------------------- colours ----

/// `--background: 0 0% 100%`.
const Color kBackground = Color(0xFFFFFFFF);

/// `--foreground: 240 10% 3.9%`.
const Color kForeground = Color(0xFF09090B);

/// `--muted-foreground: 0 0% 55%`.
const Color kMutedForeground = Color(0xFF8C8C8C);

/// `text-muted-foreground/80` — the hero tagline.
const Color kMutedForeground80 = Color(0xCC8C8C8C);

/// `--border: 240 5.9% 90%`. The avatar rings and the dock separators.
const Color kBorder = Color(0xFFE4E4E7);

/// `bg-border opacity-20` — the dock separators, over `zinc-900`.
const Color kBorder20 = Color(0x33E4E4E7);

/// `text-neutral-900` — the rotating subheading.
const Color kNeutral900 = Color(0xFF171717);

/// `bg-zinc-600` — the Index pill's percentage badge in light mode.
const Color kZinc600 = Color(0xFF52525B);

/// `bg-zinc-900` — the dock bar in light mode.
const Color kZinc900 = Color(0xFF18181B);

/// `text-[#A0A0A0]` — the education cards' period and subtitle.
const Color kMeta = Color(0xFFA0A0A0);

/// `bg-black` — the Index pill in light mode.
const Color kBlack = Color(0xFF000000);

/// `text-white` on the pill and the dock.
const Color kWhite = Color(0xFFFFFFFF);

/// `bg-white/20` — the scrim behind the expanded Index pill in light mode.
const Color kWhite20 = Color(0x33FFFFFF);

/// `shadow-lg`:
/// `0 10px 15px -3px rgb(0 0 0 / .1), 0 4px 6px -4px rgb(0 0 0 / .1)`.
const List<BoxShadow> kShadowLg = <BoxShadow>[
  BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 10),
    blurRadius: 15,
    spreadRadius: -3,
  ),
  BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 4),
    blurRadius: 6,
    spreadRadius: -4,
  ),
];

// -------------------------------------------------------------- metrics ----

/// `max-w-2xl` on the page wrapper (the wrapper's own `px-6` is inside it).
const double kMaxPageWidth = 672;

/// `px-6` on the page wrapper.
const double kPagePadH = 24;

/// `py-12` on the page wrapper (mobile; `sm:py-24` does not apply).
const double kPagePadV = 48;

/// `pt-24` on `<main>`.
const double kMainPadTop = 96;

/// `pb-16` on `<main>`.
const double kMainPadBottom = 64;

/// `space-y-24` between `<section>`s.
const double kSectionGap = 96;

/// `gap-6` between the hero avatar and the hero text column.
const double kHeroGap = 24;

/// `size-32` — the hero avatar.
const double kHeroAvatar = 128;

/// `space-y-1` inside the hero text column.
const double kHeroLineGap = 4;

/// `space-y-1` + the tagline's own `mt-1`.
const double kHeroTaglineGap = 8;

/// The rotating subheading's line box: `text-xl` is 28 px but the emoji
/// token is `text-2xl align-middle` (32 px), and the taller inline box
/// wins.
const double kRotatorHeight = 32;

/// `.prose :where(p)` margin, `1.25em` of the inherited `text-sm` 14 px.
/// `.prose > :first-child` zeroes the first paragraph's top margin, so
/// this is the gap *between* paragraphs only.
const double kProseGap = 17.5;

/// `gap-y-3` between the education cards (and between the heading and the
/// first card).
const double kCardGap = 12;

/// `size-10` — an education card's logo.
const double kCardLogo = 40;

/// `ml-4` — logo to text column.
const double kCardLogoGap = 16;

/// `gap-x-2` — card title to period.
const double kCardTitleGap = 8;

/// `gap-4` in the Contact section.
const double kContactGap = 16;

/// `h-24` — the fixed top scrim.
const double kTopScrimHeight = 96;

/// `top-12` — the Index pill's distance from the top of the safe area.
const double kPillTop = 48;

/// `h-16` — the fixed bottom scrim behind the dock.
const double kBottomScrimHeight = 64;

/// `mb-4` — the dock's distance from the bottom of the safe area.
const double kDockBottom = 16;

/// `max-h-14` — the dock bar.
const double kDockHeight = 56;

// ----------------------------------------------------------------- type ----
// `height` is (Tailwind line-height)/(font size); see the plan's `## Math`.

/// `text-3xl font-bold tracking-tighter` (mobile; `sm:text-5xl` does not
/// apply). `tracking-tighter` is `-0.05em` = −1.5 px at 30 px.
const TextStyle kHeroHeading = TextStyle(
  fontFamily: kFont,
  fontSize: 30,
  height: 36 / 30,
  fontWeight: FontWeight.w700,
  letterSpacing: -1.5,
  color: kForeground,
);

/// `text-xl font-semibold` on `text-neutral-900`, with the bundle's `mr-1`
/// between tokens expressed as `wordSpacing`.
const TextStyle kHeroRotator = TextStyle(
  fontFamily: kFont,
  fontSize: 20,
  height: 28 / 20,
  fontWeight: FontWeight.w600,
  wordSpacing: 4,
  color: kNeutral900,
);

/// The emoji token of the rotating subheading: `text-2xl align-middle`.
const TextStyle kHeroRotatorEmoji = TextStyle(
  fontFamily: kFont,
  fontSize: 24,
  height: 32 / 24,
  fontWeight: FontWeight.w600,
  color: kNeutral900,
);

/// `text-base text-muted-foreground/80 font-medium`.
const TextStyle kHeroTagline = TextStyle(
  fontFamily: kFont,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w500,
  color: kMutedForeground80,
);

/// `text-xl font-bold font-sans` — every `<h2>`.
const TextStyle kSectionHeading = TextStyle(
  fontFamily: kFont,
  fontSize: 20,
  height: 28 / 20,
  fontWeight: FontWeight.w700,
  color: kForeground,
);

/// `text-sm text-muted-foreground font-medium` — About and Contact body.
const TextStyle kProse = TextStyle(
  fontFamily: kFont,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  color: kMutedForeground,
);

/// `text-foreground underline underline-offset-4` inside the prose.
/// Flutter has no underline offset; the decoration sits on the baseline.
const TextStyle kProseLink = TextStyle(
  fontFamily: kFont,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  color: kForeground,
  decoration: TextDecoration.underline,
  decorationColor: kForeground,
);

/// `text-xs font-medium leading-none` — an education card's title.
const TextStyle kCardTitle = TextStyle(
  fontFamily: kFont,
  fontSize: 12,
  height: 1,
  fontWeight: FontWeight.w500,
  color: kForeground,
);

/// `text-xs text-[#A0A0A0]` — the period and the degree line. No weight
/// class in the markup, so it inherits the document's 400.
const TextStyle kCardMeta = TextStyle(
  fontFamily: kFont,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w400,
  color: kMeta,
);

/// `font-bold` on the pill; no size class, so the document's 16 px.
const TextStyle kPillLabel = TextStyle(
  fontFamily: kFont,
  fontSize: 16,
  height: 24 / 16,
  fontWeight: FontWeight.w700,
  color: kWhite,
);

/// `text-sm font-medium` — the percentage badge.
const TextStyle kPillBadge = TextStyle(
  fontFamily: kFont,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  color: kWhite,
);

/// `text-sm` — an inactive entry of the section-jump menu (`opacity-60` is
/// applied as a widget, not baked into the colour).
const TextStyle kPillMenuItem = TextStyle(
  fontFamily: kFont,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w400,
  color: kWhite,
);

/// `text-sm font-medium opacity-100` — the active entry.
const TextStyle kPillMenuItemActive = TextStyle(
  fontFamily: kFont,
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  color: kWhite,
);
