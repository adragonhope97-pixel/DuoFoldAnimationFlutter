import 'package:flutter/widgets.dart';

import 'demo_sections.dart';
import 'portfolio_dock.dart';
import 'portfolio_hero.dart';
import 'portfolio_index_pill.dart';
import 'portfolio_tokens.dart';

/// The interface the fold effect looks at: a static port of the mobile
/// rendering of debojyoticodes.in (007), replacing the `DemoContentView.swift`
/// port that stood here from 004.
///
/// This screen is wallpaper for the shader to sample, not a working page: it
/// renders once in its settled state and never scrolls, cycles or expands.
/// No `StatefulWidget`, no controllers.
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
/// The content is laid out at natural height and clipped at the bottom by a
/// non-scrolling `SingleChildScrollView`, exactly as the 004 content did
/// (context.md → gotchas), rather than left free to scroll.
class DemoContent extends StatelessWidget {
  const DemoContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBackground,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _content()),
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
            const Positioned(
              top: kPillTop,
              left: 0,
              right: 0,
              child: Center(child: IndexPill()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxPageWidth),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: kPagePadH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: kPagePadV + kMainPadTop),
                PortfolioHero(),
                SizedBox(height: kSectionGap),
                AboutSection(),
                SizedBox(height: kSectionGap),
                EducationSection(),
                SizedBox(height: kSectionGap),
                ContactSection(),
                SizedBox(height: kMainPadBottom + kPagePadV),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
