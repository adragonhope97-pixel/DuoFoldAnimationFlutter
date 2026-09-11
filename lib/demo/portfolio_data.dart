/// Every string on the portfolio screen, quoted from the site's client
/// bundle (`scratchpad/hunt/d69ce6a8de1a752c.js`, the `ee` object and the
/// `de` section list) rather than retyped from the rendered page.
library;

/// The `\u00A0` is the bundle's non-breaking space: it binds the waving
/// hand to the name so the emoji wraps as one unit with "Debojyoti" in the
/// 190 pt hero column (plan 007, `## Math` §11). It is written as an escape
/// rather than as a literal U+00A0 because the literal was silently
/// normalised to a plain space during transcription — twice. Do not
/// "simplify" it back to a raw character, a plain space or a newline.
const String kHeroHeadingText = "Hi! I'm Debojyoti\u00A0👋";

/// `ee.description`.
const String kHeroTaglineText =
    'I build beautiful mobile apps with design, code, and just enough '
    'caffeine. ☕️';

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
