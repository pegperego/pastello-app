import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/licenses.dart';
import 'package:pastello/src/app/theme.dart';
import 'package:pastello/src/app/tokens.dart';

import '../helpers.dart';

void main() {
  testWidgets('follows the system language', (tester) async {
    await pumpApp(tester, locale: const Locale('it'));
    expect(find.bySemanticsLabel('Nuovo disegno'), findsOneWidget);

    await pumpApp(tester, locale: const Locale('en'));
    expect(find.bySemanticsLabel('New drawing'), findsOneWidget);
  });

  testWidgets('falls back to English for other languages', (tester) async {
    await pumpApp(tester, locale: const Locale('fr'));
    expect(find.bySemanticsLabel('New drawing'), findsOneWidget);
  });

  test('theme uses the design tokens', () {
    final theme = buildTheme();
    expect(theme.scaffoldBackgroundColor, Tokens.paper);
    expect(theme.colorScheme.primary, Tokens.coral);
    expect(theme.textTheme.headlineMedium!.fontFamily, 'Fredoka');
    expect(fredoka(20).fontVariations, [const FontVariation.weight(600)]);
  });

  testWidgets('bundled font licenses appear in the credits', (tester) async {
    registerBundledLicenses();
    final packages = await tester.runAsync(
      () async => {
        await for (final entry in LicenseRegistry.licenses) ...entry.packages,
      },
    );
    expect(packages, containsAll(['Andika', 'Fredoka']));
  });
}
