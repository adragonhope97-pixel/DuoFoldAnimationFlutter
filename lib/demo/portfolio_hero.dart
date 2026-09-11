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
              HeroSubheading(),
              SizedBox(height: kHeroTaglineGap),
              Text(kHeroTaglineText, style: kHeroTagline),
            ],
          ),
        ),
      ],
    );
  }
}

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
