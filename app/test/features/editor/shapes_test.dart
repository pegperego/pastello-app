import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/editor_tool.dart';
import 'package:pastello/src/features/editor/domain/palette.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

List<ShapeElement> shapes(ProviderContainer c) =>
    c.read(editorProvider).drawing!.elements.whereType<ShapeElement>().toList();

void main() {
  group('controller', () {
    Future<(ProviderContainer, EditorController)> shapeEditor() async {
      final c = ProviderContainer(
        overrides: testOverrides(MemorySettingsRepository()),
      );
      addTearDown(c.dispose);
      await c.read(settingsProvider.future);
      c.listen(editorProvider, (_, _) {});
      final editor = c.read(editorProvider.notifier)
        ..ensureSheet(const Size(800, 500))
        ..selectTool(EditorTool.shapes);
      return (c, editor);
    }

    test('drag a shape: it follows the finger, snaps, then is added', () async {
      final (c, editor) = await shapeEditor();
      editor
        ..chooseShape(ShapeKind.star, filled: true)
        ..beginShape(const Offset(100, 100))
        ..updateShape(const Offset(200, 160));
      var state = c.read(editorProvider);
      expect(state.draft!.kind, ShapeKind.star);
      expect(state.floating, [state.draft]);
      expect(state.shapeSnapped, isFalse);
      expect(state.drawing!.isEmpty, isTrue);

      editor.updateShape(const Offset(200, 195));
      expect(c.read(editorProvider).shapeSnapped, isTrue);

      editor.endShape();
      state = c.read(editorProvider);
      expect(state.draft, isNull);
      expect(shapes(c).single.filled, isTrue);
      expect(shapes(c).single.extent, const Offset(100, 100));
      expect(state.selectedId, shapes(c).single.id);
      editor.undo();
      expect(shapes(c), isEmpty);
    });

    test('a tiny drag or a tap does not create a shape', () async {
      final (c, editor) = await shapeEditor();
      editor
        ..beginShape(const Offset(100, 100))
        ..updateShape(const Offset(102, 101))
        ..endShape()
        ..endShape();
      expect(shapes(c), isEmpty);
      expect(c.read(editorProvider).canUndo, isFalse);
      // Other tools do not draw shapes.
      editor
        ..selectTool(EditorTool.text)
        ..beginShape(const Offset(10, 10))
        ..updateShape(const Offset(300, 300));
      expect(c.read(editorProvider).draft, isNull);
    });

    test('color and width apply to the selected shape', () async {
      final (c, editor) = await shapeEditor();
      editor
        ..beginShape(const Offset(100, 100))
        ..updateShape(const Offset(300, 200))
        ..endShape()
        ..selectColor(drawingColors[4])
        ..selectWidth(WidthPreset.extraThick);
      expect(shapes(c).single.color, drawingColors[4]);
      expect(shapes(c).single.strokeWidth, WidthPreset.extraThick.width);
      editor
        ..undo()
        ..undo();
      expect(shapes(c).single.strokeWidth, WidthPreset.medium.width);

      // Tap elsewhere deselects, tap on the shape selects it again.
      editor.tapSheet(const Offset(700, 450));
      expect(c.read(editorProvider).selectedId, isNull);
      editor.tapSheet(const Offset(200, 150));
      expect(c.read(editorProvider).selectedId, shapes(c).single.id);
    });
  });

  testWidgets('the shapes panel, drawing by dragging, the snap tick', (
    tester,
  ) async {
    final haptics = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String?);
        }
        return null;
      },
    );
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(EditorPage)),
    );

    await tester.tap(find.bySemanticsLabel('Forme'));
    await pumpFrames(tester);
    expect(find.text('Scegli una forma'), findsOneWidget);
    await tester.tap(find.text('Piena'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Cuore'));
    await pumpFrames(tester);
    expect(c.read(editorProvider).shapeKind, ShapeKind.heart);
    expect(c.read(editorProvider).shapeFilled, isTrue);

    // Drag a nearly square box: the heart snaps and the tablet ticks.
    final center = tester.getCenter(find.byType(SheetView));
    final gesture = await tester.startGesture(center);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(center + Offset(i * 20.0, i * 19.0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    expect(shapes(c).single.kind, ShapeKind.heart);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
    expect(find.byTooltip('Duplica'), findsOneWidget);
  });
}
