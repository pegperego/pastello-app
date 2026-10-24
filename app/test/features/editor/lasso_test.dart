import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/features/editor/application/editor_controller.dart';
import 'package:pastello/src/features/editor/domain/editor_tool.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello/src/features/editor/presentation/selection_overlay.dart';
import 'package:pastello/src/features/editor/presentation/sheet_view.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../helpers.dart';

List<SheetPoint> line(double x, double y) => [
  SheetPoint(x, y),
  SheetPoint(x + 40, y),
  SheetPoint(x + 80, y),
];

/// A closed square lasso around [rect].
void drawLasso(EditorController editor, Rect rect) {
  editor
    ..beginLasso(rect.topLeft)
    ..updateLasso(rect.topRight)
    ..updateLasso(rect.bottomRight)
    ..updateLasso(rect.bottomLeft)
    ..endLasso();
}

void main() {
  group('controller', () {
    Future<(ProviderContainer, EditorController)> editorWithStrokes() async {
      final c = ProviderContainer(
        overrides: testOverrides(MemorySettingsRepository()),
      );
      addTearDown(c.dispose);
      await c.read(settingsProvider.future);
      c.listen(editorProvider, (_, _) {});
      final editor = c.read(editorProvider.notifier)
        ..ensureSheet(const Size(800, 500))
        ..commitStroke(line(100, 100))
        ..commitStroke(line(100, 200))
        ..commitStroke(line(500, 400))
        ..selectTool(EditorTool.select);
      return (c, editor);
    }

    test('the lasso selects a group; one undo for each change', () async {
      final (c, editor) = await editorWithStrokes();
      drawLasso(editor, const Rect.fromLTRB(50, 50, 300, 300));
      var state = c.read(editorProvider);
      expect(state.lasso, isNull);
      expect(state.groupIds, hasLength(2));
      expect(state.groupBox!.center.dx, closeTo(140, 6));

      // Rotate the group by 90° around its center and move it.
      final frame = state.groupFrame!;
      editor.previewGroup(
        frame.copyWith(
          translation: frame.translation + const Offset(100, 0),
          rotation: math.pi / 2,
        ),
      );
      expect(c.read(editorProvider).floating, hasLength(2));
      editor.commitGroup();
      state = c.read(editorProvider);
      expect(state.floating, isEmpty);
      expect(state.groupIds, hasLength(2));
      final moved = state.drawing!.elements.first;
      expect(moved.transform.rotation, closeTo(math.pi / 2, 1e-9));
      // Rotated strokes now stand vertically.
      expect(moved.bounds.height, greaterThan(moved.bounds.width));

      editor.duplicateGroup();
      expect(c.read(editorProvider).drawing!.elements, hasLength(5));
      expect(c.read(editorProvider).groupIds, hasLength(2));
      editor.deleteGroup();
      expect(c.read(editorProvider).drawing!.elements, hasLength(3));
      expect(c.read(editorProvider).groupIds, isEmpty);
      editor.undo();
      expect(c.read(editorProvider).drawing!.elements, hasLength(5));
      editor
        ..undo()
        ..undo();
      // Undo clears the selection; the rotation is undone in one step.
      expect(c.read(editorProvider).groupIds, isEmpty);
      expect(
        c.read(editorProvider).drawing!.elements.first.transform.isIdentity,
        isTrue,
      );
    });

    test(
      'a lasso around one element, a tap on a stroke, an empty lasso',
      () async {
        final (c, editor) = await editorWithStrokes();
        drawLasso(editor, const Rect.fromLTRB(450, 350, 650, 450));
        expect(c.read(editorProvider).selectedId, isNotNull);
        expect(c.read(editorProvider).groupIds, isEmpty);

        editor.tapSheet(const Offset(140, 200));
        expect(
          c.read(editorProvider).selected,
          c.read(editorProvider).drawing!.elements[1],
        );
        editor.tapSheet(const Offset(700, 50));
        expect(c.read(editorProvider).selectedId, isNull);

        drawLasso(editor, const Rect.fromLTRB(600, 10, 700, 60));
        expect(c.read(editorProvider).selectedId, isNull);
        expect(c.read(editorProvider).groupIds, isEmpty);
      },
    );

    test('erased parts follow a moved stroke', () async {
      final (c, editor) = await editorWithStrokes();
      editor
        ..selectTool(EditorTool.eraser)
        ..commitStroke([const SheetPoint(140, 80), const SheetPoint(140, 120)])
        ..selectTool(EditorTool.select)
        ..tapSheet(const Offset(110, 100));
      final selected = c.read(editorProvider).selected! as StrokeElement;
      expect(selected.erasures, hasLength(1));
      editor
        ..previewTransform(
          selected.transform.copyWith(translation: const Offset(0, 50)),
        )
        ..commitTransform();
      final moved =
          c.read(editorProvider).drawing!.elementById(selected.id)!
              as StrokeElement;
      // The erasure is kept in the stroke's own coordinates.
      expect(moved.erasures.single.points.first.x, 140);
      expect(moved.transform.translation, const Offset(0, 50));
      // A new eraser pass on the moved stroke is mapped back to it.
      editor
        ..selectTool(EditorTool.eraser)
        ..commitStroke([
          const SheetPoint(170, 130),
          const SheetPoint(170, 170),
        ]);
      final erased =
          c.read(editorProvider).drawing!.elementById(selected.id)!
              as StrokeElement;
      expect(erased.erasures.last.points.first.y, closeTo(80, 1e-9));
    });

    test('changing tool clears the group', () async {
      final (c, editor) = await editorWithStrokes();
      drawLasso(editor, const Rect.fromLTRB(50, 50, 300, 300));
      editor.selectTool(EditorTool.crayon);
      expect(c.read(editorProvider).groupIds, isEmpty);
      // Group actions without a group do nothing.
      editor
        ..previewGroup(ElementTransform.identity)
        ..commitGroup()
        ..duplicateGroup()
        ..deleteGroup();
      expect(c.read(editorProvider).drawing!.elements, hasLength(3));
    });
  });

  testWidgets('draw a lasso on the sheet and move the group', (tester) async {
    tester.view.devicePixelRatio = 2.25;
    tester.view.physicalSize = const Size(2560, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await pumpFrames(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(EditorPage)),
    );

    final sheet = tester.getRect(find.byType(SheetView));
    // Two strokes in the upper left quarter of the sheet.
    for (final dy in [0.2, 0.3]) {
      await tester.timedDragFrom(
        sheet.topLeft + Offset(sheet.width * 0.1, sheet.height * dy),
        Offset(sheet.width * 0.2, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pump();
    }

    await tester.tap(find.bySemanticsLabel('Seleziona'));
    await tester.pump();
    final gesture = await tester.startGesture(
      sheet.topLeft + const Offset(10, 10),
    );
    for (final p in [
      Offset(sheet.width * 0.45, 10),
      Offset(sheet.width * 0.45, sheet.height * 0.45),
      Offset(10, sheet.height * 0.45),
      const Offset(10, 20),
    ]) {
      await gesture.moveTo(sheet.topLeft + p);
      await tester.pump();
      if (p.dx > 100) {
        expect(find.byType(CustomPaint), findsWidgets);
      }
    }
    await gesture.up();
    await tester.pump();
    expect(c.read(editorProvider).groupIds, hasLength(2));
    expect(find.byType(ElementSelectionOverlay), findsOneWidget);

    await tester.tap(find.byTooltip('Elimina'));
    await tester.pump();
    expect(c.read(editorProvider).drawing!.isEmpty, isTrue);
  });
}
