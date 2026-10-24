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
    ]) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString(file));
    }
  });
}
