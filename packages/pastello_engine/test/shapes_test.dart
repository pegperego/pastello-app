import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

const sheet = Size(560, 240);

(ShapeElement, bool) drag(
  ShapeKind kind,
  Offset start,
  Offset end, {
  bool filled = false,
}) => shapeFromDrag(
  id: newElementId(),
  kind: kind,
  start: start,
  end: end,
  color: const Color(0xFF1D4ED8),
  strokeWidth: 8,
  filled: filled,
);

void main() {
  group('shapeFromDrag', () {
    test('a box from the start to the finger', () {
      final (shape, snapped) = drag(
        ShapeKind.rectangle,
        const Offset(10, 20),
        const Offset(110, 70),
      );
      expect(snapped, isFalse);
      expect(shape.extent, const Offset(100, 50));
      expect(shape.transform.translation, const Offset(60, 45));
      expect(shape.bounds.inflate(-4), const Rect.fromLTRB(10, 20, 110, 70));
    });

    test('dragging backwards still gives a positive box', () {
      final (shape, _) = drag(
        ShapeKind.ellipse,
        const Offset(110, 70),
        const Offset(10, 20),
      );
      expect(shape.extent, const Offset(100, 50));
    });

    test('snaps to a perfect circle or square', () {
      final (shape, snapped) = drag(
        ShapeKind.ellipse,
        const Offset(0, 0),
        const Offset(100, -95),
      );
      expect(snapped, isTrue);
      expect(shape.extent, const Offset(100, 100));
      // The corner where the finger started stays in place.
      expect(shape.transform.translation, const Offset(50, -50));
    });

    test('lines snap to 0°, 45° and 90°', () {
      final (flat, snappedFlat) = drag(
        ShapeKind.line,
        Offset.zero,
        const Offset(100, 6),
      );
      expect(snappedFlat, isTrue);
      expect(flat.extent.dy, closeTo(0, 1e-9));
      final (diagonal, snappedDiagonal) = drag(
        ShapeKind.arrow,
        Offset.zero,
        const Offset(-70, -75),
      );
      expect(snappedDiagonal, isTrue);
      expect(diagonal.extent.direction, closeTo(-3 * math.pi / 4, 1e-9));
      final (free, snappedFree) = drag(
        ShapeKind.line,
        Offset.zero,
        const Offset(100, 40),
      );
      expect(snappedFree, isFalse);
      expect(free.extent, const Offset(100, 40));
      // A tap is not a line.
      final (_, snappedTap) = drag(ShapeKind.line, Offset.zero, Offset.zero);
      expect(snappedTap, isFalse);
    });
  });

  test('every shape has a path inside its bounds', () {
    for (final kind in ShapeKind.values) {
      final (shape, _) = drag(kind, Offset.zero, const Offset(120, 80));
      final path = shape.path.getBounds();
      expect(
        shape.localBounds.inflate(1).contains(path.topLeft),
        isTrue,
        reason: kind.name,
      );
      expect(
        shape.localBounds.inflate(1).contains(path.bottomRight),
        isTrue,
        reason: kind.name,
      );
      expect(shape.erasable, isFalse);
      expect(kind.isLine, kind == ShapeKind.line || kind == ShapeKind.arrow);
    }
  });

  test('copies and round-trips through JSON text', () {
    final (shape, _) = drag(
      ShapeKind.star,
      Offset.zero,
      const Offset(80, 60),
      filled: true,
    );
    expect(shape.withId('x').kind, ShapeKind.star);
    expect(shape.withTransform(ElementTransform.identity).filled, isTrue);
    expect(shape.copyWith(strokeWidth: 3).strokeWidth, 3);
    final drawing = const Drawing(sheetSize: sheet).withElementAdded(shape);
    final json =
        jsonDecode(jsonEncode(drawingToJson(drawing))) as Map<String, Object?>;
    final restored = drawingFromJson(json).elements.single as ShapeElement;
    expect(restored.kind, ShapeKind.star);
    expect(restored.filled, isTrue);
    expect(restored.extent, const Offset(80, 60));
    expect(restored.transform.translation, const Offset(40, 30));
    expect(
      () => shapeFromJson({...shapeToJson(shape), 'kind': 'hexagon'}),
      throwsA(isA<DrawingFormatException>()),
    );
  });

  testWidgets('all shapes, outlined and filled', (tester) async {
    final grain = PaperGrain.generate();
    final renderer = DrawingRenderer(grain: grain);
    final live = LiveStroke();
    addTearDown(() {
      renderer.dispose();
      live.dispose();
      grain.dispose();
    });
    var drawing = const Drawing(sheetSize: sheet);
    for (final (i, kind) in ShapeKind.values.indexed) {
      final x = 20.0 + i * 76;
      drawing = drawing
          .withElementAdded(drag(kind, Offset(x, 20), Offset(x + 60, 90)).$1)
          .withElementAdded(
            drag(kind, Offset(x, 130), Offset(x + 60, 200), filled: true).$1,
          );
    }
    renderer.show(drawing);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: sheet,
            child: CustomPaint(
              painter: SheetPainter(
                renderer: renderer,
                live: live,
                sheetSize: sheet,
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/shapes.png'),
    );
  });
}
