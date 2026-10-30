import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello/src/features/editor/presentation/selection_overlay.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';
import 'package:pastello/src/features/editor/presentation/text_edit_panel.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

Future<ProviderContainer> openTextTool(WidgetTester tester) async {
  tester.view.devicePixelRatio = 2.25;
  tester.view.physicalSize = const Size(2560, 1600);
  addTearDown(tester.view.reset);
  await pumpApp(tester);
  await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
  await pumpFrames(tester);
  await tester.tap(find.bySemanticsLabel('Testo'));
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(EditorPage)));
}

TextElement text(ProviderContainer c) =>
    c.read(editorProvider).drawing!.elements.whereType<TextElement>().single;

Future<void> typeNewText(WidgetTester tester, String value) async {
  await tester.tapAt(tester.getCenter(find.byType(SheetView)));
  await tester.pump();
  expect(find.byType(TextEditPanel), findsOneWidget);
  await tester.enterText(find.byType(TextField), value);
  await tester.tap(find.byTooltip('Fatto'));
  await tester.pump();
}

void main() {
  setUpAll(loadTestPacks);

  testWidgets('write a text, then edit it', (tester) async {
    final c = await openTextTool(tester);
    // No widths for the text tool.
    expect(find.bySemanticsLabel('Sottile'), findsNothing);

    await typeNewText(tester, 'Ciao nonna!');
    expect(find.byType(TextEditPanel), findsNothing);
    expect(text(c).text, 'Ciao nonna!');
    expect(find.byType(ElementSelectionOverlay), findsOneWidget);

    // Incognito keyboard (ADR 0013).
    await tester.tap(find.byTooltip('Modifica il testo'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.controller!.text, 'Ciao nonna!');
    await tester.enterText(find.byType(TextField), 'Ciao mamma!');
    await tester.tap(find.byTooltip('Fatto'));
    await tester.pump();
    expect(text(c).text, 'Ciao mamma!');
  });

  testWidgets('move with the frame, then delete', (tester) async {
    final c = await openTextTool(tester);
    await typeNewText(tester, 'Ciao');
    final before = text(c).transform.translation;

    final frame = find.descendant(
      of: find.byType(ElementSelectionOverlay),
      matching: find.byType(CustomPaint),
    );
    await tester.timedDrag(
      frame.first,
      const Offset(120, 60),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    final after = text(c).transform.translation;
    expect(after.dx, greaterThan(before.dx + 20));
    expect(after.dy, greaterThan(before.dy + 10));

    // Resize with the corner handle.
    await tester.timedDrag(
      find.bySemanticsLabel('Ingrandisci o rimpicciolisci'),
      const Offset(80, 40),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(text(c).transform.scale, greaterThan(1));

    // Rotate with the round handle.
    await tester.timedDrag(
      find.bySemanticsLabel('Ruota'),
      const Offset(120, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(text(c).transform.rotation, isNot(0));

    await tester.tap(find.byTooltip('Elimina'));
    await tester.pump();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
    expect(find.byType(ElementSelectionOverlay), findsNothing);
  });

  testWidgets('choose a font and a color for the selected text', (
    tester,
  ) async {
    final c = await openTextTool(tester);
    await typeNewText(tester, 'Ciao');

    await tester.tap(find.byTooltip('Carattere'));
    await pumpFrames(tester);
    expect(find.text('Ciao'), findsNWidgets(TextFont.values.length));
    await tester.tap(find.bySemanticsLabel(RegExp('^Fredoka')));
    await pumpFrames(tester);
    expect(text(c).font, TextFont.fredoka);

    await tester.tap(find.bySemanticsLabel('Colore').at(6));
    await tester.pump();
    expect(text(c).color, c.read(editorProvider).color);

    // Drawing tools draw over texts instead of selecting them.
    await tester.tap(find.bySemanticsLabel('Gomma'));
    await tester.pump();
    expect(find.byType(ElementSelectionOverlay), findsNothing);
  });

  testWidgets('choose a sticker in the panel and place it', (tester) async {
    final c = await openTextTool(tester);
    await tester.tap(find.bySemanticsLabel('Adesivi'));
    await pumpFrames(tester);
    expect(find.text('Scegli un adesivo'), findsOneWidget);
    // One tab per category.
    expect(find.byType(Tab), findsNWidgets(8));
    await tester.tap(find.bySemanticsLabel('Cibo'));
    await pumpFrames(tester);
    await tester.tap(find.bySemanticsLabel('Pizza'));
    await pumpFrames(tester);
    expect(find.text('Scegli un adesivo'), findsNothing);

    await tester.tapAt(tester.getCenter(find.byType(SheetView)));
    await tester.pump();
    final sticker = c
        .read(editorProvider)
        .drawing!
        .elements
        .whereType<StickerElement>()
        .single;
    expect(sticker.elementId, 'pizza');
    expect(find.byTooltip('Duplica'), findsOneWidget);
    // No text actions for a sticker.
    expect(find.byTooltip('Carattere'), findsNothing);
  });
}
