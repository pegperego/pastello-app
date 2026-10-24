import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/settings_providers.dart';
import '../features/stickers/application/stickers_providers.dart';
import '../features/gallery/presentation/gallery_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'theme.dart';

/// The root widget. The app opens on the gallery (F-01).
class PastelloApp extends ConsumerWidget {
  const PastelloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The rotation lock applies to the whole app and survives restarts
    // (ADR 0002).
    ref.listen(
      settingsProvider.select((settings) => settings.value?.rotationLock),
      (_, lock) => ref.read(orientationSetterProvider)(orientationsFor(lock)),
    );
    // Sticker artwork is prepared in the background from the start, so it
    // is ready when the first sheet opens.
    ref.listen(stickerArtworkProvider, (_, _) {});
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Follows the system language, English as fallback (ADR 0013).
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GalleryPage(),
    );
  }
}
