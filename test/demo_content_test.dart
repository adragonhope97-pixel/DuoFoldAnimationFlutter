import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_content.dart';
import 'package:iphoneduo_animation_flutter/demo/demo_sections.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_dock.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_hero.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_icons.dart';
import 'package:iphoneduo_animation_flutter/demo/portfolio_index_pill.dart';
import 'package:iphoneduo_animation_flutter/demo/svg_path.dart';

/// The portfolio screen (007), rendered as a static screen: wallpaper for
/// the fold shader to sample, not a working page (scope change communicated
/// mid-implementation; see the plan's `## Implementation report`). The old
/// scroll-progress and section-jump-menu assertions were deleted with the
/// behaviour they tested; the layout and geometry assertions stay.
///
/// The Geist faces are registered for every suite by
/// `test/flutter_test_config.dart`, so widths here are the shipped ones and
/// the 190 pt Index pill does not overflow.
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
  testWidgets('renders the hero, the sections and the chrome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_fixture());
    await tester.pump();

    // The NBSP is load-bearing: it binds the emoji to the name. Written as
    // an escape so it cannot be normalised away, and asserted here so that
    // if it is, this case fails instead of the device render.
    expect(find.text("Hi! I'm Debojyoti\u00A0👋"), findsOneWidget);
    expect(
      find.text(
        'I build beautiful mobile apps with design, code, and just enough '
        'caffeine. ☕️',
      ),
      findsOneWidget,
    );
    // Static subheading: the screenshot's phrase, no cycling.
    expect(find.byType(HeroSubheading), findsOneWidget);

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Education'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
    expect(find.byType(EducationCard), findsNWidgets(2));
    expect(find.text('Techno International New Town, Kolkata'), findsOneWidget);
    expect(find.text('2010 - 2022'), findsOneWidget);

    // Index pill: rendered in its settled, collapsed state only.
    expect(find.byType(IndexPill), findsOneWidget);
    expect(find.text('Index'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    expect(find.byType(PortfolioDock), findsOneWidget);
    expect(find.byType(SvgIcon), findsNWidgets(6));
  });

  testWidgets('the screen does not scroll', (WidgetTester tester) async {
    await tester.pumpWidget(_fixture());
    await tester.pump();

    final SingleChildScrollView scrollView = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());

    // Dragging does not move the content or change the static badge.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(find.text('0%'), findsOneWidget);
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
