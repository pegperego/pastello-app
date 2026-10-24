import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app/app.dart';
import 'src/core/licenses.dart';
import 'src/core/settings/settings_providers.dart';
import 'src/core/settings/settings_repository.dart';

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
      ],
      child: const PastelloApp(),
    ),
  );
}
