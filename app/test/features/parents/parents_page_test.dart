import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/features/parents/application/parents_providers.dart';
import 'package:pastello/src/features/parents/presentation/parents_page.dart';

import '../../helpers.dart';
import '../gallery/gallery_page_test.dart' show solveGate;

Future<void> openParents(
  WidgetTester tester, {
  MemorySettingsRepository? settings,
  MemoryDrawingRepository? drawings,
}) async {
  tester.view.devicePixelRatio = 2.25;
  tester.view.physicalSize = const Size(2560, 1600);
  addTearDown(tester.view.reset);
  await pumpApp(tester, settings: settings, drawings: drawings);
  await tester.tap(find.byTooltip('Genitori'));
  await pumpFrames(tester);
  await solveGate(tester);
  expect(find.byType(ParentsPage), findsOneWidget);
}

/// Scrolls the parents' page until [finder] is on screen.
Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  testWidgets('the parents page is behind the gate', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Genitori'));
    await pumpFrames(tester);
    await tester.tap(find.text('Annulla'));
    await pumpFrames(tester);
    expect(find.byType(ParentsPage), findsNothing);
  });

  testWidgets('settings: language, left-handed, sounds, vibration', (
    tester,
  ) async {
    final settings = MemorySettingsRepository();
    await openParents(tester, settings: settings);

    await tester.tap(find.text('English'));
    await pumpFrames(tester);
    expect(settings.saved.language, 'en');
    // The app switches language right away.
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Same as the tablet'));
    await pumpFrames(tester);
    expect(settings.saved.language, isNull);

    await tester.tap(find.text('Mancina/o'));
    await tester.tap(find.text('Suoni'));
    await tester.tap(find.text('Vibrazione'));
    await tester.pump();
    expect(settings.saved.leftHanded, isTrue);
    expect(settings.saved.sounds, isFalse);
    expect(settings.saved.haptics, isFalse);
  });

  testWidgets('trash, about, links and credits', (tester) async {
    final drawings = MemoryDrawingRepository()..add('a', testNow);
    await drawings.moveToTrash('a');
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await openParents(tester, drawings: drawings);

    await scrollTo(tester, find.text('Svuota il cestino'));
    expect(find.text('1 disegno nel cestino'), findsOneWidget);
    await tester.tap(find.text('Svuota il cestino'));
    await tester.pump();
    expect(find.text('Il cestino è vuoto'), findsOneWidget);
    expect(drawings.trash, isEmpty);

    await scrollTo(tester, find.text('Versione 0.1.0 (1)'));
    expect(find.text('Versione 0.1.0 (1)'), findsOneWidget);
    expect(find.text('Xiaomi 2505DRP06E, Android 16'), findsOneWidget);
    await scrollTo(tester, find.text('Copia informazioni per la segnalazione'));
    await tester.tap(find.text('Copia informazioni per la segnalazione'));
    await tester.pump();
    expect(clipboard, contains('Android: 16'));

    await scrollTo(tester, find.text('Informativa privacy'));
    await tester.tap(find.text('Codice sorgente'));
    await tester.tap(find.text('Segnala un problema'));
    await tester.tap(find.text('Informativa privacy'));
    expect(openedLinks, [
      ProjectLinks.source,
      ProjectLinks.issues,
      ProjectLinks.privacy,
    ]);

    await scrollTo(tester, find.text('Crediti e licenze'));
    await tester.tap(find.text('Crediti e licenze'));
    await pumpFrames(tester);
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('settings remember language, sounds and vibration', () {
    const settings = AppSettings(language: 'it', sounds: false, haptics: false);
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.language, 'it');
    expect(restored.sounds, isFalse);
    expect(restored.haptics, isFalse);
    expect(AppSettings.fromJson({'language': 'fr'}).language, isNull);
    expect(const AppSettings().sounds, isTrue);
    expect(settings.copyWith(language: () => null).language, isNull);
    expect(
      const AppInfo(version: '1', device: 'd', android: '16').report,
      contains('Pastello 1'),
    );
  });
}
