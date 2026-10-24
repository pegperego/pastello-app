import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/editor_tool.dart';
import 'package:pastello/src/features/editor/domain/palette.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

Future<(ProviderContainer, EditorController)> textEditor() async {
  final c = ProviderContainer(
    overrides: testOverrides(MemorySettingsRepository()),
  );
  addTearDown(c.dispose);
  await c.read(settingsProvider.future);
  c.listen(editorProvider, (_, _) {});
  final editor = c.read(editorProvider.notifier)
    ..ensureSheet(const Size(800, 500))
    ..selectTool(EditorTool.text);
  return (c, editor);
}

TextElement onlyText(ProviderContainer c) =>
    c.read(editorProvider).drawing!.elements.whereType<TextElement>().single;

void main() {
  test('tap, type and confirm a new text; undo removes it', () async {
    final (c, editor) = await textEditor();
    editor.tapSheet(const Offset(300, 200));
    var state = c.read(editorProvider);
    expect(state.editing, isNotNull);
    expect(state.editingIsNew, isTrue);
    expect(state.floating, [state.editing]);
    expect(state.drawing!.isEmpty, isTrue);

    editor.updateText('Ciao nonna!');
    expect(c.read(editorProvider).editing!.text, 'Ciao nonna!');
    editor.commitText();
    state = c.read(editorProvider);
    expect(state.editing, isNull);
    expect(onlyText(c).text, 'Ciao nonna!');
    expect(onlyText(c).transform.translation, const Offset(300, 200));
    expect(state.selectedId, onlyText(c).id);
    expect(state.canUndo, isTrue);

    editor.undo();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
    expect(c.read(editorProvider).selectedId, isNull);
  });

  test('an empty new text is discarded', () async {
    final (c, editor) = await textEditor();
    editor
      ..tapSheet(const Offset(300, 200))
      ..updateText('   ')
      ..commitText();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
    expect(c.read(editorProvider).canUndo, isFalse);
  });

  test('taps select, deselect and start new texts', () async {
    final (c, editor) = await textEditor();
    editor
      ..tapSheet(const Offset(300, 200))
      ..updateText('Ciao')
      ..commitText()
      ..tapSheet(const Offset(700, 450));
    expect(c.read(editorProvider).selectedId, isNull);

    editor.tapSheet(const Offset(302, 205));
    expect(c.read(editorProvider).selectedId, onlyText(c).id);

    // While typing, a tap on the sheet confirms the text.
    editor
      ..tapSheet(const Offset(700, 450))
      ..tapSheet(const Offset(700, 450));
    expect(c.read(editorProvider).editing, isNotNull);
    editor.tapSheet(const Offset(10, 10));
    expect(c.read(editorProvider).editing, isNull);
  });

  test('edit, empty to delete, restyle', () async {
    final (c, editor) = await textEditor();
    editor
      ..tapSheet(const Offset(300, 200))
      ..updateText('Ciao')
      ..commitText()
      ..editSelected();
    expect(c.read(editorProvider).editingIsNew, isFalse);
    editor
      ..updateText('Ciao mamma')
      ..commitText();
    expect(onlyText(c).text, 'Ciao mamma');
    editor.undo();
    expect(onlyText(c).text, 'Ciao');
    editor.redo();

    editor
      ..tapSheet(const Offset(300, 200))
      ..selectColor(drawingColors[6])
      ..selectFont(TextFont.fredoka);
    expect(onlyText(c).color, drawingColors[6]);
    expect(onlyText(c).font, TextFont.fredoka);
    // The next new text uses the chosen font.
    expect(c.read(editorProvider).textFont, TextFont.fredoka);

    editor
      ..editSelected()
      ..selectColor(drawingColors[0]);
    expect(c.read(editorProvider).editing!.color, drawingColors[0]);
    editor
      ..updateText('')
      ..commitText();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
    editor.undo();
    expect(onlyText(c).text, 'Ciao mamma');
  });

  test('move, resize and rotate are one undo step each', () async {
    final (c, editor) = await textEditor();
    editor
      ..tapSheet(const Offset(300, 200))
      ..updateText('Ciao')
      ..commitText();
    final original = onlyText(c).transform;

    editor
      ..previewTransform(original.copyWith(translation: const Offset(310, 200)))
      ..previewTransform(
        original.copyWith(translation: const Offset(400, 250)),
      );
    expect(c.read(editorProvider).preview, isNotNull);
    expect(
      c.read(editorProvider).selected!.transform.translation,
      const Offset(400, 250),
    );
    // The committed element did not move yet.
    expect(onlyText(c).transform, original);
    editor.commitTransform();
    expect(onlyText(c).transform.translation, const Offset(400, 250));

    editor
      ..previewTransform(
        onlyText(c).transform.copyWith(scale: 100, rotation: math.pi / 4),
      )
      ..commitTransform();
    expect(onlyText(c).transform.scale, maxElementScale);
    expect(onlyText(c).transform.rotation, math.pi / 4);

    editor.undo();
    expect(onlyText(c).transform.translation, const Offset(400, 250));
    expect(onlyText(c).transform.scale, 1);
    editor.undo();
    expect(onlyText(c).transform, original);

    // A gesture that ends where it started records nothing.
    final undoable = c.read(editorProvider).canRedo;
    editor
      ..tapSheet(const Offset(300, 200))
      ..previewTransform(onlyText(c).transform)
      ..commitTransform();
    expect(c.read(editorProvider).canRedo, undoable);
  });

  test('delete, deselect and leaving the text tool', () async {
    final (c, editor) = await textEditor();
    editor
      ..tapSheet(const Offset(300, 200))
      ..updateText('Ciao')
      ..commitText()
      ..deleteSelected();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
    editor.undo();

    editor
      ..tapSheet(const Offset(300, 200))
      ..deselect();
    expect(c.read(editorProvider).selectedId, isNull);

    editor
      ..tapSheet(const Offset(300, 200))
      ..editSelected()
      ..updateText('Ciao!')
      ..selectTool(EditorTool.crayon);
    final state = c.read(editorProvider);
    expect(state.editing, isNull);
    expect(state.selectedId, isNull);
    expect(onlyText(c).text, 'Ciao!');

    // Drawing tools do not select.
    editor.tapSheet(const Offset(300, 200));
    expect(c.read(editorProvider).selectedId, isNull);
  });

  test('saving commits the text being typed', () async {
    final drawings = MemoryDrawingRepository();
    final c = ProviderContainer(
      overrides: testOverrides(MemorySettingsRepository(), drawings),
    );
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    c.listen(editorProvider, (_, _) {});
    final editor = c.read(editorProvider.notifier)
      ..ensureSheet(const Size(800, 500))
      ..selectTool(EditorTool.text)
      ..tapSheet(const Offset(300, 200))
      ..updateText('Ciao');
    await editor.flush();
    final saved = drawings.drawings.values.single.$1.drawing;
    expect((saved.elements.single as TextElement).text, 'Ciao');
  });
}
