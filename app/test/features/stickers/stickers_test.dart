import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/editor_tool.dart';
import 'package:pastello/src/features/stickers/application/stickers_providers.dart';
import 'package:pastello/src/features/stickers/data/bundled_packs.dart';
import 'package:pastello/src/features/stickers/domain/sticker_pack.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled packs: 8 categories, every file present', () async {
    final packs = [
      for (final pack in await loadBundledPacks(rootBundle))
        if (pack.kind == PackKind.stickers) pack,
    ];
    expect(packs, hasLength(8));
    expect(packs.first.title('it'), 'Animali');
    expect(packs.first.title('en'), 'Animals');
    expect(packs.first.title('fr'), 'Animals');
    final ids = <String>{};
    var count = 0;
    for (final pack in packs) {
      expect(pack.license, 'MIT');
      expect(pack.items, contains(pack.icon));
      for (final item in pack.items) {
        count++;
        expect(ids.add('${pack.id}/${item.id}'), isTrue);
        expect(File(item.asset).existsSync(), isTrue, reason: item.asset);
      }
    }
    expect(count, greaterThanOrEqualTo(150));
  });

  test('a pack without icon uses its first item', () {
    final pack = parsePack({
      'id': 'p',
      'version': 1,
      'title': {'it': 'Prova'},
      'author': 'me',
      'license': 'MIT',
      'items': [
        {'id': 'a', 'file': 'stickers/a.svg', 'name': 'A'},
      ],
    }, 'assets/packs/p');
    expect(pack.icon.id, 'a');
    expect(pack.icon.asset, 'assets/packs/p/stickers/a.svg');
    expect(pack.title('en'), 'p');
  });

  testWidgets('the artwork of every sticker loads', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final artwork = (await tester.runAsync(
      () => container.read(stickerArtworkProvider.future),
    ))!;
    expect(artwork.size, PackArtwork.pictureSize);
    expect(artwork.pictureFor('fluent-animals', 'dog_face'), isNotNull);
    expect(artwork.pictureFor('fluent-animals', 'nope'), isNull);
  });

  group('editor', () {
    Future<(ProviderContainer, EditorController)> stickerEditor() async {
      final c = ProviderContainer(
        overrides: testOverrides(MemorySettingsRepository()),
      );
      addTearDown(c.dispose);
      await c.read(settingsProvider.future);
      c.listen(editorProvider, (_, _) {});
      final editor = c.read(editorProvider.notifier)
        ..ensureSheet(const Size(800, 500))
        ..selectTool(EditorTool.stickers);
      return (c, editor);
    }

    List<StickerElement> stickers(ProviderContainer c) => c
        .read(editorProvider)
        .drawing!
        .elements
        .whereType<StickerElement>()
        .toList();

    test('choose, place, select, duplicate, delete, undo', () async {
      final (c, editor) = await stickerEditor();
      // Nothing chosen yet: a tap does nothing.
      editor.tapSheet(const Offset(200, 200));
      expect(c.read(editorProvider).drawing!.isEmpty, isTrue);

      editor
        ..chooseSticker(const StickerChoice('fluent-animals', 'dog_face'))
        ..tapSheet(const Offset(200, 200));
      expect(stickers(c).single.elementId, 'dog_face');
      expect(stickers(c).single.transform.translation, const Offset(200, 200));
      expect(c.read(editorProvider).selectedId, stickers(c).single.id);

      // A tap elsewhere deselects; the next one places another sticker.
      editor
        ..tapSheet(const Offset(600, 400))
        ..tapSheet(const Offset(600, 400));
      expect(stickers(c), hasLength(2));

      editor
        ..tapSheet(const Offset(205, 205))
        ..duplicateSelected();
      expect(stickers(c), hasLength(3));
      expect(
        stickers(c).last.transform.translation,
        const Offset(200, 200) + duplicateOffset,
      );
      expect(c.read(editorProvider).selectedId, stickers(c).last.id);

      editor.deleteSelected();
      expect(stickers(c), hasLength(2));
      editor.undo();
      expect(stickers(c), hasLength(3));
      expect(const StickerChoice('a', 'b'), const StickerChoice('a', 'b'));
      expect(
        const StickerChoice('a', 'b').hashCode,
        const StickerChoice('a', 'b').hashCode,
      );
    });

    test(
      'the Text tool selects stickers too, without creating texts',
      () async {
        final (c, editor) = await stickerEditor();
        editor
          ..chooseSticker(const StickerChoice('fluent-food', 'pizza'))
          ..tapSheet(const Offset(300, 300))
          ..selectTool(EditorTool.text)
          ..tapSheet(const Offset(300, 300));
        expect(c.read(editorProvider).editing, isNull);
        expect(c.read(editorProvider).selected, isA<StickerElement>());
      },
    );
  });
}
