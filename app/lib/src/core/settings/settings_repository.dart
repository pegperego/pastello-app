import 'dart:convert';
import 'dart:io';

import '../storage/atomic_file.dart';
import 'app_settings.dart';

/// Loads and saves [AppSettings].
abstract interface class SettingsRepository {
  /// The saved settings, or defaults when there are none.
  Future<AppSettings> load();

  /// Saves [settings].
  Future<void> save(AppSettings settings);
}

/// Stores settings in `settings.json` in the app's private [directory]
/// (ADR 0014: no shared_preferences dependency).
class FileSettingsRepository implements SettingsRepository {
  FileSettingsRepository(Directory directory)
    : _file = File('${directory.path}/settings.json');

  final File _file;

  @override
  Future<AppSettings> load() async {
    try {
      final json = jsonDecode(await _file.readAsString());
      if (json is Map<String, Object?>) return AppSettings.fromJson(json);
    } on FileSystemException {
      // First launch: no settings yet.
    } on FormatException {
      // A corrupted file must never prevent the app from starting.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) =>
      writeFileAtomically(_file, jsonEncode(settings.toJson()));
}
