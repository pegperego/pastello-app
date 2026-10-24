import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/feedback/feedback.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/editor_tool.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';

import '../helpers.dart';

void main() {
  late List<String> haptics;
  setUp(() => haptics = []);

  void mockHaptics(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add('tick');
        return null;
      },
    );
  }

  test('sounds and vibration follow the settings', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    var settings = const AppSettings();
    final played = <AppSound>[];
    final feedback = Feedback(() => settings, (s) async => played.add(s));
    await feedback.sound(AppSound.pop);
    settings = settings.copyWith(sounds: false);
    await feedback.sound(AppSound.ding);
    expect(played, [AppSound.pop]);
    expect(AppSound.ding.asset, 'sounds/ding.wav');
  });

  testWidgets('a sticker pops, deleting whooshes, a tool change ticks', (
    tester,
  ) async {
    mockHaptics(tester);
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(EditorPage)),
    );
    final editor = c.read(editorProvider.notifier);

    editor
      ..selectTool(EditorTool.stickers)
      ..chooseSticker(const StickerChoice('fluent-food', 'pizza'));
    await tester.pump();
    expect(haptics, ['tick']);
    final center = tester.getCenter(find.byType(SheetView));
    await tester.tapAt(center);
    await tester.pump();
    expect(playedSounds, [AppSound.pop]);

    await tester.tap(find.byTooltip('Elimina'));
    await tester.pump();
    expect(playedSounds, [AppSound.pop, AppSound.whoosh]);
  });

  testWidgets('saving to the gallery dings, unless sounds are off', (
    tester,
  ) async {
    final drawings = MemoryDrawingRepository()..add('a', testNow);
    final settings = MemorySettingsRepository();
    await pumpApp(tester, drawings: drawings, settings: settings);
    await tester.pump();
    await tester.tap(find.byTooltip('Opzioni del disegno'));
    await pumpFrames(tester);
    await tester.tap(find.text('Salva nella galleria'));
    await pumpFrames(tester);
    expect(playedSounds, [AppSound.ding]);

    final container = ProviderScope.containerOf(
      tester.element(find.text('Pastello')),
    );
    await container
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(sounds: false));
    await tester.tap(find.byTooltip('Opzioni del disegno'));
    await pumpFrames(tester);
    await tester.tap(find.text('Elimina'));
    await pumpFrames(tester);
    expect(playedSounds, [AppSound.ding]);
  });
}
