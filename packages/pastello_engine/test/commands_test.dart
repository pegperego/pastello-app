import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

StrokeElement horizontal(double y) => StrokeElement(
  id: newElementId(),
  tool: StrokeTool.crayon,
  color: const Color(0xFFE63946),
  width: 8,
  points: [SheetPoint(0, y), SheetPoint(100, y)],
);

void main() {
  const empty = Drawing(sheetSize: Size(400, 300));

  test('add, undo and redo a stroke', () {
    final stack = CommandStack(empty);
    final s = horizontal(10);
    stack.execute(AddElementCommand(s));
    expect(stack.drawing.elements, [s]);
    expect(stack.canUndo, isTrue);

    expect(stack.undo(), isTrue);
    expect(stack.drawing.isEmpty, isTrue);
    expect(stack.canRedo, isTrue);

    expect(stack.redo(), isTrue);
    expect(stack.drawing.elements, [s]);
  });

  test('undo and redo on empty stacks do nothing', () {
    final stack = CommandStack(empty);
    expect(stack.undo(), isFalse);
    expect(stack.redo(), isFalse);
  });

  test('a new command clears the redo stack', () {
    final stack = CommandStack(empty)
      ..execute(AddElementCommand(horizontal(1)));
    stack.undo();
    stack.execute(AddElementCommand(horizontal(2)));
    expect(stack.canRedo, isFalse);
  });

  test('history is limited', () {
    final stack = CommandStack(empty, limit: 3);
    for (var i = 0; i < 5; i++) {
      stack.execute(AddElementCommand(horizontal(i.toDouble())));
    }
    var undone = 0;
    while (stack.undo()) {
      undone++;
    }
    expect(undone, 3);
    expect(stack.drawing.elements, hasLength(2));
  });

  group('erase', () {
    final top = horizontal(10);
    final bottom = horizontal(200);
    final drawing = empty.withElementAdded(top).withElementAdded(bottom);
    final eraserPath = [const SheetPoint(50, 0), const SheetPoint(50, 20)];

    test('attaches the erasure only to touched strokes', () {
      final command = EraseCommand.forDrawing(drawing, eraserPath, 6)!;
      expect(command.elementIds, {top.id});

      final erased = command.apply(drawing);
      expect((erased.elements[0] as StrokeElement).erasures, hasLength(1));
      expect((erased.elements[1] as StrokeElement).erasures, isEmpty);

      final restored = command.revert(erased);
      expect((restored.elements[0] as StrokeElement).erasures, isEmpty);
    });

    test('returns null when nothing is touched', () {
      final far = [const SheetPoint(300, 100), const SheetPoint(310, 100)];
      expect(EraseCommand.forDrawing(drawing, far, 6), isNull);
    });
  });

  test('clear is undoable', () {
    final s = horizontal(10);
    final stack = CommandStack(empty)..execute(AddElementCommand(s));
    stack.execute(ClearCommand(stack.drawing.elements));
    expect(stack.drawing.isEmpty, isTrue);
    stack.undo();
    expect(stack.drawing.elements, [s]);
  });
}
