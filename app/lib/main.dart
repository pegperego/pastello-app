import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app/app.dart';
import 'src/core/licenses.dart';
import 'src/core/settings/settings_providers.dart';
import 'src/core/settings/settings_repository.dart';
import 'src/features/backup/application/backup_providers.dart';
import 'src/features/backup/data/drawing_backup.dart';
import 'src/features/drawings/application/drawings_providers.dart';
import 'src/features/drawings/data/drawing_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  final directory = await getApplicationSupportDirectory();
  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          FileSettingsRepository(directory),
        ),
        drawingRepositoryProvider.overrideWithValue(
          FileDrawingRepository(directory),
        ),
        drawingBackupProvider.overrideWithValue(DrawingBackup(directory)),
      ],
      child: const PastelloApp(),
    ),
  );
}
