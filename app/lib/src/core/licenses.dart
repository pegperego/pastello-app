import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licenses of bundled assets to the app's license page.
///
/// Package licenses are collected by Flutter automatically; fonts and other
/// assets are not, so they are registered here (ADR 0014).
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in const [
      ('Andika', 'assets/fonts/Andika-OFL.txt'),
      ('Fredoka', 'assets/fonts/Fredoka-OFL.txt'),
      ('Playwrite IT Moderna', 'assets/fonts/PlaywriteITModerna-OFL.txt'),
      ('Comic Neue', 'assets/fonts/ComicNeue-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString(file));
    }
    // Stickers of the bundled content packs (F-11, ADR 0018).
    yield LicenseEntryWithLineBreaks([
      'Fluent Emoji (Microsoft)',
    ], await rootBundle.loadString('assets/packs/LICENSE-fluent-emoji.txt'));
  });
}
