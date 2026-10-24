import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/app/app.dart';

/// Pumps the whole app in [locale], with optional provider [overrides].
Future<void> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('it'),
  List<Override> overrides = const [],
  bool disableAnimations = false,
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.accessibilityFeaturesTestValue = disableAnimations
      ? const FakeAccessibilityFeatures(disableAnimations: true)
      : const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const PastelloApp()),
  );
  await tester.pump();
}

/// Pumps a second of frames: enough for page transitions to finish.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
