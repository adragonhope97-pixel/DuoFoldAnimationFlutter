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
