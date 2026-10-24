import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

StrokeElement stroke(List<Offset> points, {ElementTransform? transform}) =>
    StrokeElement(
      id: newElementId(),
      tool: StrokeTool.marker,
      color: const Color(0xFF000000),
      width: 10,
      points: [for (final p in points) SheetPoint(p.dx, p.dy)],
      transform: transform ?? ElementTransform.identity,
    );

const square = [Offset(0, 0), Offset(100, 0), Offset(100, 100), Offset(0, 100)];

void main() {
  test('points inside a polygon', () {
    expect(pointInPolygon(const Offset(50, 50), square), isTrue);
    expect(pointInPolygon(const Offset(150, 50), square), isFalse);
    expect(
      pointInPolygon(const Offset(50, 50), square.take(2).toList()),
      isFalse,
    );
  });

  test('the lasso catches strokes by most of their points', () {
    final inside = stroke([
      const Offset(10, 50),
      const Offset(60, 50),
      const Offset(90, 50),
    ]);
    final mostlyOutside = stroke([
      const Offset(90, 20),
      const Offset(150, 20),
      const Offset(200, 20),
    ]);
    final movedIn = stroke([
      const Offset(500, 500),
      const Offset(520, 500),
    ], transform: const ElementTransform(translation: Offset(-450, -450)));
    final text = TextElement(
      id: 'text',
      text: 'Ciao',
      color: const Color(0xFF000000),
      fontSize: 20,
      transform: const ElementTransform(translation: Offset(50, 80)),
    );
    final drawing = const Drawing(sheetSize: Size(300, 300))
        .withElementAdded(inside)
        .withElementAdded(mostlyOutside)
        .withElementAdded(movedIn)
        .withElementAdded(text)
        .withElementAdded(stroke(const []));
    expect(lassoSelection(drawing, square), [inside.id, movedIn.id, 'text']);
    expect(lassoSelection(drawing, square.take(2).toList()), isEmpty);
  });

  test('strokes are hit on their line, not in their box', () {
    final diagonal = stroke([const Offset(0, 0), const Offset(100, 100)]);
    expect(diagonal.contains(const Offset(50, 50)), isTrue);
    expect(diagonal.contains(const Offset(90, 10)), isFalse);
    expect(diagonal.contains(const Offset(60, 50), slop: 10), isTrue);
    final dot = stroke([const Offset(20, 20)]);
    expect(dot.contains(const Offset(22, 22)), isTrue);
    expect(dot.contains(const Offset(40, 40)), isFalse);
    expect(stroke(const []).contains(Offset.zero), isFalse);
  });

  test('a group moves, scales and rotates around its center', () {
    final a = stroke([const Offset(0, 0), const Offset(20, 0)]);
    final b = stroke([const Offset(80, 0), const Offset(100, 0)]);
    final box = groupBounds([a, b]);
    expect(box.center.dx, closeTo(50, 1e-9));

    // Turn the frame by 90° around its center and move it 10 to the right.
    final frame = ElementTransform(
      translation: box.center + const Offset(10, 0),
      rotation: math.pi / 2,
    );
    final g = groupTransform(box, frame);
    final moved = a.transform.then(g);
    // The first point of a, at the left end, ends up above the center.
    final p = moved.apply(const Offset(0, 0));
    expect(p.dx, closeTo(60, 1e-9));
    expect(p.dy, closeTo(-50, 1e-9));
    expect(moved.rotation, closeTo(math.pi / 2, 1e-9));

    // Scaling a group scales every element.
    final bigger = groupTransform(
      box,
      ElementTransform(translation: box.center, scale: 2),
    );
    expect(b.transform.then(bigger).scale, 2);
    expect(
      b.transform.then(bigger).apply(const Offset(100, 0)).dx,
      closeTo(150, 1e-9),
    );
  });

  test('a batch is one undo step and survives serialization', () {
    final a = stroke([const Offset(0, 0), const Offset(20, 0)]);
    final b = stroke([const Offset(80, 0), const Offset(100, 0)]);
    final c = stroke([const Offset(40, 40), const Offset(60, 40)]);
    final drawing = const Drawing(
      sheetSize: Size(300, 300),
    ).withElementAdded(a).withElementAdded(b).withElementAdded(c);

    final delete = BatchCommand.deleteAll(drawing, [a.id, c.id]);
    final deleted = delete.apply(drawing);
    expect(deleted.elements.map((e) => e.id), [b.id]);
    // Undo puts each element back at its place in the z-order.
    expect(delete.revert(deleted).elements.map((e) => e.id), [
      a.id,
      b.id,
      c.id,
    ]);

    final json =
        jsonDecode(jsonEncode(commandToJson(delete))) as Map<String, Object?>;
    final restored = commandFromJson(json) as BatchCommand;
    expect(restored.commands, hasLength(2));
    expect(restored.apply(drawing).elements.map((e) => e.id), [b.id]);
  });
}
