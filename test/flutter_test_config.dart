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
