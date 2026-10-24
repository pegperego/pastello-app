import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/editor_tool.dart';
import 'package:pastello/src/features/editor/domain/palette.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

List<SheetPoint> line(double y) => [
  for (var x = 10.0; x <= 200; x += 10) SheetPoint(x, y, time: x.toInt()),
];

Future<ProviderContainer> container(MemorySettingsRepository settings) async {
  final c = ProviderContainer(overrides: testOverrides(settings));
  addTearDown(c.dispose);
  await c.read(settingsProvider.future);
  // Keep the auto-dispose editor alive for the whole test.
  c.listen(editorProvider, (_, _) {});
  return c;
}

void main() {
  test('starts from defaults, then from the saved settings', () async {
    var c = await container(MemorySettingsRepository());
    var state = c.read(editorProvider);
    expect(state.tool, EditorTool.crayon);
    expect(state.color, drawingColors.first);
    expect(state.widths[EditorTool.pencil], WidthPreset.thin);
    expect(state.drawing, isNull);

    c = await container(
      MemorySettingsRepository(
        const AppSettings(
          tool: 'brush',
          color: 0xFF1D4ED8,
          extraColor: 0xFF00C2A8,
          widths: {'brush': 'extraThick'},
        ),
      ),
    );
    state = c.read(editorProvider);
    expect(state.tool, EditorTool.brush);
    expect(state.color, const Color(0xFF1D4ED8));
    expect(state.extraColor, const Color(0xFF00C2A8));
    expect(state.width, WidthPreset.extraThick.width);
  });

  test('tool, color and widths are remembered', () async {
    final settings = MemorySettingsRepository();
    final c = await container(settings);
    final editor = c.read(editorProvider.notifier);

    editor.selectTool(EditorTool.marker);
    editor.selectWidth(WidthPreset.extraThick);
    editor.selectTool(EditorTool.pencil);
    expect(c.read(editorProvider).width, WidthPreset.thin.width);
    editor.selectTool(EditorTool.marker);
    expect(c.read(editorProvider).width, WidthPreset.extraThick.width);

    editor.selectColor(moreColors[3]);
    expect(c.read(editorProvider).extraColor, moreColors[3]);
    editor.selectColor(drawingColors[2]);
    expect(c.read(editorProvider).extraColor, moreColors[3]);

    await Future<void>.delayed(Duration.zero);
    expect(settings.saved.tool, 'marker');
    expect(settings.saved.widths['marker'], 'extraThick');
    expect(settings.saved.color, drawingColors[2].toARGB32());
    expect(settings.saved.extraColor, moreColors[3].toARGB32());
  });

  test('strokes, erasing, undo, redo and clear', () async {
    final c = await container(MemorySettingsRepository());
    final editor = c.read(editorProvider.notifier)
      ..ensureSheet(const Size(400, 300))
      ..commitStroke(line(50))
      ..commitStroke(line(150));
    var state = c.read(editorProvider);
    expect(state.drawing!.elements, hasLength(2));
    expect(state.canUndo, isTrue);

    editor
      ..selectTool(EditorTool.eraser)
      ..commitStroke([const SheetPoint(100, 0), const SheetPoint(100, 300)]);
    state = c.read(editorProvider);
    expect(state.lastErasure, isNotNull);
    expect(state.drawing!.elements.every((e) => e.erasures.isNotEmpty), isTrue);

    // An eraser pass that touches nothing is not recorded.
    final revision = state.revision;
    editor.commitStroke([const SheetPoint(390, 290)]);
    expect(c.read(editorProvider).revision, revision);

    editor.undo();
    expect(c.read(editorProvider).lastErasure, isNull);
    expect(c.read(editorProvider).canRedo, isTrue);
    editor.redo();
    editor.clear();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
    editor.undo();
    expect(c.read(editorProvider).drawing!.elements, hasLength(2));
  });

  test(
    'an empty sheet follows the screen, a drawn one keeps its shape',
    () async {
      final c = await container(MemorySettingsRepository());
      final editor = c.read(editorProvider.notifier)
        ..ensureSheet(Size.zero)
        ..ensureSheet(const Size(300, 500));
      expect(c.read(editorProvider).drawing!.sheetSize, const Size(300, 500));

      editor.ensureSheet(const Size(500, 300));
      expect(c.read(editorProvider).drawing!.sheetSize, const Size(500, 300));

      editor
        ..commitStroke(line(50))
        ..ensureSheet(const Size(300, 500));
      expect(c.read(editorProvider).drawing!.sheetSize, const Size(500, 300));

      // Cleared, but undoable: still keeps its shape.
      editor
        ..clear()
        ..ensureSheet(const Size(300, 500));
      expect(c.read(editorProvider).drawing!.sheetSize, const Size(500, 300));
    },
  );

  test('nothing happens before the sheet exists', () async {
    final c = await container(MemorySettingsRepository());
    c.read(editorProvider.notifier)
      ..commitStroke(line(10))
      ..undo()
      ..redo()
      ..clear();
    expect(c.read(editorProvider).drawing, isNull);
  });
}
