import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/palette.dart';
import 'package:pastello/src/features/editor/presentation/editor_buttons.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

void main() {
  test('changing the paper is undoable and keeps the drawing', () async {
    final c = ProviderContainer(
      overrides: testOverrides(MemorySettingsRepository()),
    );
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    c.listen(editorProvider, (_, _) {});
    final editor = c.read(editorProvider.notifier)
      ..changeBackground(SheetBackground.white)
      ..ensureSheet(const Size(800, 500))
      ..commitStroke(const [SheetPoint(10, 10), SheetPoint(100, 100)]);
    const squares = SheetBackground(pattern: BackgroundPattern.bigSquares);
    editor
      ..changeBackground(squares)
      ..changeBackground(squares);
    final drawing = c.read(editorProvider).drawing!;
    expect(drawing.background, squares);
    expect(drawing.elements, hasLength(1));
    editor.undo();
    expect(c.read(editorProvider).drawing!.background, SheetBackground.white);
    editor.undo();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
  });

  testWidgets('choose lined yellow paper from the action bar', (tester) async {
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(EditorPage)),
    );

    await tester.tap(find.byTooltip('Tipo di foglio'));
    await pumpFrames(tester);
    expect(find.text('Colore del foglio'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Righe'));
    await tester.pump();
    await tester.tap(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(ColorSwatchButton),
          )
          .at(1),
    );
    await tester.pump();
    final bg = c.read(editorProvider).drawing!.background;
    expect(
      bg,
      SheetBackground(pattern: BackgroundPattern.lines, color: paperColors[1]),
    );
  });
}
