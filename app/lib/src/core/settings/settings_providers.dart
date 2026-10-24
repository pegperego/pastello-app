import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

/// Where settings are stored. Provided in `main` (and by tests).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('Override settingsRepositoryProvider'),
);

/// The current settings.
final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Reads and updates [AppSettings], saving every change.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  /// Applies [change] to the current settings and saves the result.
  Future<void> change(AppSettings Function(AppSettings) change) async {
    final next = change(state.value ?? const AppSettings());
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

/// Applies an orientation lock to the system. Replaced in tests.
final orientationSetterProvider =
    Provider<Future<void> Function(List<DeviceOrientation>)>(
      (ref) => SystemChrome.setPreferredOrientations,
    );

/// The system orientations allowed by [lock].
List<DeviceOrientation> orientationsFor(LockedOrientation? lock) =>
    switch (lock) {
      null => const [],
      LockedOrientation.landscape => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      LockedOrientation.portrait => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    };
