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
          data: MediaQueryData.fromView(tester.view)
              .copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
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
