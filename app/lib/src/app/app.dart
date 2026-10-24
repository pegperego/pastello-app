import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/gallery/presentation/gallery_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'theme.dart';

/// The root widget. The app opens on the gallery (F-01).
class PastelloApp extends StatelessWidget {
  const PastelloApp({super.key});

  @override
  Widget build(BuildContext context) {
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
