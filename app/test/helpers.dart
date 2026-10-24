import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pastello/src/app/app.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/core/settings/settings_repository.dart';

/// Settings kept in memory, for tests.
class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this.saved = const AppSettings()]);

  AppSettings saved;

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

/// Records the orientations requested by the rotation lock.
final requestedOrientations = <List<DeviceOrientation>>[];

/// Overrides every provider that touches the platform.
List<Override> testOverrides(MemorySettingsRepository settings) => [
  settingsRepositoryProvider.overrideWithValue(settings),
  orientationSetterProvider.overrideWithValue((orientations) async {
    requestedOrientations.add(orientations);
  }),
];

/// Pumps the whole app in [locale], with optional provider [overrides].
Future<void> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('it'),
  List<Override> overrides = const [],
  MemorySettingsRepository? settings,
  bool disableAnimations = false,
}) async {
  requestedOrientations.clear();
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.accessibilityFeaturesTestValue = disableAnimations
      ? const FakeAccessibilityFeatures(disableAnimations: true)
      : const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  // Start from an empty tree, so a second call does not keep the previous
  // app's navigation stack.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(settings ?? MemorySettingsRepository()),
        ...overrides,
      ],
      child: const PastelloApp(),
    ),
  );
  await tester.pump();
}

/// Pumps a second of frames: enough for page transitions to finish.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
