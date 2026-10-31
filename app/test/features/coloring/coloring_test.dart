import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/coloring/application/coloring_providers.dart';
import 'package:pastello/src/features/coloring/presentation/coloring_picker_page.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello/src/features/stickers/data/bundled_packs.dart';
import 'package:pastello/src/features/stickers/domain/sticker_pack.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';
import '../editor/editor_page_test.dart' show drawStroke;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestPacks);

  test('the bundled coloring pages: CC0, simple SVGs, every file '
      'present', () async {
    final packs = [
      for (final pack in await loadBundledPacks(rootBundle))
        if (pack.kind == PackKind.coloring) pack,
    ];
    // Animals, vehicles, nature, parties: about 20 pages (D-12).
    expect(packs, hasLength(4));
    expect(
      packs.fold<int>(0, (n, p) => n + p.items.length),
      greaterThanOrEqualTo(20),
    );
    for (final pack in packs) {
      expect(pack.license, 'CC0-1.0');
      for (final item in pack.items) {
        expect(item.asset, contains('/coloring/'));
        final svg = File(item.asset).readAsStringSync();
        // Outlines only: no embedded images, filters or text.
        for (final tag in ['<image', '<filter', '<text', '<foreignObject']) {
          expect(svg, isNot(contains(tag)), reason: '${item.asset}: $tag');
        }
      }
    }
  });

  test('packs of an unknown kind are left out', () {
    expect(packKind(const {}), PackKind.stickers);
    expect(packKind(const {'kind': 'coloring'}), PackKind.coloring);
    expect(packKind(const {'kind': 'backgrounds'}), isNull);
  });

  testWidgets('the artwork of every coloring page loads', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final artwork = (await tester.runAsync(
      () => c.read(coloringArtworkProvider.future),
    ))!;
    final star = artwork.pageFor(
      const ColoringOutline(packId: 'pastello-party', pageId: 'star'),
    );
    expect(star, isNotNull);
    expect(star!.size, const Size(800, 800));
    expect(
      artwork.pageFor(
        const ColoringOutline(packId: 'pastello-party', pageId: 'nope'),
      ),
      isNull,
    );
  });

  testWidgets('pick a coloring page from the gallery and color it (F-19)', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    final drawings = MemoryDrawingRepository();
    await pumpApp(tester, drawings: drawings);

    await tester.tap(find.bySemanticsLabel('Da colorare'));
    await tester.pumpAndSettle();
    expect(find.byType(ColoringPickerPage), findsOneWidget);
    expect(find.text('Scegli un disegno da colorare'), findsOneWidget);
    // One tab per category.
    await tester.tap(find.text('Natura'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('House'));
    await pumpFrames(tester);

    final c = ProviderScope.containerOf(
      tester.element(find.byType(EditorPage)),
    );
    const house = ColoringOutline(packId: 'pastello-nature', pageId: 'house');
    expect(c.read(editorProvider).drawing!.outline, house);

    // The outline stays when the sheet is cleared or a stroke undone.
    await drawStroke(tester);
    final controller = c.read(editorProvider.notifier)..undo();
    expect(c.read(editorProvider).drawing!.outline, house);
    controller.redo();

    // Saved with the drawing.
    await tester.tap(find.byTooltip('Torna alla galleria'));
    await pumpFrames(tester);
    final saved = drawings.drawings.values.single.$1.drawing;
    expect(saved.outline, house);
    expect(saved.elements, hasLength(1));
  });

  testWidgets('back from the coloring pages, no drawing is made', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    final drawings = MemoryDrawingRepository();
    await pumpApp(tester, drawings: drawings);
    await tester.tap(find.bySemanticsLabel('Da colorare'));
    await tester.pumpAndSettle();
    expect(find.byType(ColoringPickerPage), findsOneWidget);
    // The system back, as on Android.
    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    expect(find.byType(EditorPage), findsNothing);
    expect(drawings.drawings, isEmpty);
  });
}
