# 007 portfolio-screen

## Goal

The interface behind the glass is no longer the DuoLikeAnimation "Today"
demo; it is a Flutter port of the mobile rendering of `debojyoticodes.in`,
in the site's light theme, using the site's own Geist type scale and colour
tokens. When this phase is done the phone shows: a white page under a
scrolling column containing the hero (128 px avatar, `Hi! I'm Debojyoti&nbsp;👋`,
a subheading that cycles through four phrases every 3 s, and the tagline),
an About section, an Education section with the two supplied crest images,
and a Contact section; a fixed white top scrim; the black "Index" pill
floating at 48 px from the top with a live scroll-progress ring, a live
percentage badge and a chevron that springs open a 300×300 section-jump
menu with a blur-and-height transition; and a fixed dark dock at the bottom
with six inert glyphs over a white bottom scrim. The fold shader, the
uniform table, `FoldEffect`, the motion bridge and `ControlPanel` are
byte-identical to their state at HEAD. `flutter analyze` is clean,
`dart format --set-exit-if-changed` exits 0, `flutter test` passes and
`flutter build ios --debug --no-codesign` succeeds.

## Decisions

1. **Light theme, mobile column.** A phone is below the site's `sm`
   breakpoint (640 px), so every responsive class resolves to its mobile
   value: `text-3xl` not `sm:text-5xl` for the heading, `text-xl` not
   `sm:text-2xl` for the subheading, `text-xs` not `sm:text-sm` in the
   education cards, `whitespace-normal` not `sm:whitespace-nowrap`,
   `py-12` not `sm:py-24`. Light theme because the shipped default is
   `system` → light, because `context.md` pins the demo screen to a light
   appearance, and because the pill (`bg-black text-white`) and dock
   (`bg-zinc-900`) only read as designed against a white page.
2. **Tokens, not literals.** All colours, metrics and text styles live in
   one new file `lib/demo/portfolio_tokens.dart`. The user asked for the
   hierarchy and colour scheme to be followed exactly; a token set makes
   that checkable. Values are computed from `:root` in `scratchpad/site/app.css`
   (see `## Math`), not eyeballed.
3. **The dock is inert. The Index pill is live.** `AnimatedSampler`'s
   render object is a plain `RenderProxyBox`
   (`flutter_shaders-0.1.3/lib/src/animated_sampler.dart:114`), so hit
   testing passes through to the child in *unwarped* local coordinates
   while the shader displaces the *image*. A tap therefore lands where the
   pixel would have been at θ = 0, off by the full reprojection
   displacement when tilted. The dock's six actions all open external URLs
   or a PDF, which is meaningless inside a shader demo, so they get no
   gesture recogniser at all and the whole dock is wrapped in
   `IgnorePointer`. The pill is the one control whose state changes the
   composition, so it must be exercisable; it is a 190×40 target near the
   top centre and the user can tap it with the manual slider at 0. This is
   stated on the widget's doc comment so nobody "fixes" the dock later.
4. **Scrolling is allowed, and costs nothing new.** The sampler's render
   object is `isRepaintBoundary == true` while enabled, and its `paint`
   calls `toImageSync` — one full-screen offscreen per repaint. That
   already happens on every Core Motion sample (~60 Hz) because θ changes
   every frame. Scrolling adds the child's own layout+paint, which is a
   `Column` of `Text` plus three small images: cheap relative to the 32-tap
   blur that already runs over ~2.96 M physical fragments. Physics is
   `BouncingScrollPhysics` (iOS default); the site's Lenis smooth-scroll
   inertia model is not portable and is not reproduced.
5. **Four sections, not seven.** The bundle's section list is
   `[hero, about, education, experience, skills, projects, contact]`, but
   experience and projects need 11 `.webp` logo/preview files that are not
   in `assets/images/` (only `me_avatar`, `college`, `school` were
   supplied), and skills is not in the screenshot's viewport. Rather than
   ship an Index menu with four dead jump targets, the menu lists exactly
   the four ported sections. The omitted three are named in
   `## Out of scope` with the assets they would need.
6. **Entrance animations are omitted.** Every hero and section child is
   wrapped in a `BlurFade` (`opacity 0→1, blur 6–8 px→0, translateY 6–8→0`,
   staggered `delay: .04…`). It plays once at t=0 and the fold effect is
   judged at rest; reproducing it means an `ImageFiltered` Gaussian layer
   per block inside a subtree that is rasterised to an offscreen every
   frame. Declared, not smuggled in.
7. **The rotating subheading is reproduced at word granularity, not glyph
   granularity.** The bundle animates the container (`y: 20→0→-20`, spring
   `stiffness 300, damping 30, mass 1`) *and* every word *and* every
   character, each with its own `blur(8px)` filter and `delay: .1*i`.
   Per-glyph `ImageFiltered` layers inside the rasterised subtree are the
   same objection as decision 6. The container transition is reproduced
   (slide + fade, 350 ms, `Curves.easeOutCubic` standing in for
   ζ = 30/(2√300) = 0.866); the per-word blur stagger is not.
8. **The emoji token keeps its own size.** The bundle renders any
   `\p{Extended_Pictographic}` token in a `text-2xl align-middle` span
   while the words are `text-xl`, and puts `mr-1` (4 px) after each token.
   Reproduced as a 24 px `TextSpan` for the emoji and `wordSpacing: 4` on
   the 20 px style.
9. **NBSP, not a line break.** The heading string is
   `Hi! I'm Debojyoti 👋` verbatim; the emoji wraps with "Debojyoti"
   because U+00A0 is non-breaking and the hero text column is only
   ~190 logical px wide on a 390 px phone. No `\n`, no `Wrap`.
10. **`SafeArea` wraps the whole portfolio.** The site's fixed offsets
    (`top-12` for the pill, `mb-4` for the dock, `py-12` for the page) are
    used verbatim but measured from inside the safe area, so the pill
    clears the Dynamic Island and the dock clears the home indicator. The
    white page colour still fills the full screen behind the safe area.
11. **`TextStyle.height` is set, unlike the old demo.** `context.md`'s
    gotcha "leave `TextStyle.height` null in the demo" derives from SwiftUI
    `Text` taking its box from the font's line height. This screen is a
    port of CSS, where `line-height` is an explicit part of the type
    scale, so every style sets `height` = (Tailwind line-height)/(font
    size). See `## Math` for the correction and the proposed `context.md`
    hunk.
12. **File naming.** `lib/demo/demo_content.dart` keeps its path and its
    `DemoContent` class name so `lib/main.dart` and
    `test/widget_test.dart` do not have to change. `demo_style.dart` is
    trimmed to the four constants `control_panel.dart` still imports;
    everything else in it described the deleted Today screen.
13. **Dock glyphs are the site's own SVG path data**, parsed at runtime by
    a ~110-line subset parser in `lib/demo/svg_path.dart` (M m L l H h V v
    C c A a Z z — the only commands these seven paths use, verified by
    scanning them). No new package: `flutter_svg`/`path_drawing` would
    violate the phase scope, and `dart:ui`'s `Path.arcToPoint` already
    takes SVG endpoint-arc parameters, so no arc→cubic conversion is
    needed.
14. **`WordRotate.cyclingEnabled` static flag.** A `Timer.periodic`
    schedules a frame forever, so `WidgetTester.pumpAndSettle` never
    settles. `test/widget_test.dart:160` already calls `pumpAndSettle`
    with `DemoContent` mounted. The flag defaults to `true` and both test
    files set it to `false`; that is a two-line hunk in `widget_test.dart`
    and is the only edit outside `lib/demo/`, `pubspec.yaml` and
    `test/demo_content_test.dart`.
15. **`"CBSE     Class 1 - Class 12"` is normalised to one space.** HTML
    collapses the run of five spaces in the bundle's data; Flutter does
    not. The port matches what the browser renders.

### Proposed `context.md` hunks (the main session routes these; do not edit
`context.md` in this phase)

    - The demo screen is pinned to the iOS **light** appearance (004). It hard-codes
    + The demo screen is pinned to the **light** appearance (004/007). It hard-codes

    - `lib/demo/demo_content.dart  # DemoContentView port: root, header, chips, hero`
    - `lib/demo/demo_sections.dart # DemoContentView port: stat grid, Recent list`
    - `lib/demo/demo_style.dart    # iOS light system colours + text styles`
    + `lib/demo/demo_content.dart      # portfolio root: page, scroll, scrims, pill, dock`
    + `lib/demo/demo_sections.dart     # About / Education / Contact`
    + `lib/demo/portfolio_hero.dart    # avatar, NBSP heading, WordRotate, tagline`
    + `lib/demo/portfolio_index_pill.dart`
    + `lib/demo/portfolio_dock.dart`
    + `lib/demo/portfolio_tokens.dart  # debojyoticodes.in colour/type/metric tokens`
    + `lib/demo/portfolio_data.dart    # strings quoted from the site bundle`
    + `lib/demo/portfolio_icons.dart   # the dock's SVG path data`
    + `lib/demo/svg_path.dart          # SVG path subset parser`
    + `lib/demo/demo_style.dart        # iOS light colours the control panel still uses`

    + - The demo content since 007 is a port of debojyoticodes.in, not
    +   `DemoContentView.swift`. Its type scale comes from CSS, so its
    +   `TextStyle`s set `height` explicitly (Tailwind line-height / font size);
    +   the "leave `height` null" rule above applies only to `control_panel.dart`,
    +   which is still SwiftUI-derived.
    + - `AnimatedSampler`'s render object is a `RenderProxyBox`: hit testing is
    +   *not* reprojected. Taps land where the pixel would be at θ = 0. Only the
    +   Index pill is interactive; the dock is `IgnorePointer`.

## Files

### 1. `pubspec.yaml` — edit

Before (the commented asset block and the commented font block at the end
of the `flutter:` section):

```yaml
  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg

  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images

  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
  #   - family: Trajan Pro
  #     fonts:
  #       - asset: fonts/TrajanPro.ttf
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package
```

After:

```yaml
  # The portfolio screen's images (007). Declared as a directory: every file
  # in it is bundled, and `test/demo_content_test.dart` loads the fonts
  # through `rootBundle`, which needs them in the manifest.
  assets:
    - assets/images/

  # Geist, the site's `--font-geist-sans`. All six static weights the user
  # supplied are declared with their real `weight:` so FontWeight.w500 and
  # w600 resolve to files instead of being synthesised from the 400.
  fonts:
    - family: Geist
      fonts:
        - asset: assets/fonts/Geist-300.ttf
          weight: 300
        - asset: assets/fonts/Geist-400.ttf
          weight: 400
        - asset: assets/fonts/Geist-500.ttf
          weight: 500
        - asset: assets/fonts/Geist-600.ttf
          weight: 600
        - asset: assets/fonts/Geist-700.ttf
          weight: 700
        - asset: assets/fonts/Geist-800.ttf
          weight: 800
```

The `shaders:` block above it is untouched.

### 2. `lib/demo/demo_style.dart` — full replacement

```dart
import 'package:flutter/widgets.dart';

/// The light-appearance iOS colours that `control_panel.dart` still asks
/// for. Everything else this file used to hold described the
/// `DemoContentView.swift` port, which 007 replaced with the
/// debojyoticodes.in screen; those tokens now live in
/// `portfolio_tokens.dart`.
///
/// The control panel is chrome around the effect, not part of the interface
/// behind the glass, so it stays SwiftUI-derived and keeps these literals.

/// `Color.accentColor` — the app tint, which defaults to systemBlue.
const Color kAccentColor = Color(0xFF007AFF);

/// `.systemGreen` — the manual-tilt toggle's on colour.
const Color kSystemGreen = Color(0xFF34C759);

/// `.primary` / `UIColor.label`.
const Color kLabel = Color(0xFF000000);

/// `.tertiary` / `UIColor.tertiaryLabel` (#3C3C43 at 30 %).
const Color kTertiaryLabel = Color(0x4D3C3C43);
```

### 3. `lib/demo/portfolio_tokens.dart` — new

```dart
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
```

### 4. `lib/demo/portfolio_data.dart` — new

```dart
/// Every string on the portfolio screen, quoted from the site's client
/// bundle (`scratchpad/hunt/d69ce6a8de1a752c.js`, the `ee` object and the
/// `de` section list) rather than retyped from the rendered page.

/// ` ` is the bundle's non-breaking space: it binds the waving hand to
/// the name so the emoji wraps as one unit with "Debojyoti" in a narrow
/// column. Do not replace it with a newline or a normal space.
const String kHeroHeadingText = "Hi! I'm Debojyoti 👋";

/// `ee.description`.
const String kHeroTaglineText =
    'I build beautiful mobile apps with design, code, and just enough '
    'caffeine. ☕️';

/// `rg` — the four phrases of the rotating subheading, split into the word
/// run and the trailing emoji token because the bundle renders any
/// `\p{Extended_Pictographic}` token one step larger.
const List<(String, String)> kRotatingWords = <(String, String)>[
  ('Student', '📚'),
  ('Flutter App Developer', '💻'),
  ('UI/UX Designer', '🎨'),
  ('Gym Rat', '🏋️'),
];

/// `rm`'s `duration: 3e3`.
const Duration kRotateInterval = Duration(milliseconds: 3000);

/// `ee.summary`, split on its two blank lines into `<p>` elements.
const List<String> kAboutParagraphs = <String>[
  "I'm a Flutter developer and product builder who enjoys turning ideas "
      'into beautiful, usable, slightly over-engineered mobile apps. I spend '
      'most of my time thinking about how things should feel, animations, '
      'transitions, haptics, tiny details that make software feel alive.',
  "I've shipped multiple consumer apps used by thousands of people, "
      "including Radpapers (9,500+ downloads), and I'm currently building "
      'products like SnekID AI, Cartoonify AI, Span, and CareSync, from '
      'AI-powered utilities to calm, design-first tools.',
  'I like working where design meets engineering, obsessing over both the '
      'pixels and the code behind them.',
];

/// One entry of `ee.education`.
class EducationEntry {
  const EducationEntry({
    required this.logoAsset,
    required this.school,
    required this.degree,
    required this.period,
  });

  final String logoAsset;
  final String school;
  final String degree;
  final String period;
}

/// `ee.education`. The bundle's second degree string has a run of five
/// spaces, which HTML collapses; it is normalised here to match what the
/// browser renders.
const List<EducationEntry> kEducation = <EducationEntry>[
  EducationEntry(
    logoAsset: 'assets/images/college.webp',
    school: 'Techno International New Town, Kolkata',
    degree: 'Bachelor of Technology in Computer Science',
    period: '2022 - 2026',
  ),
  EducationEntry(
    logoAsset: 'assets/images/school.webp',
    school: 'Amrita Vidyalayam, Durgapur',
    degree: 'CBSE Class 1 - Class 12',
    period: '2010 - 2022',
  ),
];

const String kAvatarAsset = 'assets/images/me_avatar.webp';

/// The Contact paragraph, in the four runs the markup splits it into: two
/// plain runs separated by a `<br/>`, then two links.
const String kContactLine1 = 'Want to get in touch or hire me for a project?';
const String kContactLine2 = 'Just shoot me a DM on ';
const String kContactLinkX = 'X';
const String kContactBetween = ' or ';
const String kContactLinkTelegram = 'Telegram';

/// One entry of `de`, the Index pill's section list.
class PortfolioSection {
  const PortfolioSection(this.id, this.title);

  final String id;
  final String title;
}

/// `de`, filtered to the sections this port ships. The bundle also lists
/// `experience`, `skills` and `projects`; they need eleven `.webp` files
/// that are not in `assets/images/`, and an Index entry that jumps nowhere
/// is worse than no entry (plan 007, decision 5).
const List<PortfolioSection> kSections = <PortfolioSection>[
  PortfolioSection('hero', 'Introduction'),
  PortfolioSection('about', 'About'),
  PortfolioSection('education', 'Education'),
  PortfolioSection('contact', 'Contact'),
];
```

### 5. `lib/demo/svg_path.dart` — new

```dart
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
```

### 6. `lib/demo/portfolio_icons.dart` — new

```dart
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
  const SvgIcon(this.data, {super.key, required this.size, required this.color});

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
```

### 7. `lib/demo/portfolio_dock.dart` — new

```dart
import 'package:flutter/widgets.dart';

import 'portfolio_icons.dart';
import 'portfolio_tokens.dart';

/// The site's bottom dock, plus the white scrim it sits on.
///
/// **Inert on purpose.** All six actions open an external URL or a PDF,
/// which means nothing inside a shader demo, and `AnimatedSampler` is a
/// `RenderProxyBox`: it displaces the *image* but not the hit-test
/// geometry, so under tilt a tap lands wherever the pixel would have been
/// at θ = 0. The whole dock is therefore wrapped in [IgnorePointer]. Do not
/// add gestures here (plan 007, decision 3).
///
/// Markup: an `h-16` scrim masked `linear-gradient(to top, black,
/// transparent)`, and a `w-max p-2 px-1 rounded-full bg-zinc-900 border
/// border-white/20` bar `mb-4` from the bottom, holding six `40×40` slots
/// with `1.125rem` glyphs and two `w-[1px] opacity-20` separators.
class PortfolioDock extends StatelessWidget {
  const PortfolioDock({super.key});

  /// `size-[1.125rem]`.
  static const double glyph = 18;

  /// The dock slot, `style="width:40px" aspect-square`.
  static const double slot = 40;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: kBottomScrimHeight + kDockBottom + kDockHeight,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: kBottomScrimHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00FFFFFF), kBackground],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: kDockBottom,
              child: Center(child: _bar()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar() {
    return Container(
      height: kDockHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: kZinc900,
        borderRadius: BorderRadius.circular(kDockHeight / 2),
        border: Border.all(color: kWhite20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          _Slot(kIconDocument),
          _Separator(),
          _Slot(kIconGithub),
          _Slot(kIconLinkedIn),
          _Slot(kIconX),
          _Slot(kIconTelegram),
          _Separator(),
          _Slot(kIconSun),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot(this.data);

  final String data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PortfolioDock.slot,
      height: PortfolioDock.slot,
      child: Center(
        child: SvgIcon(data, size: PortfolioDock.glyph, color: kWhite),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: PortfolioDock.slot,
      child: ColoredBox(color: kBorder20),
    );
  }
}
```

### 8. `lib/demo/portfolio_index_pill.dart` — new

```dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'portfolio_data.dart';
import 'portfolio_tokens.dart';

/// The site's floating "Index" control: a scroll-progress ring, a
/// percentage badge and a chevron that springs the pill open into a
/// section-jump menu.
///
/// **The one live control on this screen.** See plan 007, decision 3: hit
/// testing under `AnimatedSampler` is not reprojected, so taps are accurate
/// only near θ = 0.
///
/// Geometry and timing, quoted from the bundle:
///
/// * pill `collapsed {width:190, height:40, borderRadius:24, padding:0}`,
///   `expanded {width:300, height:300, borderRadius:28, padding:12}`,
///   spring `{bounce:.35, duration:.6, mass:1.1}`;
/// * ring: `w-6 h-6` svg, `-rotate-90`, `cx=12 cy=12 r=10 strokeWidth=4`,
///   track `opacity-30`, progress `strokeLinecap="round"`,
///   `strokeDasharray="${o/100*62.83} 62.83"`, `transition-all
///   duration-300`;
/// * header `w-full px-1.5 h-10 flex items-center justify-between`, left
///   group `flex items-center gap-2`, chevron `w-4 h-4` with
///   `animate:{rotate: 180*!!a}`;
/// * badge `px-4 py-1 rounded-full text-sm font-medium bg-zinc-600`;
/// * panel `collapsed {opacity:0, filter:"blur(16px)", height:0,
///   duration:.6, ease:[.4,0,.2,1]}`, `expanded {opacity:1,
///   filter:"blur(0px)", height:"auto", duration:.45, ease:[.5,0,.4,1]}`,
///   list `px-4 pb-4 space-y-2`;
/// * scrim `fixed inset-0 bg-white/20` with `backdropFilter: blur(8px)`.
class IndexPill extends StatefulWidget {
  const IndexPill({
    super.key,
    required this.sections,
    required this.activeSectionId,
    required this.progressPercent,
    required this.onSectionTap,
  });

  final List<PortfolioSection> sections;
  final String activeSectionId;

  /// 0…100, `Math.min(Math.round(window.scrollY/t*100),100)`.
  final int progressPercent;
  final ValueChanged<String> onSectionTap;

  static const double collapsedWidth = 190;
  static const double collapsedHeight = 40;
  static const double expandedSize = 300;

  @override
  State<IndexPill> createState() => _IndexPillState();
}

class _IndexPillState extends State<IndexPill> with TickerProviderStateMixin {
  /// Framer's `{type:"spring", duration:.6, bounce:.35, mass:1.1}`: when a
  /// duration is given it wins over stiffness/damping. ζ = 1 − bounce and
  /// ω = 2π/duration, so k = mω² and c = 2ζ√(km). See `## Math`.
  static const SpringDescription _spring = SpringDescription(
    mass: 1.1,
    stiffness: 120.63,
    damping: 15.98,
  );

  late final AnimationController _box = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    reverseDuration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _panelCurve = CurvedAnimation(
    parent: _panel,
    curve: const Cubic(0.5, 0, 0.4, 1),
    reverseCurve: const Cubic(0.4, 0, 0.2, 1),
  );

  bool _expanded = false;

  @override
  void dispose() {
    _box.dispose();
    _panel.dispose();
    super.dispose();
  }

  void _toggle() => _setExpanded(!_expanded);

  void _setExpanded(bool value) {
    if (value == _expanded) {
      return;
    }
    setState(() => _expanded = value);
    _box.animateWith(
      SpringSimulation(_spring, _box.value, value ? 1 : 0, _box.velocity),
    );
    if (value) {
      _panel.forward();
    } else {
      _panel.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _scrim()),
        Positioned(
          top: kPillTop,
          left: 0,
          right: 0,
          child: Center(child: _pill()),
        ),
      ],
    );
  }

  Widget _scrim() {
    return AnimatedBuilder(
      animation: _panelCurve,
      builder: (BuildContext context, Widget? child) {
        final double v = _panelCurve.value;
        if (v <= 0) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          ignoring: !_expanded,
          child: Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setExpanded(false),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8 * v, sigmaY: 8 * v),
                child: const ColoredBox(color: kWhite20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pill() {
    return AnimatedBuilder(
      animation: _box,
      builder: (BuildContext context, Widget? child) {
        final double t = _box.value;
        return Container(
          width: ui.lerpDouble(
            IndexPill.collapsedWidth,
            IndexPill.expandedSize,
            t,
          ),
          height: ui.lerpDouble(
            IndexPill.collapsedHeight,
            IndexPill.expandedSize,
            t,
          ),
          padding: EdgeInsets.all((12 * t).clamp(0.0, 12.0)),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: kBlack,
            borderRadius: BorderRadius.circular(ui.lerpDouble(24, 28, t)!),
            boxShadow: kShadowLg,
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[_header(), Flexible(child: _panelBody())],
      ),
    );
  }

  Widget _header() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      end: widget.progressPercent / 100,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: const Cubic(0.4, 0, 0.2, 1),
                    builder: (BuildContext context, double v, Widget? _) {
                      return SizedBox(
                        width: 24,
                        height: 24,
                        child: CustomPaint(painter: _RingPainter(v)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('Index', style: kPillLabel),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _box,
                    builder: (BuildContext context, Widget? child) {
                      return Transform.rotate(
                        angle: _box.value * math.pi,
                        child: child,
                      );
                    },
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CustomPaint(painter: _ChevronPainter()),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: const BoxDecoration(
                  color: kZinc600,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text('${widget.progressPercent}%', style: kPillBadge),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelBody() {
    return AnimatedBuilder(
      animation: _panelCurve,
      builder: (BuildContext context, Widget? child) {
        final double v = _panelCurve.value.clamp(0.0, 1.0);
        if (v <= 0) {
          return const SizedBox.shrink();
        }
        Widget body = Opacity(opacity: v, child: child);
        final double sigma = (1 - v) * 16;
        if (sigma > 0.01) {
          body = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: body,
          );
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            child: body,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < widget.sections.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _MenuItem(
                section: widget.sections[i],
                active: widget.sections[i].id == widget.activeSectionId,
                onTap: () {
                  _setExpanded(false);
                  widget.onSectionTap(widget.sections[i].id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.section,
    required this.active,
    required this.onTap,
  });

  final PortfolioSection section;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Opacity(
          opacity: active ? 1 : 0.6,
          child: Text(
            section.title,
            textAlign: TextAlign.left,
            style: active ? kPillMenuItemActive : kPillMenuItem,
          ),
        ),
      ),
    );
  }
}

/// `<svg class="-rotate-90">` with two `r=10 strokeWidth=4` circles.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect oval = Rect.fromCircle(
      center: const Offset(12, 12),
      radius: 10,
    );
    canvas.drawCircle(
      const Offset(12, 12),
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x4DFFFFFF), // white at opacity-30
    );
    if (progress > 0.001) {
      canvas.drawArc(
        oval,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = kWhite,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// lucide `ChevronDown`, `d="m6 9 6 6 6-6"` on a 24 grid, `stroke-width:2`,
/// round cap and join. Stroked, so it does not go through
/// `parseSvgPath`, which only fills.
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
```

### 9. `lib/demo/portfolio_hero.dart` — new

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'portfolio_data.dart';
import 'portfolio_tokens.dart';

/// `<section id="hero">`: `gap-6 flex items-start` — a `size-32 border`
/// avatar and a `flex-1 space-y-1` text column.
class PortfolioHero extends StatelessWidget {
  const PortfolioHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: kHeroAvatar,
          height: kHeroAvatar,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder),
          ),
          child: Image.asset(kAvatarAsset, fit: BoxFit.cover),
        ),
        const SizedBox(width: kHeroGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              // The U+00A0 in kHeroHeadingText is what keeps 👋 attached to
              // "Debojyoti" when this ~190 px column wraps the line.
              Text(kHeroHeadingText, style: kHeroHeading),
              SizedBox(height: kHeroLineGap),
              WordRotate(),
              SizedBox(height: kHeroTaglineGap),
              Text(kHeroTaglineText, style: kHeroTagline),
            ],
          ),
        ),
      ],
    );
  }
}

/// The bundle's `rm({words: rg, duration: 3e3})`: the subheading is not a
/// static string, it cycles through four phrases on a 3 s interval. The
/// container transition is reproduced (enter `y:20 → 0` with a fade, exit
/// `0 → y:-20` with a fade); the per-word and per-character `blur(8px)`
/// stagger is not (plan 007, decision 7).
class WordRotate extends StatefulWidget {
  const WordRotate({super.key});

  /// A `Timer.periodic` schedules a frame forever, so
  /// `WidgetTester.pumpAndSettle` never settles. Tests set this to false.
  static bool cyclingEnabled = true;

  @override
  State<WordRotate> createState() => _WordRotateState();
}

class _WordRotateState extends State<WordRotate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..value = 1;
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;
  int _index = 0;
  int _previous = 0;

  @override
  void initState() {
    super.initState();
    if (WordRotate.cyclingEnabled) {
      _timer = Timer.periodic(kRotateInterval, (Timer _) => _advance());
    }
  }

  void _advance() {
    setState(() {
      _previous = _index;
      _index = (_index + 1) % kRotatingWords.length;
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _phrase(int i) {
    final (String words, String emoji) = kRotatingWords[i];
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '$words '),
          TextSpan(text: emoji, style: kHeroRotatorEmoji),
        ],
      ),
      style: kHeroRotator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kRotatorHeight,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (BuildContext context, Widget? _) {
          final double t = _curve.value;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (t < 1 && _previous != _index)
                Positioned(
                  left: 0,
                  top: -20 * t,
                  child: Opacity(opacity: 1 - t, child: _phrase(_previous)),
                ),
              Positioned(
                left: 0,
                top: 20 * (1 - t),
                child: Opacity(opacity: t, child: _phrase(_index)),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

### 10. `lib/demo/demo_sections.dart` — full replacement

```dart
import 'package:flutter/widgets.dart';

import 'portfolio_data.dart';
import 'portfolio_tokens.dart';

/// `<section id="about">`: an `<h2>` with no gap under it (the `.prose`
/// rule `> :first-child { margin-top: 0 }` eats the first paragraph's
/// margin), then `<p>`s `1.25em` apart.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('About', style: kSectionHeading),
        for (int i = 0; i < kAboutParagraphs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: kProseGap),
          Text(kAboutParagraphs[i], style: kProse),
        ],
      ],
    );
  }
}

/// `<section id="education">`: `flex min-h-0 flex-col gap-y-3`.
class EducationSection extends StatelessWidget {
  const EducationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Education', style: kSectionHeading),
        for (final EducationEntry e in kEducation) ...<Widget>[
          const SizedBox(height: kCardGap),
          EducationCard(entry: e),
        ],
      ],
    );
  }
}

/// `ResumeCard`: a `size-10 border m-auto object-contain` logo, then a
/// `flex-grow ml-4` column of a title/period row and the degree line.
///
/// The `ChevronRight` in the markup is `opacity-0` until `group-hover`,
/// which never happens on a touch screen, so it is not drawn.
class EducationCard extends StatelessWidget {
  const EducationCard({super.key, required this.entry});

  final EducationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: kCardLogo,
          height: kCardLogo,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kBorder),
          ),
          child: Image.asset(entry.logoAsset, fit: BoxFit.contain),
        ),
        const SizedBox(width: kCardLogoGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Flexible(child: Text(entry.school, style: kCardTitle)),
                  const SizedBox(width: kCardTitleGap),
                  Text(
                    entry.period,
                    style: kCardMeta,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              Text(entry.degree, style: kCardMeta),
            ],
          ),
        ),
      ],
    );
  }
}

/// `<section id="contact">`: `flex flex-col items-start gap-4`. The `<br/>`
/// after the first question is a hard break, not a wrap.
class ContactSection extends StatelessWidget {
  const ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Contact', style: kSectionHeading),
        const SizedBox(height: kContactGap),
        Text.rich(
          const TextSpan(
            children: <InlineSpan>[
              TextSpan(text: '$kContactLine1\n$kContactLine2'),
              TextSpan(text: kContactLinkX, style: kProseLink),
              TextSpan(text: kContactBetween),
              TextSpan(text: kContactLinkTelegram, style: kProseLink),
            ],
          ),
          style: kProse,
        ),
      ],
    );
  }
}
```

### 11. `lib/demo/demo_content.dart` — full replacement

```dart
import 'package:flutter/widgets.dart';

import 'demo_sections.dart';
import 'portfolio_data.dart';
import 'portfolio_dock.dart';
import 'portfolio_hero.dart';
import 'portfolio_index_pill.dart';
import 'portfolio_tokens.dart';

/// The interface the fold effect looks at: a port of the mobile rendering
/// of debojyoticodes.in (007), replacing the `DemoContentView.swift` port
/// that stood here from 004.
///
/// Pure Flutter on purpose: platform views are not rasterised into the
/// `AnimatedSampler`'s image (context.md → gotchas).
///
/// Pinned to the site's light theme: every colour, size and text style is a
/// literal from `portfolio_tokens.dart` and nothing here reads
/// `Theme.of(context)`.
///
/// Layout, from the site's markup:
/// `<div class="max-w-2xl mx-auto py-12 px-6">` wrapping
/// `<main class="flex flex-col space-y-24 pt-24 pb-16">`, with three fixed
/// overlays: the `h-24` top scrim, the Index pill at `top-12`, and the dock.
/// The padding lives inside the scrolling [Column] rather than on the
/// [SingleChildScrollView] so that a section's offset within that column is
/// exactly the scroll offset that brings it to the top of the viewport.
class DemoContent extends StatefulWidget {
  const DemoContent({super.key});

  /// `t.getBoundingClientRect().top - 100`: the site parks a jump target
  /// 100 px below the viewport top, and picks the active section by the
  /// same measure.
  static const double anchorInset = 100;

  @override
  State<DemoContent> createState() => _DemoContentState();
}

class _DemoContentState extends State<DemoContent> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _columnKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{
    for (final PortfolioSection s in kSections) s.id: GlobalKey(),
  };

  int _progress = 0;
  String _active = kSections.first.id;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// A section's top edge measured from the top of the scrolling column,
  /// i.e. the scroll offset that would put it at the viewport top.
  double? _sectionOffset(String id) {
    final RenderObject? column = _columnKey.currentContext?.findRenderObject();
    final RenderObject? section = _sectionKeys[id]?.currentContext
        ?.findRenderObject();
    if (column is! RenderBox || section is! RenderBox || !section.hasSize) {
      return null;
    }
    return section.localToGlobal(Offset.zero, ancestor: column).dy;
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final double max = _scroll.position.maxScrollExtent;
    final int progress = max <= 0
        ? 0
        : (_scroll.offset / max * 100).round().clamp(0, 100);

    String active = _active;
    double best = double.infinity;
    for (final PortfolioSection s in kSections) {
      final double? top = _sectionOffset(s.id);
      if (top == null) {
        continue;
      }
      final double d =
          (top - _scroll.offset - DemoContent.anchorInset).abs();
      if (d < best) {
        best = d;
        active = s.id;
      }
    }

    if (progress != _progress || active != _active) {
      setState(() {
        _progress = progress;
        _active = active;
      });
    }
  }

  /// Lenis `scrollTo(top - 100, {duration: 1.5, easing: 1.001 - 2^(-10t)})`.
  /// That easing is `Curves.easeOutExpo`.
  void _jumpTo(String id) {
    final double? top = _sectionOffset(id);
    if (top == null || !_scroll.hasClients) {
      return;
    }
    _scroll.animateTo(
      (top - DemoContent.anchorInset).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutExpo,
    );
  }

  Widget _anchored(String id, Widget child) =>
      KeyedSubtree(key: _sectionKeys[id], child: child);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBackground,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _scrollView()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kTopScrimHeight,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        kBackground,
                        Color(0xB3FFFFFF), // via-background/70
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PortfolioDock(),
            ),
            Positioned.fill(
              child: IndexPill(
                sections: kSections,
                activeSectionId: _active,
                progressPercent: _progress,
                onSectionTap: _jumpTo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrollView() {
    return SingleChildScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxPageWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPagePadH),
            child: Column(
              key: _columnKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: kPagePadV + kMainPadTop),
                _anchored('hero', const PortfolioHero()),
                const SizedBox(height: kSectionGap),
                _anchored('about', const AboutSection()),
                const SizedBox(height: kSectionGap),
                _anchored('education', const EducationSection()),
                const SizedBox(height: kSectionGap),
                _anchored('contact', const ContactSection()),
                const SizedBox(height: kMainPadBottom + kPagePadV),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### 12. `test/widget_test.dart` — edit

Before (the import block's last project import and the first line of the
top-level `void main() {`):

```dart
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
```

After:

```dart
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_hero.dart';
```

Before:

```dart
void main() {
```

After:

```dart
void main() {
  // The hero's rotating subheading runs a Timer.periodic, which schedules a
  // frame forever and stops `pumpAndSettle` from ever settling.
  WordRotate.cyclingEnabled = false;
```

Nothing else in this file changes. (If `void main() {` is not the exact
first line of the top-level `main`, insert the two comment lines and the
assignment as the first statements of that function and leave the rest
untouched.)

### 13. `test/demo_content_test.dart` — full replacement

```dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_sections.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_dock.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_hero.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_icons.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_index_pill.dart';
import 'package:iphoneduo_animation_flutter/demo/svg_path.dart';

/// The portfolio screen (007). The old assertions here described the
/// `DemoContentView.swift` port and were deleted with it.
///
/// The real Geist faces are loaded so that widths are the shipped ones:
/// without them every glyph is the test font's em square and the 190 pt
/// Index pill overflows in the test and only in the test.
Future<void> _loadGeist() async {
  final FontLoader loader = FontLoader('Geist');
  for (final int weight in <int>[300, 400, 500, 600, 700, 800]) {
    loader.addFont(rootBundle.load('assets/fonts/Geist-$weight.ttf'));
  }
  await loader.load();
}

Widget _fixture() {
  return const Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: Size(390, 844)),
      child: SizedBox(width: 390, height: 844, child: DemoContent()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WordRotate.cyclingEnabled = false;

  setUpAll(_loadGeist);

  testWidgets('renders the hero, the sections and the chrome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_fixture());
    await tester.pump();

    // The NBSP is load-bearing: it binds the emoji to the name.
    expect(find.text("Hi! I'm Debojyoti 👋"), findsOneWidget);
    expect(
      find.text(
        'I build beautiful mobile apps with design, code, and just enough '
        'caffeine. ☕️',
      ),
      findsOneWidget,
    );
    expect(find.byType(WordRotate), findsOneWidget);

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Education'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
    expect(find.byType(EducationCard), findsNWidgets(2));
    expect(
      find.text('Techno International New Town, Kolkata'),
      findsOneWidget,
    );
    expect(find.text('2010 - 2022'), findsOneWidget);

    expect(find.byType(IndexPill), findsOneWidget);
    expect(find.text('Index'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    expect(find.byType(PortfolioDock), findsOneWidget);
    expect(find.byType(SvgIcon), findsNWidgets(6));
  });

  testWidgets('scrolling moves the progress percentage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_fixture());
    await tester.pump();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('the Index chevron expands the section menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_fixture());
    await tester.pump();

    // Collapsed: the menu entries are not built.
    expect(find.text('Introduction'), findsNothing);

    await tester.tap(find.text('Index'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('About'), findsNWidgets(2)); // heading + menu entry
  });

  test('the svg path parser handles the dock glyphs', () {
    for (final String d in <String>[
      kIconDocument,
      kIconGithub,
      kIconLinkedIn,
      kIconX,
      kIconTelegram,
      kIconSun,
    ]) {
      final Path p = parseSvgPath(d);
      final Rect b = p.getBounds();
      expect(b.isEmpty, isFalse);
      expect(b.left, greaterThanOrEqualTo(-1));
      expect(b.top, greaterThanOrEqualTo(-1));
      expect(b.right, lessThanOrEqualTo(25));
      expect(b.bottom, lessThanOrEqualTo(25));
    }
  });
}
```

## Math

Conventions restated: everything on this screen is in **logical pixels**,
which is what CSS pixels map to one-for-one at the site's mobile breakpoint.
The fold shader's conventions (`uSize`, θ, hinge at `xh = θ > 0 ? W : 0`,
the reference math block in `context.md`) are **untouched by this phase**;
no uniform is added, removed or reordered, and the uniform table stands as
written.

1. **HSL → sRGB for the CSS custom properties.** `hsl(h, s%, l%)` with
   `C = (1 − |2L − 1|)·S`, `X = C(1 − |((h/60) mod 2) − 1|)`,
   `m = L − C/2`. Rounded to 8-bit:

   | token | CSS | sRGB |
   |---|---|---|
   | `--background` | `0 0% 100%` | `#FFFFFF` |
   | `--foreground` | `240 10% 3.9%` | `#09090B` |
   | `--muted-foreground` (light) | `0 0% 55%` | `#8C8C8C` |
   | `--border` | `240 5.9% 90%` | `#E4E4E7` |
   | `--muted` | `240 4.8% 95.9%` | `#F4F4F5` (unused) |

   `text-muted-foreground/80` is `#8C8C8C` at α = 0.8 → `0xCC8C8C8C`, kept
   as an alpha colour rather than pre-composited over white (`#A3A3A3`) so
   it stays correct wherever it is drawn.

   Tailwind palette literals used as-is: `neutral-900 #171717`,
   `zinc-600 #52525B`, `zinc-900 #18181B`. Markup literal: `#A0A0A0`.
   Alpha literals: `white/20 → 0x33FFFFFF`, `opacity-30 on white →
   0x4DFFFFFF` (0.3·255 = 76.5 → 0x4D), `bg-border opacity-20 →
   0x33E4E4E7`, `background/70 → 0xB3FFFFFF` (0.7·255 = 178.5 → 0xB3).

2. **`TextStyle.height`.** Tailwind ships a font size and a line height per
   class; Flutter's `height` is a multiplier. `height = lineHeight / fontSize`:
   `text-3xl` 30/36 → 1.2, `text-2xl` 24/32 → 4/3, `text-xl` 20/28 → 1.4,
   `text-base` 16/24 → 1.5, `text-sm` 14/20 → 10/7, `text-xs` 12/16 → 4/3,
   `leading-none` → 1.

   **Correction to `context.md`.** Its gotcha "SwiftUI `Text` boxes come
   from the font's line height … leave `TextStyle.height` null in the demo"
   was derived for the SwiftUI port. This screen is a port of CSS, where
   the line height is an explicit design token, so every style in
   `portfolio_tokens.dart` sets `height`. The rule still holds for
   `control_panel.dart`, which is still SwiftUI-derived. A proposed hunk is
   in `## Decisions`.

3. **`tracking-tighter`.** `-0.05em` at 30 px = `letterSpacing: -1.5`
   logical px. Flutter and CSS both add the tracking after every glyph,
   including the last.

4. **Prose paragraph gap.** `.prose :where(p) { margin-top: 1.25em;
   margin-bottom: 1.25em }` with `em` resolving against the `.prose`
   element's own `text-sm` 14 px → 17.5 px. Adjacent `<p>` margins collapse
   in CSS, so the gap between paragraphs is 17.5 px, not 35. The first
   paragraph's top margin is zeroed by
   `.prose :where(.prose > :first-child) { margin-top: 0 }`, which is why
   the "About" heading sits directly on the first line with no gap.

5. **Scroll progress.** Site:
   `t = el.scrollHeight − window.innerHeight;`
   `o = min(round(window.scrollY / t · 100), 100)`.
   Flutter: `t ≡ position.maxScrollExtent`, `window.scrollY ≡
   controller.offset`, so
   `progress = (offset / maxScrollExtent · 100).round().clamp(0, 100)`,
   guarded with `progress = 0` when `maxScrollExtent ≤ 0`.

6. **The progress ring.** The SVG uses `strokeDasharray = (o/100)·62.83`
   over a circumference of `2π·10 = 62.832`, with the `<svg>` itself
   `-rotate-90` so the dash starts at 12 o'clock. The equivalent
   `Canvas.drawArc` is `startAngle = −π/2`,
   `sweepAngle = 2π·(progress/100)`, on `Rect.fromCircle(centre (12,12),
   r 10)`, `strokeWidth 4`, `StrokeCap.round`. Sweep is suppressed below
   0.001 because a zero-length round-capped arc paints a dot, which the
   `0 62.83` dash array does not.

7. **The pill's spring.** Framer Motion, given `{type:"spring",
   duration:0.6, bounce:0.35, mass:1.1}`, ignores the sibling
   `stiffness`/`damping` and derives the spring from duration and bounce:
   `ζ = 1 − bounce = 0.65`, `ω = 2π/duration = 10.472 rad/s`,
   `k = m·ω² = 1.1 · 109.66 = 120.63`,
   `c = 2ζ√(k·m) = 2 · 0.65 · √(120.63 · 1.1) = 15.98`.
   Those are the three numbers in `_IndexPillState._spring`. The controller
   is `AnimationController.unbounded` because ζ < 1 overshoots 1.0 by
   ~7 %, which is the bounce; `width`, `height` and `borderRadius`
   `lerpDouble` through it, and only `padding` is clamped (a negative
   `EdgeInsets` asserts).

8. **CSS `blur()` is a standard deviation, not a radius.** `filter:
   blur(16px)` → `ImageFilter.blur(sigmaX: 16, sigmaY: 16)`; the panel
   animates σ = 16·(1 − v). The scrim's `backdropFilter: blur(8px)` → σ = 8,
   scaled by the same `v` so it fades in with the overlay.

9. **Easing.** `ease:[.4,0,.2,1]` → `Cubic(0.4, 0, 0.2, 1)` (also
   Tailwind's default `transition-all` timing function, used on the ring's
   300 ms dash transition). `ease:[.5,0,.4,1]` → `Cubic(0.5, 0, 0.4, 1)`.
   Lenis' `e => min(1, 1.001 − 2^(−10e))` is `Curves.easeOutExpo`.

10. **Column-relative section offsets.** The page padding is inside the
    scrolling `Column`, so for a section `S` with the `Column` `C`,
    `top(S) = S.localToGlobal(Offset.zero, ancestor: C).dy` is exactly the
    scroll offset that puts `S` at the viewport top. The site's active-
    section rule is `argmin_S |rect(S).top − 100|` in viewport
    coordinates, i.e. `argmin_S |top(S) − offset − 100|`; its jump target
    is `top(S) − 100`, clamped to `[0, maxScrollExtent]`.

11. **Mobile column.** 390 pt screen, `SafeArea` inset horizontally 0:
    page width 390 < `max-w-2xl` 672, so the content column is
    `390 − 2·24 = 342` pt. The hero text column is
    `342 − 128 − 24 = 190` pt, which is why `Hi! I'm Debojyoti 👋`
    wraps and takes the emoji with it.

## Commands

Run from the repository root, in order:

```
flutter pub get
dart format lib test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
flutter build ios --debug --no-codesign
```

`flutter pub get` must come first: the new `assets:` and `fonts:` sections
have to be in the asset manifest before `flutter test` can `rootBundle
.load` the Geist faces. Do not run `flutter run`, `flutter pub add`, or
anything that touches `shaders/`, `ios/` or `pubspec.lock`'s dependency
list.

Then, with the phone attached, a human runs
`flutter run -d 00008120-000278980AE3601E` and works the checklist in
`## Acceptance`.

## Acceptance

Automated:

- A1. `flutter analyze` prints `No issues found!`.
- A2. `dart format --output=none --set-exit-if-changed lib test` exits 0.
- A3. `flutter test` passes, including all four cases in the new
  `test/demo_content_test.dart` and the untouched cases in
  `widget_test.dart`, `reprojection_test.dart` and `blur_dim_test.dart`.
- A4. `flutter build ios --debug --no-codesign` succeeds. (It also proves
  the six font files and three images are in the bundle.)
- A5. `git diff --stat` touches exactly: `pubspec.yaml`,
  `lib/demo/demo_content.dart`, `lib/demo/demo_sections.dart`,
  `lib/demo/demo_style.dart`, the six new `lib/demo/*.dart` files,
  `test/demo_content_test.dart` and `test/widget_test.dart`. Nothing under
  `shaders/`, `lib/fold/`, `lib/motion/`, `ios/` or
  `lib/demo/control_panel.dart`.

On the device, manual tilt at 0° (so the geometry is undistorted):

- H1. The page is white. The heading reads `Hi! I'm Debojyoti 👋` in Geist
  Bold at 30 pt with visibly tight tracking, and 👋 sits on the same line
  as "Debojyoti" or wraps *with* it — never alone.
- H2. The avatar is a 128 pt circle with a hairline `#E4E4E7` ring.
- H3. The subheading changes every 3 s, cycling
  `Student 📚 → Flutter App Developer 💻 → UI/UX Designer 🎨 → Gym Rat 🏋️`,
  with the outgoing phrase sliding up and fading and the incoming one
  sliding up from below. The emoji is visibly larger than the words.
- H4. The tagline is 16 pt medium grey directly under the subheading.
- H5. The Index pill is a black 190×40 capsule centred 48 pt below the top
  of the safe area, showing a white ring, "Index" in bold, a chevron, and a
  grey `0%` badge.
- H6. Dragging the page up fills the ring clockwise from 12 o'clock and
  raises the badge; at the bottom it reads `100%`.
- H7. Tapping the pill springs it open to a 300×300 rounded square with a
  visible overshoot, the chevron flips to point up, the four entries
  (`Introduction`, `About`, `Education`, `Contact`) resolve out of a heavy
  blur as the panel grows, and the rest of the screen goes behind a light
  blurred scrim. The entry matching the current scroll position is brighter
  than the other three.
- H8. Tapping an entry closes the pill and scrolls that section to 100 pt
  below the viewport top over ~1.5 s, decelerating hard at the end.
  Tapping the scrim closes the pill without scrolling.
- H9. The dock is a dark capsule at the bottom with six white glyphs in the
  order document, github, linkedin, X, telegram, sun, with hairline
  separators after the first and before the last. Each glyph is legible —
  no filled blobs, no missing counters (the parser's fill rule). Tapping it
  does nothing.
- H10. Both education crests are legible inside their 40 pt circles and are
  *contained*, not cropped.

With the phone tilted (manual slider at ±30° or live motion):

- H11. The whole portfolio reprojects, blurs and dims exactly as the old
  demo did; the wedge that misses the interface is black. Nothing about the
  effect changed.
- H12. Scrolling while tilted works and does not stutter noticeably
  relative to scrolling at 0°.
- H13. Tapping the pill while tilted is expected to miss (decision 3);
  confirm it misses rather than crashes, and that tapping it at 0° still
  works.

## Out of scope

- `shaders/duo_fold.frag`, `lib/fold/**`, `lib/motion/**`,
  `ios/Runner/**`, and the uniform table in `context.md`. No uniform is
  added, removed, reordered or re-bound this phase.
- `lib/demo/control_panel.dart` and `lib/main.dart`. The floating panel,
  the recalibrate button, the manual slider and the `FoldScreen`
  composition stay exactly as they are.
- `context.md` itself. The proposed hunks in `## Decisions` are for the
  main session to route; do not apply them from this plan.
- `pubspec.yaml`'s `dependencies:`/`dev_dependencies:` and
  `pubspec.lock`. No package is added — in particular no `flutter_svg` or
  `path_drawing`; `svg_path.dart` exists so that none is needed.
- `test/reprojection_test.dart` and `test/blur_dim_test.dart`. Their
  literal colours are shader probes and have nothing to do with the demo
  content.
- The site's `experience`, `skills` and `projects` sections. They need
  `stellarstudios.webp`, `freelance.webp`, `snekid.webp`, `span.webp`,
  `caresync.webp`, `cartoonifyai.webp`, `dewanjee.webp`,
  `radpapers_app.webp`, `radpapers_website.webp`, `orbitai.webp` and
  `whatsbuddy.webp`, none of which are in `assets/images/`. A later phase
  can add them and extend `kSections`; do not stub them with placeholders.
- The `BlurFade` entrance stagger, the 👋 `animate-wave` keyframes, the
  dock's cursor-proximity magnification (`magnification: 60, distance:
  140`), the per-glyph blur stagger inside the rotating subheading, the
  hover chevron in the education cards, the image magnifier on project
  screenshots, and Lenis' smooth-scroll inertia. All declared in
  `## Decisions`; none is a bug.
- Dark mode. No `Theme.of(context)` read may appear in `lib/demo/`.

## Implementation report
STATUS: DONE

**Mid-implementation scope change (coordinator message, verbatim reason: "Its
not needed, its needs to just be a static screen." — "The screen is
wallpaper for the shader to sample. It does not need to work, it needs to
look right.")**. Received after the interactive version below was fully
written and had reached a BLOCKED state (that interactive version, its
BLOCKED report, and the reasoning behind each choice, are described in the
`## Files` and `## Decisions` sections above, which the architect is
revising separately). Applied
on top of the interactive implementation rather than rewritten from scratch,
per the coordinator's instruction. This plan file still describes the
interactive version; the architect is correcting it separately. The
deviations below are a consequence of that scope change, not drift:

1. **Scrolling dropped.** `DemoContent` is now a `StatelessWidget`. Removed
   `ScrollController`, the section `GlobalKey`s, `_onScroll`,
   `_sectionOffset`, `_jumpTo` and `_anchored`. The content is a fixed
   `Column` inside `SingleChildScrollView(physics:
   NeverScrollableScrollPhysics())` with no controller — natural-height
   layout, clipped at the bottom, exactly as context.md describes the 004
   content, never user-scrollable.
2. **`IndexPill` is a static `StatelessWidget`.** Removed
   `TickerProviderStateMixin`, both `AnimationController`s, `CurvedAnimation`,
   `SpringDescription`/`SpringSimulation`, the tap `GestureDetector`s, the
   scrim, `BackdropFilter`/`ImageFiltered` blur and the menu-item list. It
   takes no constructor parameters and renders only the settled, collapsed
   state the screenshot shows: the ring at 0 % (track only, arc suppressed),
   "Index", a chevron permanently pointing down, and a "0%" badge. Geometry
   (190×40, `borderRadius: 24`, `kShadowLg`) and colours are unchanged from
   the plan.
3. **`WordRotate` is a static `StatelessWidget`.** Removed `dart:async`,
   `Timer`, `AnimationController`, `CurvedAnimation` and the
   `cyclingEnabled` flag. It renders `kRotatingWords[1]` ("Flutter App
   Developer" 💻) unconditionally — the phrase the user's screenshot shows —
   with the same `Text.rich`/`kHeroRotator`/`kHeroRotatorEmoji` styling as
   before.
4. **`lib/demo/portfolio_data.dart`**: removed `PortfolioSection` and
   `kSections` (the section-jump menu they served no longer exists) and
   `kRotateInterval` (the cycling timer it served no longer exists).
   `kRotatingWords` is kept, now documented as sourcing only the one static
   phrase. All hero/about/education/contact strings and the avatar asset
   path are untouched.
5. **`test/widget_test.dart`**: the plan's two hunks (import +
   `WordRotate.cyclingEnabled = false;`) were reverted — `WordRotate` no
   longer has that flag or a timer, so nothing in this file needed it. In
   its place I added a `_loadGeist()` `FontLoader` helper (same pattern as
   `test/demo_content_test.dart`) and a `setUpAll(_loadGeist)`, because
   `FoldApp`'s three pre-existing tests embed `DemoContent` → `IndexPill`,
   and without the real Geist faces `flutter_test`'s fallback font renders
   the pill's header wide enough to overflow its fixed 190 pt width,
   independent of any behaviour under test (see the prior BLOCKED revision
   of this report for the exact error). This is a net-new hunk beyond what
   the interactive-version plan authorized for this file; recorded here
   because the plan is being corrected separately and "nothing else in this
   file changes" no longer reflects what the file needs.
6. **`test/demo_content_test.dart`**: dropped the "scrolling moves the
   progress percentage" and "the Index chevron expands the section menu"
   cases (the behaviour they tested no longer exists). Added "the screen
   does not scroll" (asserts `NeverScrollableScrollPhysics` and that a drag
   leaves the "0%" badge in place). The chrome/layout/geometry assertions
   in "renders the hero, the sections and the chrome" are unchanged. The
   architect's flagged FontLoader contingency ("relax the pill assertion")
   never triggered — no assertion needed relaxing once fonts loaded.
7. Entrance/reveal animation (plan decision 6) was already never
   implemented, so nothing to strip there.
8. The dock (`lib/demo/portfolio_dock.dart`) is unchanged — it was already
   a stateless, inert `IgnorePointer`d widget.

Files written (new, per plan, then edited per the scope change above):
`lib/demo/portfolio_tokens.dart` (unchanged from plan), `lib/demo/portfolio_data.dart`
(edited, §4 above), `lib/demo/svg_path.dart` (unchanged), `lib/demo/portfolio_icons.dart`
(unchanged), `lib/demo/portfolio_dock.dart` (unchanged), `lib/demo/portfolio_index_pill.dart`
(rewritten static, §2), `lib/demo/portfolio_hero.dart` (rewritten static, §3).

Files edited:
- `pubspec.yaml` — replaced the commented assets/fonts scaffold block with the `assets:`/`fonts:` hunk from the plan, verbatim.
- `lib/demo/demo_style.dart` — full replacement per plan (trimmed to the four control-panel constants), unaffected by the scope change.
- `lib/demo/demo_sections.dart` — full replacement per plan (About/Education/Contact), unaffected by the scope change.
- `lib/demo/demo_content.dart` — rewritten as a static `StatelessWidget` (§1 above).
- `test/widget_test.dart` — plan hunks reverted, `_loadGeist`/`setUpAll` added instead (§5 above).
- `test/demo_content_test.dart` — full replacement per plan, then edited for the scope change (§6 above).

Deviations from plan: the eight numbered points above, all directly caused by the coordinator's mid-task "static screen" scope-change message quoted at the top of this report. No colour token, type-scale value, spacing constant or asset from the plan was changed.

Self-fixes applied:
1. Added `library;` directive to `lib/demo/portfolio_data.dart` — `flutter analyze`'s `dangling_library_doc_comments` lint (pure style), fixed and re-verified clean. (The `package:flutter/physics.dart` import self-fix from the interactive version was made moot by §2 above, which removed the spring simulation entirely.)
2. Ran `dart format` before the format-check command, per `## Commands`; whitespace-only reflows, no logic change.

Command results:
  flutter pub get — ok (4 transitive packages have newer versions than the pinned constraints allow; no constraint changed)
  dart format lib test — clean after formatting; `dart format --output=none --set-exit-if-changed lib test` exits 0
  flutter analyze — clean: `No issues found!`
  flutter test — all 20 tests pass (`test/reprojection_test.dart`, `test/blur_dim_test.dart`, `test/widget_test.dart`, `test/demo_content_test.dart`)
  flutter build ios --debug --no-codesign — ok: `✓ Built build/ios/iphoneos/Runner.app`

Open questions for architect: none — the architect is correcting this plan file to describe the static screen separately, per the coordinator's message.

## Review

STATUS: REVISE

Reviewed: this plan, the `STATUS: DONE` report above, and
`git diff e499b86` plus the nine untracked files. An earlier
`## Amendment A` of mine (written against the BLOCKED report) has been
deleted from this file: the implementer had already landed the static
screen, and a plan amendment describing work that is already on disk is
just a second source of truth. Its rulings that still matter are folded
into the corrections below.

### What is correct

- **The token layer survived the rewrite byte-for-byte.** I diffed every
  on-disk file against this plan's `## Files` blocks mechanically, not by
  eye: `lib/demo/portfolio_tokens.dart`, `lib/demo/demo_style.dart`,
  `lib/demo/demo_sections.dart`, `lib/demo/portfolio_dock.dart` and
  `lib/demo/svg_path.dart` are **identical** to the plan, character for
  character. `lib/demo/portfolio_icons.dart` differs only by `dart format`
  reflowing the `SvgIcon` constructor across five lines. So every colour,
  every `height` ratio, every spacing constant and both education crests
  are exactly what was specified — the subtractive edit did not reach them.
  `pubspec.yaml` matches the plan's hunk verbatim; the six Geist weights
  and three images are present under `assets/`.
- The pill keeps 190×40, radius 24, `kShadowLg`, `kZinc600` badge, the
  `opacity-30` ring track, bold "Index", down chevron, `0%`.
  `lib/demo/demo_content.dart` keeps `SafeArea`, the three-stop top scrim,
  the dock, and the pill at `kPillTop` inside a `Center`. Nothing visual
  moved.
- Dead behaviour really is deleted, not disabled: no `Timer`,
  `AnimationController`, `ScrollController`, `SpringSimulation`,
  `GestureDetector`, `BackdropFilter`, `ImageFiltered`, `StatefulWidget` or
  `Theme.of` survives anywhere in `lib/demo/` outside `control_panel.dart`.
  `PortfolioSection`, `kSections`, `kRotateInterval`, `_MenuItem` and the
  scrim are gone rather than orphaned.
- `NeverScrollableScrollPhysics` inside a `SingleChildScrollView` is the
  right shape for "static but taller than the viewport": natural-height
  layout, clipped at the bottom, no `RenderFlex` overflow, no drag. Deviation
  from this plan's decision 4 accepted — decision 4 is superseded by the
  user's scope change.
- Deviations 1–4 and 6–8 of the report are all consequences of that scope
  change and are accepted.

### Judgement call 1 — fonts in the `widget_test.dart` fixture

Registering the real faces is the right *kind* of fix: the overflow was a
fallback-font artifact, so putting the suite on shipped metrics removes the
artifact instead of hiding it, and refusing to resize the production pill to
please a test was the correct instinct. Reverting this plan's two
`widget_test.dart` hunks was also correct — `WordRotate.cyclingEnabled` no
longer exists, so keeping them would have been a compile error, and the
"pinned diff stat" existed only to stop unrelated churn in that file, not as
an end in itself.

What is wrong is the *placement*. `_loadGeist` now exists twice, in two
suites, and the failure mode it guards is not local to either: any future
suite that mounts `DemoContent` gets the same 20 px overflow and the same
hour of confusion, because nothing in either copy says "this is a global
precondition". That is the papering-over risk, and it is cheap to remove:
`flutter test` runs `test/flutter_test_config.dart`'s `testExecutable` in
place of every suite's `main` in the directory tree. One file, one copy,
every suite — including the ones that do not exist yet. Correction 5.

### Judgement call 2 — leftovers from the interactive version

Three, all of the "shape without the substance" kind the coordinator asked
about:

1. `_RingPainter` still takes `progress`, stores it, and carries a
   `if (progress > 0.001) { drawArc(...) }` branch that can never run,
   because its only call site is `_RingPainter(0)`. `dart:math` is imported
   solely to feed that dead branch. `shouldRepaint` already returns a flat
   `false`, which is correct only because the field never varies — so the
   class simultaneously claims to be progress-driven and assumes it is not.
   Corrections 1–3.
2. `WordRotate` is a widget named for a rotation it no longer performs, and
   it reads `kRotatingWords[1]` — a magic index into a four-element list of
   which three elements are now unreachable. Corrections 4a–4c.
3. `kPillMenuItem` / `kPillMenuItemActive` in `portfolio_tokens.dart` are
   now unreferenced. **Leave them.** The user asked for the token set as
   specified, the analyzer does not flag public consts, and a later phase
   restoring the menu will want them. Recorded so nobody "cleans" them.

All five corrections below are pixel-neutral: no colour, size, style,
string or layout changes. The build already on the user's phone does not
need to be rebuilt for their visual sign-off.

### Corrections

**1. `lib/demo/portfolio_index_pill.dart` lines 1–3 — drop the dead
`dart:math` import.**

Current:

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
```

Required:

```dart
import 'package:flutter/widgets.dart';
```

**2. `lib/demo/portfolio_index_pill.dart` line 54 — the ring call site.**

Current:

```dart
                  child: CustomPaint(painter: _RingPainter(0)),
```

Required:

```dart
                  child: CustomPaint(painter: _RingPainter()),
```

**3. `lib/demo/portfolio_index_pill.dart` lines 81–116 — `_RingPainter`
loses the parameter and the unreachable arc.**

Current:

```dart
/// `<svg class="-rotate-90">` with two `r=10 strokeWidth=4` circles. Always
/// drawn at 0 % progress: the progress arc never appears (suppressed below
/// 0.001, per the plan's `## Math` §6), only the track.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

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
    if (progress > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(12, 12), radius: 10),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = kWhite,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}
```

Required:

```dart
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
```

**4a. `lib/demo/portfolio_data.dart` lines 16–27 — one phrase, no magic
index.**

Current:

```dart
/// `rg` — the four phrases of the bundle's rotating subheading, split into
/// the word run and the trailing emoji token because the bundle renders any
/// `\p{Extended_Pictographic}` token one step larger. This screen is static
/// wallpaper for the fold shader (007 scope change), so only
/// `kRotatingWords[1]` — the phrase the user's screenshot shows — is ever
/// rendered; the cycling and its `rm`'s `duration: 3e3` are dropped.
const List<(String, String)> kRotatingWords = <(String, String)>[
  ('Student', '📚'),
  ('Flutter App Developer', '💻'),
  ('UI/UX Designer', '🎨'),
  ('Gym Rat', '🏋️'),
];
```

Required:

```dart
/// `rg[1]` — the subheading. The bundle cycles four phrases
/// (`Student 📚`, `Flutter App Developer 💻`, `UI/UX Designer 🎨`,
/// `Gym Rat 🏋️`) every 3 s through `rm({words: rg, duration: 3e3})`; this
/// screen is static wallpaper for the fold shader (007 scope change), so it
/// renders the one phrase the user's screenshot shows and nothing else. The
/// other three phrases and the interval are not kept as unreachable data.
///
/// Split into the word run and the emoji token because the bundle renders
/// any `\p{Extended_Pictographic}` token one step larger (decision 8).
const String kHeroSubheadingWords = 'Flutter App Developer';
const String kHeroSubheadingEmoji = '💻';
```

**4b. `lib/demo/portfolio_hero.dart` line 36 — the call site.**

Current:

```dart
              WordRotate(),
```

Required:

```dart
              HeroSubheading(),
```

**4c. `lib/demo/portfolio_hero.dart` lines 47–71 — rename and de-index the
widget.**

Current:

```dart
/// The subheading. Static per the user's screenshot: this screen is
/// wallpaper for the fold shader to sample, not a live surface, so the
/// bundle's `rm({words: rg, duration: 3e3})` cycling is not reproduced —
/// only `kRotatingWords[1]` ("Flutter App Developer" 💻), the phrase the
/// screenshot shows, is rendered. No timer, no controller.
class WordRotate extends StatelessWidget {
  const WordRotate({super.key});

  @override
  Widget build(BuildContext context) {
    final (String words, String emoji) = kRotatingWords[1];
    return SizedBox(
      height: kRotatorHeight,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '$words '),
            TextSpan(text: emoji, style: kHeroRotatorEmoji),
          ],
        ),
        style: kHeroRotator,
      ),
    );
  }
}
```

Required:

```dart
/// The subheading, static. This screen is wallpaper for the fold shader to
/// sample, not a live surface, so the bundle's `rm({words: rg, duration:
/// 3e3})` cycling is not reproduced: the one phrase the user's screenshot
/// shows is rendered and nothing moves. No timer, no controller, no state —
/// and no name that implies otherwise.
///
/// The emoji token keeps its own larger box (decision 8), which is why the
/// line box is [kRotatorHeight] = 32, sized by the emoji and not by the
/// 28 px words.
class HeroSubheading extends StatelessWidget {
  const HeroSubheading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: kRotatorHeight,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '$kHeroSubheadingWords '),
            TextSpan(text: kHeroSubheadingEmoji, style: kHeroRotatorEmoji),
          ],
        ),
        style: kHeroRotator,
      ),
    );
  }
}
```

The interpolation is a constant expression — both operands are `const
String` — so the `const SizedBox` holds. The rendered string is unchanged:
`'Flutter App Developer '` + `'💻'`.

**5. Font registration moves to one file that covers every suite.**

**5a. New file `test/flutter_test_config.dart`, full content:**

```dart
import 'dart:async';

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Registers the Geist faces for **every** suite under `test/`.
///
/// `flutter test` discovers this file automatically and runs
/// [testExecutable] in place of each suite's `main`. Without the real faces
/// `flutter_test` renders every glyph as the fallback test font's em square,
/// which widens "Index" and the `0%` badge enough to overflow the Index
/// pill's fixed 190×40 header `Row` by 20 px — an artifact of the test font
/// only, never a production one, which is why the pill is not resized to
/// accommodate it. It is registered here rather than per suite so that a
/// future suite mounting `DemoContent` inherits the fix instead of
/// rediscovering the overflow.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final FontLoader loader = FontLoader('Geist');
  for (final int weight in <int>[300, 400, 500, 600, 700, 800]) {
    loader.addFont(rootBundle.load('assets/fonts/Geist-$weight.ttf'));
  }
  await loader.load();
  await testMain();
}
```

**5b. `test/widget_test.dart` lines 4–6 — drop the now-unused import.**

Current:

```dart
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSlider;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_shaders/flutter_shaders.dart';
```

Required:

```dart
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSlider;
import 'package:flutter_shaders/flutter_shaders.dart';
```

**5c. `test/widget_test.dart` lines 16–28 — drop the local loader.**

Current:

```dart
/// `FoldApp` embeds `DemoContent`, which since 007 includes the Index pill's
/// fixed 190×40 geometry. Without the real Geist faces, `flutter_test`'s
/// fallback font renders that header's text wide enough to overflow the
/// pill, independent of any behaviour under test here — see the plan's
/// `## Implementation report`.
Future<void> _loadGeist() async {
  final FontLoader loader = FontLoader('Geist');
  for (final int weight in <int>[300, 400, 500, 600, 700, 800]) {
    loader.addFont(rootBundle.load('assets/fonts/Geist-$weight.ttf'));
  }
  await loader.load();
}

/// Scriptable stand-in for the native bridge.
```

Required:

```dart
/// Scriptable stand-in for the native bridge.
```

**5d. `test/widget_test.dart` — drop the `setUpAll`.**

Current:

```dart
void main() {
  setUpAll(_loadGeist);

  group('FoldParameters', () {
```

Required:

```dart
void main() {
  group('FoldParameters', () {
```

After 5b–5d, `git diff e499b86 -- test/widget_test.dart` must print nothing.

**5e. `test/demo_content_test.dart` line 1 — drop the now-unused import.**

Current:

```dart
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter/widgets.dart';
```

Required:

```dart
import 'package:flutter/widgets.dart';
```

**5f. `test/demo_content_test.dart` lines 12–29 — drop the local loader,
keep the doc comment.**

Current:

```dart
/// The real Geist faces are loaded so that widths are the shipped ones:
/// without them every glyph is the test font's em square and the 190 pt
/// Index pill overflows in the test and only in the test.
Future<void> _loadGeist() async {
  final FontLoader loader = FontLoader('Geist');
  for (final int weight in <int>[300, 400, 500, 600, 700, 800]) {
    loader.addFont(rootBundle.load('assets/fonts/Geist-$weight.ttf'));
  }
  await loader.load();
}

Widget _fixture() {
```

Required:

```dart
/// The Geist faces are registered for every suite by
/// `test/flutter_test_config.dart`, so widths here are the shipped ones and
/// the 190 pt Index pill does not overflow.
Widget _fixture() {
```

(The five doc-comment lines above this hunk, describing the static screen,
stay exactly as they are.)

**5g. `test/demo_content_test.dart` lines 39–44 — drop the per-suite
bootstrap.**

Current:

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadGeist);

  testWidgets('renders the hero, the sections and the chrome', (
```

Required:

```dart
void main() {
  testWidgets('renders the hero, the sections and the chrome', (
```

**5h. `test/demo_content_test.dart` line 60 — follow the rename.**

Current:

```dart
    expect(find.byType(WordRotate), findsOneWidget);
```

Required:

```dart
    expect(find.byType(HeroSubheading), findsOneWidget);
```

**5i. `pubspec.yaml` — the comment now names the wrong file.**

Current:

```yaml
  # The portfolio screen's images (007). Declared as a directory: every file
  # in it is bundled, and `test/demo_content_test.dart` loads the fonts
  # through `rootBundle`, which needs them in the manifest.
```

Required:

```yaml
  # The portfolio screen's images (007). Declared as a directory: every file
  # in it is bundled, and `test/flutter_test_config.dart` loads the fonts
  # through `rootBundle`, which needs them in the manifest.
```

If `flutter test` cannot load the fonts from `testExecutable`, restore the
two `_loadGeist` helpers exactly as they are today, report `STATUS: BLOCKED`
with the error, and do not invent a third approach.

### Commands for the revision

```
dart format lib test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
```

`flutter build ios --debug --no-codesign` does not need re-running: no
correction touches a pixel, a string, an asset or `pubspec.yaml`'s bundle
contents (5i is a comment).

### Acceptance for the revision

- R1. `flutter analyze` prints `No issues found!`.
- R2. `dart format --output=none --set-exit-if-changed lib test` exits 0.
- R3. All 20 tests pass, with no `RenderFlex overflowed` line anywhere in
  the output.
- R4. `git diff e499b86 -- test/widget_test.dart` prints nothing.
- R5. `grep -rn "kRotatingWords\|WordRotate\|_RingPainter(0)\|dart:math" lib/demo`
  prints nothing.
- R6. `git diff` of `lib/demo/portfolio_tokens.dart`,
  `lib/demo/demo_style.dart`, `lib/demo/demo_sections.dart` and
  `lib/demo/portfolio_dock.dart` against their state before the revision is
  empty: not one token may move.

### Note for the commit (main session)

`git commit -am "phase 007: portfolio-screen"` will **miss** everything
here, because `assets/`, the seven new `lib/demo/*.dart` files,
`test/flutter_test_config.dart` and this plan file are untracked. The
commit must be `git add -A` first.

### Proposed `context.md` hunks

These supersede the hunks proposed in `## Decisions` above, which describe
the interactive version. The main session routes them; the architect does
not edit `context.md`.

    - The demo screen is pinned to the iOS **light** appearance (004). It hard-codes
    + The demo screen is pinned to the **light** appearance (004/007). It hard-codes

    - `lib/demo/demo_content.dart  # DemoContentView port: root, header, chips, hero`
    - `lib/demo/demo_sections.dart # DemoContentView port: stat grid, Recent list`
    - `lib/demo/demo_style.dart    # iOS light system colours + text styles`
    + `lib/demo/demo_content.dart      # portfolio root: page, scrims, pill, dock`
    + `lib/demo/demo_sections.dart     # About / Education / Contact`
    + `lib/demo/portfolio_hero.dart    # avatar, NBSP heading, subheading, tagline`
    + `lib/demo/portfolio_index_pill.dart # static "Index" pill at its 0 % rest state`
    + `lib/demo/portfolio_dock.dart`
    + `lib/demo/portfolio_tokens.dart  # debojyoticodes.in colour/type/metric tokens`
    + `lib/demo/portfolio_data.dart    # strings quoted from the site bundle`
    + `lib/demo/portfolio_icons.dart   # the dock's SVG path data`
    + `lib/demo/svg_path.dart          # SVG path subset parser`
    + `lib/demo/demo_style.dart        # iOS light colours the control panel still uses`
    + `test/flutter_test_config.dart   # registers Geist for every suite`

    + - The demo content since 007 is a port of debojyoticodes.in, not
    +   `DemoContentView.swift`, and it is **static**: wallpaper for the shader to
    +   sample. Nothing in `lib/demo/` outside `control_panel.dart` may hold state,
    +   a timer, a controller or a gesture. The page does not scroll — it lays out
    +   at natural height inside a `SingleChildScrollView` with
    +   `NeverScrollableScrollPhysics` and is clipped at the bottom.
    + - Its type scale comes from CSS, so its `TextStyle`s set `height` explicitly
    +   (Tailwind line-height / font size); the "leave `height` null" rule above
    +   applies only to `control_panel.dart`, which is still SwiftUI-derived.
    + - `AnimatedSampler`'s render object is a `RenderProxyBox`: hit testing is
    +   *not* reprojected — taps land where the pixel would be at θ = 0. That is
    +   the reason the demo screen takes no gestures at all; do not add one.
    + - Widget tests that mount `DemoContent` need the real Geist faces. Under
    +   `flutter_test`'s fallback font the Index pill's fixed 190×40 header
    +   overflows by 20 px. `test/flutter_test_config.dart` registers them for
    +   every suite; do not resize the pill to satisfy a test.

### Addendum — race with the withdrawn Amendment A

While this review was being written the implementer was concurrently
applying my earlier `## Amendment A` (dispatched before the coordinator
stopped it). The two converge — the amendment and correction 5 specify the
same `test/flutter_test_config.dart` — but the tree is currently in a
half-applied state. Reconcile as follows; where a correction above is
already satisfied on disk, skip it, do not re-apply it.

- **Already applied, keep:** `test/flutter_test_config.dart` exists and
  matches 5a apart from its last doc line; `test/widget_test.dart` is back
  to its `e499b86` content (5b–5d done, R4 satisfied);
  `test/demo_content_test.dart` has lost its `services.dart` import and its
  `_loadGeist` body (5e, 5f done).
- **Correction 6 (blocking, compile error).** `test/demo_content_test.dart`
  still calls a helper that no longer exists. Apply 5g exactly as written
  above: the file must go from

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadGeist);

  testWidgets('renders the hero, the sections and the chrome', (
```

  to

```dart
void main() {
  testWidgets('renders the hero, the sections and the chrome', (
```

- **Correction 7.** `## Amendment A` has been deleted from this plan file,
  so two doc comments now cite a section that does not exist. In
  `test/flutter_test_config.dart` line 17 and `test/demo_content_test.dart`
  line 18, replace the text `plan 007, amendment A, decision 22` with
  `plan 007, ` + "`## Review`" + ` correction 5`. Nothing else in either
  comment changes.
- **Still outstanding:** corrections 1, 2, 3 (`_RingPainter`), 4a, 4b, 4c
  (`HeroSubheading` + `kHeroSubheadingWords`/`kHeroSubheadingEmoji`), 5h
  (`find.byType(HeroSubheading)`) and 5i (the `pubspec.yaml` comment).
  Corrections 4a–4c are identical in effect to the amendment's A.2/A.3, so
  if those were already applied, only 1, 2, 3, 5h and 5i remain.
- The amendment's A.6 rewrote `test/demo_content_test.dart`'s assertions
  (`find.textContaining('Flutter App Developer', findRichText: true)`, an
  "inert" case). Either that version or the current one is acceptable; do
  not do both and do not lose the `NeverScrollableScrollPhysics` assertion.

## Implementation report (revision)

STATUS: DONE

Note on process: I was originally dispatched to apply this plan's
`## Amendment A`, at the coordinator's direction. While reading the file,
the coordinator sent a correction: Amendment A had been deleted from the
plan (it described work already on disk) and superseded by this file's
`## Review` section (corrections 1–7) plus its closing addendum. I worked
from `## Review` and the addendum from that point on, not from Amendment A.
Before the correction I had already: created `test/flutter_test_config.dart`,
reverted `test/widget_test.dart` to `e499b86` via `git checkout HEAD --
test/widget_test.dart`, and stripped the redundant `_loadGeist`/`setUpAll`
out of `test/demo_content_test.dart`. All three actions matched what the
Review independently required (5a–5d, 5e–5g), so nothing needed undoing;
I only had to fix doc-comment wording afterward (see below).

Files written:
- `test/flutter_test_config.dart` — new, content matches `## Review` §5a
  verbatim.

Files edited:
- `test/widget_test.dart` — reverted to `git show HEAD:test/widget_test.dart`
  via `git checkout`. `git diff --stat -- test/widget_test.dart` prints
  nothing (R4/B4).
- `test/demo_content_test.dart` — dropped the `services.dart` import and the
  local `_loadGeist` helper/`setUpAll` call (already done pre-correction);
  fixed the doc comment to the Review's §5f wording (no more "amendment A"
  citation) and changed `find.byType(WordRotate)` to
  `find.byType(HeroSubheading)` per §5h.
- `lib/demo/portfolio_index_pill.dart` — corrections 1–3: dropped the dead
  `dart:math` import, changed the call site to `_RingPainter()`, and
  removed `_RingPainter`'s `progress` field and unreachable `drawArc`
  branch, replacing its doc comment per the Review's required text.
- `lib/demo/portfolio_data.dart` — correction 4a: replaced `kRotatingWords`
  (and its already-removed-elsewhere `kRotateInterval`) with
  `kHeroSubheadingWords` / `kHeroSubheadingEmoji`, doc comment as specified.
- `lib/demo/portfolio_hero.dart` — corrections 4b/4c: `WordRotate()` call
  site renamed to `HeroSubheading()`; the `WordRotate` class renamed to
  `HeroSubheading`, dropped the `kRotatingWords[1]` indexing in favor of the
  two new constants, doc comment as specified.
- `pubspec.yaml` — correction 5i: comment now names
  `test/flutter_test_config.dart` instead of `test/demo_content_test.dart`.

Deviations from plan: none. Every hunk applied was byte-matched against its
"Current" block before editing.

Self-fixes applied: none beyond what the corrections specified.

Command results:
  flutter pub get — ok (4 transitive packages have newer versions than the pinned constraints allow; no constraint changed)
  dart format lib test — 23 files, 0 changed
  flutter analyze — clean: `No issues found!`
  dart format --output=none --set-exit-if-changed lib test — exit 0
  flutter test — all 20 tests pass, no `RenderFlex overflowed` anywhere in the output
  flutter build ios --debug --no-codesign — ok: `✓ Built build/ios/iphoneos/Runner.app`

Acceptance checks run directly:
  git diff --stat -- test/widget_test.dart — prints nothing (R4/B4 satisfied)
  grep -rn "Timer\|ScrollController\|AnimationController\|SpringSimulation\|GestureDetector" lib/demo | grep -v control_panel.dart — prints nothing (B5 satisfied)
  grep -rn "kRotatingWords\|WordRotate\|_RingPainter(0)\|dart:math" lib/demo — prints nothing under lib/demo except lib/demo/control_panel.dart's unrelated `dart:math` import (R5 satisfied)
  git diff --stat for lib/demo/portfolio_tokens.dart, demo_style.dart, demo_sections.dart, portfolio_dock.dart — none of these four files were touched in this pass (R6 satisfied)
  git status --porcelain — matches the expected set: modified `pubspec.yaml`, `lib/demo/demo_content.dart`, `lib/demo/demo_sections.dart`, `lib/demo/demo_style.dart`, `test/demo_content_test.dart`; untracked `assets/`, `docs/plans/007-portfolio-screen.md`, the seven `lib/demo/portfolio_*.dart`/`svg_path.dart` files, `test/flutter_test_config.dart`. `test/widget_test.dart` not listed; nothing under `shaders/`, `lib/fold/`, `lib/motion/`, `ios/`, `lib/demo/control_panel.dart`.

Open questions for architect: none.

## Review (revision)

STATUS: REVISE

One correction. Everything the revision pass was asked to do was done, and
done byte-exactly; the defect below is older than this pass — it landed in
the first pass and I missed it in `## Review`. It is two hunks in two files.

### What I verified mechanically, not by reading the report

- **All 15 correction blocks are applied verbatim.** I extracted every
  `Current:`/`Required:` fenced block from `### Corrections` and substring-
  matched each against the file on disk. All 15 `Required` blocks are
  present character-for-character; all 14 `Current` blocks are absent. No
  correction was paraphrased, and no superseded text survives anywhere.
- **`_RingPainter` no longer claims an input it never receives.**
  `lib/demo/portfolio_index_pill.dart:87-104`: `const _RingPainter()`, no
  field, no `drawArc`, no `clamp`, one `drawCircle` at `#4DFFFFFF`.
  `shouldRepaint => false` is now true by construction rather than by
  accident. The sole call site is line 52, `_RingPainter()`, inside a
  `const <Widget>[]` list. `dart:math` is gone from the file; the only
  `dart:math` left under `lib/demo/` is `control_panel.dart`'s, which is
  out of scope and unrelated (R5 as written said "prints nothing", which
  was my over-tight wording, not a miss).
- **The rename left nothing stale.** `grep -rn` over `lib`, `test`,
  `shaders` and `pubspec.yaml` for `WordRotate`, `kRotatingWords`,
  `kRotateInterval`, `kSections`, `PortfolioSection`, `progressPercent`,
  `activeSectionId`, `onSectionTap`, `cyclingEnabled`, `_loadGeist`,
  `Amendment A`/`amendment A` returns **nothing**. `HeroSubheading` is
  declared once, called once from `portfolio_hero.dart:36`, asserted once
  from `demo_content_test.dart:47`.
  `'$kHeroSubheadingWords ' + kHeroSubheadingEmoji` renders
  `Flutter App Developer 💻`, unchanged.
- **The token files are still byte-identical to this plan's `## Files`
  blocks after the second pass.** I re-extracted the blocks from this file
  and diffed: `portfolio_tokens.dart`, `demo_style.dart`,
  `demo_sections.dart`, `portfolio_dock.dart` and `svg_path.dart` are
  **IDENTICAL**, zero lines of diff. `portfolio_icons.dart` still differs
  only by `dart format`'s five-line reflow of the `SvgIcon` constructor.
  `pubspec.yaml` carries 5i and nothing else moved: `assets/images/`, the
  six Geist weights with their real `weight:` keys, `shaders:` untouched.
  Not one constant slipped.
- **`test/flutter_test_config.dart` matches §5a verbatim**, including the
  closing doc line — correction 7's `amendment A` citation is gone from
  both files.
- **I ran the commands myself.** `flutter analyze` → `No issues found!`.
  `dart format --output=none --set-exit-if-changed lib test` → `23 files
  (0 changed)`, exit 0. `flutter test` → `+20: All tests passed!`, and a
  case-insensitive grep for `overflow` over the full output returns 0 hits.
  `git diff --stat -- test/widget_test.dart` is empty (R4). R1, R2, R3, R4,
  R6 confirmed independently.

### The defect: the non-breaking space is gone

Decision 9 and `## Math` §11 both turn on one character. The plan's
`## Files` block for `portfolio_data.dart` has U+00A0 between "Debojyoti"
and 👋 (I checked the plan's own bytes: NBSP at plan lines 88, 544, 547,
2003, 2189). On disk there is U+0020:

    lib/demo/portfolio_data.dart:9
    ['0x44','0x65','0x62','0x6f','0x6a','0x79','0x6f','0x74','0x69',
     '0x20',            <-- must be 0xa0
     '0x1f44b']

A repo-wide scan finds **zero** U+00A0 characters in any file under `lib/`
or `test/`. It was lost in both the literal and its own doc comment, and
`test/demo_content_test.dart:38` asserts the plain-space string, so the
suite is self-consistently wrong and green. Two comments —
`portfolio_data.dart:6` ("is the bundle's non-breaking space") and
`demo_content_test.dart:37` ("The NBSP is load-bearing") — currently
describe a character that is not in the file. That is the same class of
finding as judgement call 2 in `## Review`: shape without substance, and
here it is also a factually false comment.

Whether it changes pixels at exactly 390 pt is not the point and I am not
going to guess it: at 190 pt of hero column the two layouts differ the
moment the column is one glyph narrower, the site's own markup uses
`&nbsp;` deliberately, and H1/J1 is a stated acceptance criterion the user
is about to check on a device. Fix the character, not the criterion.

The fix writes it as a Dart escape rather than a raw character. It has now
been normalised away twice in transcription; `\u00A0` cannot be, it is
visible in review and in `git diff`, and the literal stays `const`.

### Corrections

**8a. `lib/demo/portfolio_data.dart` lines 6-9.**

Current (the spaces in this block are the plain U+0020 now on disk; match
it as literal text):

```dart
/// ` ` is the bundle's non-breaking space: it binds the waving hand to
/// the name so the emoji wraps as one unit with "Debojyoti" in a narrow
/// column. Do not replace it with a newline or a normal space.
const String kHeroHeadingText = "Hi! I'm Debojyoti 👋";
```

Required (type the backslash-u escape literally; do not paste a raw
U+00A0 anywhere):

```dart
/// The `\u00A0` is the bundle's non-breaking space: it binds the waving
/// hand to the name so the emoji wraps as one unit with "Debojyoti" in the
/// 190 pt hero column (plan 007, `## Math` §11). It is written as an escape
/// rather than as a literal U+00A0 because the literal was silently
/// normalised to a plain space during transcription — twice. Do not
/// "simplify" it back to a raw character, a plain space or a newline.
const String kHeroHeadingText = "Hi! I'm Debojyoti\u00A0👋";
```

**8b. `test/demo_content_test.dart` lines 37-38.**

Current:

```dart
    // The NBSP is load-bearing: it binds the emoji to the name.
    expect(find.text("Hi! I'm Debojyoti 👋"), findsOneWidget);
```

Required:

```dart
    // The NBSP is load-bearing: it binds the emoji to the name. Written as
    // an escape so it cannot be normalised away, and asserted here so that
    // if it is, this case fails instead of the device render.
    expect(find.text("Hi! I'm Debojyoti\u00A0👋"), findsOneWidget);
```

Nothing else changes. No token, no colour, no metric, no other string, no
`pubspec.yaml`, no asset. If `flutter test` fails after 8a+8b, the cause is
that only one of the two was applied — apply both, do not relax the
assertion.

### Commands for revision 2

```
dart format lib test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
```

`flutter build ios --debug --no-codesign` does not need re-running: no
asset, no `pubspec.yaml` entry and no native file changes, and the two
edited files are pure Dart already covered by `flutter test`.

### Acceptance for revision 2

- S1. `flutter analyze` prints `No issues found!`.
- S2. `dart format --output=none --set-exit-if-changed lib test` exits 0.
- S3. All 20 tests pass, no `RenderFlex overflowed` anywhere in the output.
  This now proves the character: `find.text` compares the rendered string,
  so the assertion only matches if the widget tree really holds U+00A0.
- S4. `grep -c 'Debojyoti\\u00A0' lib/demo/portfolio_data.dart` prints `1`,
  and the same grep on `test/demo_content_test.dart` prints `1`.
- S5. No raw U+00A0 is introduced. This prints `0`:

```
python3 -c "import pathlib;print(sum(p.read_text(encoding='utf-8').count(chr(0xa0)) for p in list(pathlib.Path('lib').rglob('*.dart'))+list(pathlib.Path('test').rglob('*.dart'))))"
```

- S6. `git status --porcelain` shows exactly the same file set as after the
  last pass — this revision modifies `lib/demo/portfolio_data.dart` and
  `test/demo_content_test.dart` and creates nothing.
- S7. `git diff --stat -- test/widget_test.dart` still prints nothing.

### The device checklist, restated as J1-J8

`## Acceptance`'s H1-H13 were written for the interactive screen. H3, H6,
H7, H8, H12 and the first clause of H13 describe behaviour the scope change
deleted and are **void**, not pending. The pending list for this phase is
exactly:

- J1. Heading reads `Hi! I'm Debojyoti 👋` in Geist Bold 30 pt with visibly
  tight tracking, and 👋 is on the same line as "Debojyoti" or wraps *with*
  it — never alone. (This is what correction 8 protects.)
- J2. Avatar is a 128 pt circle with a hairline `#E4E4E7` ring; both
  education crests are contained, not cropped, in their 40 pt circles.
- J3. Subheading reads `Flutter App Developer 💻`, static, emoji visibly
  larger than the words; the 16 pt grey tagline sits directly under it.
- J4. Index pill: black 190×40 capsule, centred, 48 pt below the top of the
  safe area, showing the white `opacity-30` ring at 0 %, "Index" in bold, a
  chevron pointing **down**, and a grey `0%` badge.
- J5. Dock: dark capsule at the bottom, six white glyphs in the order
  document, github, linkedin, X, telegram, sun, hairline separators after
  the first and before the last, every counter legible (no filled blobs).
- J6. Nothing on the screen responds to touch: no scroll, no pill
  expansion, no dock action. The page is clipped at the bottom, not
  overflow-striped.
- J7. Under tilt the whole portfolio reprojects, blurs and dims exactly as
  the 004 demo did; the wedge that misses the interface is black. Nothing
  about the effect changed.
- J8. Frame rate under live motion is indistinguishable from the 004 demo.

These join the unrun device checklists from 003, 005 and 006. All pending,
none failing.

### Proposed `context.md` hunk (route after the in-flight pass lands)

The hunks in `## Review` stand as written; this is one extra line for the
demo gotchas, to be appended to the bullet that describes the 007 screen:

    +   The hero heading's non-breaking space is written `\u00A0`, not as a raw
    +   character: the raw one has been normalised to a plain space twice, and it
    +   is what keeps 👋 from wrapping alone in the 190 pt hero column.

### Note for the commit (main session)

Unchanged from `## Review`: `git commit -am` would miss `assets/`, the
seven new `lib/demo/*.dart` files, `test/flutter_test_config.dart` and this
plan file. Use `git add -A` first.

Once correction 8 is in and S1-S7 pass, this is the paragraph for the
commit body:

    The interface behind the glass is now a static port of the mobile
    rendering of debojyoticodes.in in its light theme, replacing the
    DemoContentView demo from 004. It is deliberately inert: hero, About,
    Education and Contact lay out at natural height inside a
    non-scrolling SingleChildScrollView and are clipped at the bottom, and
    the Index pill and the dock are rendered at their rest state — 0 % ring,
    "0%" badge, chevron down — with no timer, controller, gesture or state
    anywhere under lib/demo/ outside control_panel.dart. It is wallpaper for
    the shader to sample, so the site's scroll progress, section-jump menu,
    phrase cycling, entrance blur-fades and dock links are all absent by
    design rather than broken. Colours, metrics and the Geist type scale
    live in portfolio_tokens.dart, computed from the site's own CSS custom
    properties; the dock glyphs are the site's SVG path data parsed by a
    small in-repo subset parser, so no new package was added. The shader,
    the uniform table, FoldEffect, the motion bridge and ControlPanel are
    byte-identical to their state at e499b86.

## Implementation report (revision 2)

STATUS: DONE

Files written: none

Files edited:
- `lib/demo/portfolio_data.dart` — correction 8a: doc comment above
  `kHeroHeadingText` now describes and uses the ` ` escape (typed as
  literal backslash-u text, not a raw NBSP character) between "Debojyoti"
  and the emoji.
- `test/demo_content_test.dart` — correction 8b: the hero-heading assertion
  and its doc comment now use the ` ` escape to match.

Deviations from plan: none.

Self-fixes applied:
1. The `Edit` tool's text-transit layer silently normalised the typed
   ` ` escape into a raw U+00A0 character on the first attempt (the
   exact failure mode the architect warned about, reproduced a third time).
   Caught it before running any commands by re-reading the file bytes with
   a `python3 -c` one-liner rather than trusting the diff, then rewrote
   both files with `python3` string replacement (not the `Edit` tool) so
   the literal two-character escape ` ` lands on disk instead of
   U+00A0. Re-verified with the same byte-level read.

Command results:
  dart format lib test — 23 files, 0 changed
  flutter analyze — clean (`No issues found!`)
  dart format --output=none --set-exit-if-changed lib test — exit 0
  flutter test — all 20 tests passed, no `RenderFlex overflowed` output
  flutter build ios — not run (plan states no rebuild needed for this
    correction: no asset, no pubspec.yaml entry, no native file changes)

Verification (S4/S5):
  grep -c 'Debojyoti\\u00A0' lib/demo/portfolio_data.dart → 1
  grep -c 'Debojyoti\\u00A0' test/demo_content_test.dart → 1
  raw U+00A0 count across lib/**/*.dart and test/**/*.dart → 0

git status --porcelain matches the file set from the prior pass (this
revision only modified `lib/demo/portfolio_data.dart` and
`test/demo_content_test.dart`); `git diff --stat -- test/widget_test.dart`
is empty.

Open questions for architect: none.
