import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

StrokeElement stroke(StrokeTool tool, double y) => StrokeElement(
  id: newElementId(),
  tool: tool,
  color: const Color(0xFF8E44AD),
  width: 12.5,
  points: [
    for (var x = 0; x <= 100; x += 25)
      SheetPoint(x.toDouble(), y + x / 3, pressure: 0.42, time: x * 4),
  ],
);

/// JSON text, as it is written to disk.
Map<String, Object?> roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  Drawing sample() {
    var drawing = const Drawing(sheetSize: Size(1137.5, 650));
    for (final (i, tool) in StrokeTool.values.indexed) {
      drawing = drawing.withElementAdded(stroke(tool, i * 40));
    }
    final erase = EraseCommand.forDrawing(drawing, [
      const SheetPoint(50, 0),
      const SheetPoint(50, 300),
    ], 20)!;
    return erase.apply(drawing);
  }

  test('a drawing survives a round trip through JSON text', () {
    final drawing = sample();
    final restored = drawingFromJson(roundTrip(drawingToJson(drawing)));
    expect(restored.sheetSize, drawing.sheetSize);
    expect(restored.elements, hasLength(drawing.elements.length));
    for (var i = 0; i < drawing.elements.length; i++) {
      final a = drawing.elements[i] as StrokeElement;
      final b = restored.elements[i] as StrokeElement;
      expect(b.id, a.id);
      expect(b.tool, a.tool);
      expect(b.color, a.color);
      expect(b.width, a.width);
      expect(b.points.length, a.points.length);
      expect(b.points.last.x, closeTo(a.points.last.x, 0.005));
      expect(b.points.last.y, closeTo(a.points.last.y, 0.005));
      expect(b.points.last.time, a.points.last.time);
      expect(b.erasures.map((e) => e.id), a.erasures.map((e) => e.id));
    }
  });

  test('commands survive a round trip and still undo after loading', () {
    final stack = CommandStack(const Drawing(sheetSize: Size(400, 300)));
    stack
      ..execute(AddElementCommand(stroke(StrokeTool.marker, 50)))
      ..execute(AddElementCommand(stroke(StrokeTool.crayon, 100)));
    final erase = EraseCommand.forDrawing(stack.drawing, [
      const SheetPoint(50, 0),
      const SheetPoint(50, 300),
    ], 20)!;
    stack
      ..execute(erase)
      ..execute(ClearCommand(stack.drawing.elements))
      ..undo();

    // Save and load everything, as the app does between sessions.
    final drawing = drawingFromJson(roundTrip(drawingToJson(stack.drawing)));
    List<DrawingCommand> load(List<DrawingCommand> commands) => [
      for (final c in commands) commandFromJson(roundTrip(commandToJson(c))),
    ];
    final restored = CommandStack(const Drawing(sheetSize: Size.zero))
      ..restore(drawing, load(stack.undoCommands), load(stack.redoCommands));

    expect(restored.canRedo, isTrue);
    expect(restored.undo(), isTrue); // the eraser pass
    expect(
      restored.drawing.elements.every(
        (e) => (e as StrokeElement).erasures.isEmpty,
      ),
      isTrue,
    );
    expect(restored.undo(), isTrue);
    expect(restored.undo(), isTrue);
    expect(restored.drawing.isEmpty, isTrue);
  });

  test('restore keeps at most `limit` undo steps', () {
    final commands = [
      for (var i = 0; i < 5; i++)
        AddElementCommand(stroke(StrokeTool.pencil, 0)),
    ];
    final stack = CommandStack(const Drawing(sheetSize: Size.zero), limit: 3)
      ..restore(const Drawing(sheetSize: Size.zero), commands, const []);
    expect(stack.undoCommands, hasLength(3));
  });

  group('rejects bad files', () {
    final valid = drawingToJson(sample());

    void rejects(Map<String, Object?> json) => expect(
      () => drawingFromJson(roundTrip(json)),
      throwsA(isA<DrawingFormatException>()),
    );

    test('missing or newer schema', () {
      rejects({...valid, 'schemaVersion': null});
      rejects({...valid, 'schemaVersion': drawingSchemaVersion + 1});
    });

    test('malformed content', () {
      rejects({...valid, 'sheet': 'big'});
      rejects({
        ...valid,
        'elements': [
          {'type': 'hologram'},
        ],
      });
      rejects({
        ...valid,
        'elements': [
          {...strokeToJson(stroke(StrokeTool.brush, 0)), 'tool': 'laser'},
        ],
      });
      rejects({
        ...valid,
        'elements': [
          {
            ...strokeToJson(stroke(StrokeTool.brush, 0)),
            'points': [1, 2, 3],
          },
        ],
      });
      rejects({
        ...valid,
        'elements': [
          {...strokeToJson(stroke(StrokeTool.brush, 0)), 'id': 7},
        ],
      });
      rejects({
        ...valid,
        'elements': [
          {...strokeToJson(stroke(StrokeTool.brush, 0)), 'color': 'red'},
        ],
      });
      expect(
        () => commandFromJson({'type': 'teleport'}),
        throwsA(isA<DrawingFormatException>()),
      );
      expect(() => commandToJson(_Unknown()), throwsArgumentError);
      expect(
        const DrawingFormatException('x').toString(),
        contains('DrawingFormatException'),
      );
    });
  });

  testWidgets('renderDrawing keeps the proportions', (tester) async {
    final drawing = sample();
    final grain = PaperGrain.generate();
    addTearDown(grain.dispose);
    final picture = renderDrawing(drawing, grain, width: 300);
    final height = renderedHeight(drawing, 300);
    expect(height, (300 * 650 / 1137.5).round());
    final image = picture.toImageSync(300, height);
    expect(image.width, 300);
    image.dispose();
    picture.dispose();
  });
}

class _Unknown implements DrawingCommand {
  @override
  Drawing apply(Drawing drawing) => drawing;

  @override
  Drawing revert(Drawing drawing) => drawing;
}
