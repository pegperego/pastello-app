import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

/// A map of [width] × [height] pixels with the outline of a box from
/// ([left], [top]) to ([right], [bottom]) excluded, [thickness] pixels
/// thick, and an opening of [gap] pixels in the middle of its top side.
Uint8List boxWalls(
  int width,
  int height, {
  int left = 40,
  int top = 40,
  int right = 160,
  int bottom = 160,
  int thickness = 4,
  int gap = 0,
}) {
  final walls = Uint8List(width * height);
  final middle = (left + right) ~/ 2;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final edge =
          x < left + thickness ||
          x >= right - thickness ||
          y < top + thickness ||
          y >= bottom - thickness;
      final opening =
          y < top + thickness && (x - middle).abs() * 2 < gap && gap > 0;
      if (edge && !opening) walls[y * width + x] = 1;
    }
  }
  return walls;
}

bool contains(BucketRegion region, int x, int y) => FillMask(
  left: region.left,
  top: region.top,
  rows: region.rows,
).containsPixel(x, y);

FillMask maskOf(Rect rect) => FillMask(
  left: rect.left.toInt(),
  top: rect.top.toInt(),
  rows: [
    for (var y = 0; y < rect.height; y++)
      Int32List.fromList([0, rect.width.toInt()]),
  ],
);

void main() {
  group('bucketRegion', () {
    test('fills a closed box up to under its border', () {
      final region = bucketRegion(boxWalls(200, 200), 200, 200, 100, 100)!;
      expect(contains(region, 100, 100), isTrue);
      // Right next to the inner side of the border: no white edge.
      expect(contains(region, 44, 100), isTrue);
      expect(contains(region, 43, 100), isTrue);
      // Not through the border, not outside.
      expect(contains(region, 39, 100), isFalse);
      expect(contains(region, 10, 10), isFalse);
      expect(region.left, greaterThanOrEqualTo(40));
      expect(region.top, greaterThanOrEqualTo(40));
    });

    test('a tap outside the box fills around it', () {
      final region = bucketRegion(boxWalls(200, 200), 200, 200, 10, 10)!;
      expect(contains(region, 0, 0), isTrue);
      expect(contains(region, 199, 199), isTrue);
      expect(contains(region, 100, 100), isFalse);
    });

    test('closes gaps up to the medium width, not wider ones', () {
      final small = bucketRegion(
        boxWalls(200, 200, gap: 8),
        200,
        200,
        100,
        100,
      )!;
      expect(contains(small, 10, 10), isFalse);
      final wide = bucketRegion(
        boxWalls(200, 200, gap: 14),
        200,
        200,
        100,
        100,
      )!;
      expect(contains(wide, 10, 10), isTrue);
    });

    test('an open sheet is filled whole', () {
      final region = bucketRegion(Uint8List(60 * 40), 60, 40, 5, 5)!;
      expect(region.left, 0);
      expect(region.top, 0);
      expect(region.rows, hasLength(40));
      expect(region.rows.every((r) => r[0] == 0 && r[1] == 60), isTrue);
    });

    test('a tap on a border or outside the map fills nothing', () {
      final walls = boxWalls(200, 200);
      expect(bucketRegion(walls, 200, 200, 41, 100), isNull);
      expect(bucketRegion(walls, 200, 200, -1, 100), isNull);
      expect(bucketRegion(walls, 200, 200, 100, 200), isNull);
    });

    test('a tap close to the border fills the same area', () {
      final walls = boxWalls(200, 200, gap: 8);
      final center = bucketRegion(walls, 200, 200, 100, 100)!;
      final edge = bucketRegion(walls, 200, 200, 46, 100)!;
      expect(edge.left, center.left);
      expect(edge.top, center.top);
      expect(edge.rows.length, center.rows.length);
    });

    test('a narrow area is filled too', () {
      // A box only 6 pixels wide inside.
      final walls = boxWalls(200, 200, left: 40, right: 54);
      final region = bucketRegion(walls, 200, 200, 47, 100)!;
      expect(contains(region, 47, 100), isTrue);
      expect(contains(region, 47, 50), isTrue);
      expect(contains(region, 30, 100), isFalse);
    });
  });

  group('FillMask', () {
    final mask = FillMask(
      left: 10,
      top: 20,
      rows: [
        Int32List.fromList([0, 3, 5, 2]),
        Int32List.fromList([]),
        Int32List.fromList([1, 4]),
      ],
    );

    test('bounds, area and pixels', () {
      expect(mask.bounds, const Rect.fromLTRB(10, 20, 17, 23));
      expect(mask.area, 9);
      expect(mask.containsPixel(10, 20), isTrue);
      expect(mask.containsPixel(13, 20), isFalse);
      expect(mask.containsPixel(16, 20), isTrue);
      expect(mask.containsPixel(12, 21), isFalse);
      expect(mask.containsPixel(11, 22), isTrue);
      expect(mask.containsPixel(11, 23), isFalse);
    });

    test('covers', () {
      final big = maskOf(const Rect.fromLTWH(0, 0, 50, 50));
      expect(big.covers(mask), isTrue);
      expect(mask.covers(big), isFalse);
      expect(maskOf(const Rect.fromLTWH(11, 0, 50, 50)).covers(mask), isFalse);
    });

    test('the path merges rows that repeat', () {
      final square = maskOf(const Rect.fromLTWH(5, 5, 10, 10));
      expect(square.path.getBounds(), const Rect.fromLTWH(5, 5, 10, 10));
      expect(square.path.contains(const Offset(10, 10)), isTrue);
      expect(mask.path.contains(const Offset(13.5, 20.5)), isFalse);
      expect(mask.path.contains(const Offset(15.5, 20.5)), isTrue);
    });
  });

  group('FillElement', () {
    final fill = FillElement(
      id: 'f',
      color: const Color(0xFF2A9D3F),
      mask: maskOf(const Rect.fromLTWH(100, 100, 50, 20)),
    );

    test('is hit inside its area, also after moving', () {
      expect(fill.contains(const Offset(120, 110)), isTrue);
      expect(fill.contains(const Offset(99, 110)), isFalse);
      final moved = fill.withTransform(
        const ElementTransform(translation: Offset(10, 0)),
      );
      expect(moved.contains(const Offset(155, 110)), isTrue);
      expect(moved.contains(const Offset(105, 110)), isFalse);
    });

    test('is erased like a stroke, and the eraser comes back on undo', () {
      final drawing = Drawing(
        sheetSize: const Size(400, 300),
        elements: [fill],
      );
      expect(
        EraseCommand.forDrawing(drawing, const [
          SheetPoint(0, 0),
          SheetPoint(90, 90),
        ], 10),
        isNull,
      );
      final command = EraseCommand.forDrawing(drawing, const [
        SheetPoint(120, 0),
        SheetPoint(120, 200),
      ], 10)!;
      expect(command.elementIds, {'f'});
      final erased = command.apply(drawing);
      expect((erased.elements.single as FillElement).erasures, hasLength(1));
      final restored = command.revert(erased);
      expect((restored.elements.single as FillElement).erasures, isEmpty);
    });

    test('the lasso catches it when most of its area is inside', () {
      final drawing = Drawing(
        sheetSize: const Size(400, 300),
        elements: [fill],
      );
      List<Offset> box(double l, double t, double r, double b) => [
        Offset(l, t),
        Offset(r, t),
        Offset(r, b),
        Offset(l, b),
      ];
      expect(lassoSelection(drawing, box(90, 90, 140, 130)), ['f']);
      expect(lassoSelection(drawing, box(90, 90, 115, 130)), isEmpty);
    });

    test('is painted under every other element, newer fills on top', () {
      final stroke = StrokeElement(
        id: 's',
        tool: StrokeTool.marker,
        color: const Color(0xFF000000),
        width: 4,
        points: const [SheetPoint(0, 0), SheetPoint(10, 10)],
      );
      final older = fill.withId('old');
      final drawing = Drawing(
        sheetSize: const Size(400, 300),
        elements: [older, stroke, fill],
      );
      expect(drawing.paintOrder.map((e) => e.id), ['old', 'f', 's']);
      // The stroke is the topmost element where it is drawn.
      expect(drawing.elementAt(const Offset(5, 5))?.id, 's');
      expect(drawing.elementAt(const Offset(120, 110))?.id, 'f');
    });

    test('survives saving and loading', () {
      final erased = fill
          .withTransform(const ElementTransform(translation: Offset(3, 4)))
          .withErasure(
            const Erasure(
              id: 'e',
              width: 10,
              points: [SheetPoint(1, 2), SheetPoint(3, 4)],
            ),
          );
      final drawing = Drawing(
        sheetSize: const Size(400, 300),
        elements: [erased],
      );
      final loaded =
          drawingFromJson(drawingToJson(drawing)).elements.single
              as FillElement;
      expect(loaded.id, 'f');
      expect(loaded.color, fill.color);
      expect(loaded.mask.bounds, fill.mask.bounds);
      expect(loaded.mask.area, fill.mask.area);
      expect(loaded.erasures.single.id, 'e');
      expect(loaded.transform, erased.transform);
      expect(
        () => fillFromJson({
          'type': 'fill',
          'id': 'x',
          'color': 0,
          'left': 0,
          'top': 0,
          'rows': [
            [1, 2, 3],
          ],
        }),
        throwsA(isA<DrawingFormatException>()),
      );
    });
  });

  group('on a drawing', () {
    const sheet = Size(400, 240);
    const red = Color(0xFFE63946);
    const blue = Color(0xFF1D4ED8);

    final box = ShapeElement(
      id: 'box',
      kind: ShapeKind.rectangle,
      extent: const Offset(200, 120),
      color: const Color(0xFF000000),
      strokeWidth: 10,
      transform: const ElementTransform(translation: Offset(200, 120)),
    );
    StrokeElement line(StrokeTool tool, {double y = 120}) => StrokeElement(
      id: tool.name,
      tool: tool,
      color: blue,
      width: 10,
      points: [SheetPoint(20, y), SheetPoint(380, y)],
    );

    testWidgets('fills inside the borders; texts and see-through strokes '
        'do not stop the color', (tester) async {
      final drawing = Drawing(
        sheetSize: sheet,
        elements: [
          box,
          line(StrokeTool.highlighter, y: 100),
          line(StrokeTool.spray, y: 140),
          TextElement(
            id: 't',
            text: 'Ciao',
            color: red,
            fontSize: 40,
            transform: const ElementTransform(translation: Offset(200, 120)),
          ),
        ],
      );
      final mask = (await tester.runAsync(
        () => bucketFill(drawing, const Offset(150, 120)),
      ))!;
      // Inside the box (lines from 100 to 300, 60 to 180, 10 thick).
      expect(mask.containsPixel(110, 70), isTrue);
      expect(mask.containsPixel(200, 120), isTrue);
      expect(mask.containsPixel(290, 170), isTrue);
      expect(mask.containsPixel(90, 120), isFalse);
      expect(mask.containsPixel(200, 50), isFalse);
      // Under the inner half of the border, no further.
      expect(mask.containsPixel(105, 120), isTrue);
      expect(mask.containsPixel(100, 120), isFalse);
    });

    testWidgets('finds the line under the finger', (tester) async {
      final drawing = Drawing(
        sheetSize: sheet,
        elements: [
          box,
          line(StrokeTool.marker, y: 100),
          line(StrokeTool.watercolor, y: 140),
        ],
      );
      Future<String?> at(Offset point) async =>
          (await tester.runAsync(() => bucketBorderAt(drawing, point)))?.id;
      expect(await at(const Offset(200, 101)), 'marker');
      expect(await at(const Offset(100, 120)), 'box');
      expect(await at(const Offset(200, 120)), isNull);
      // See-through strokes are not borders.
      expect(await at(const Offset(200, 140)), isNull);
    });

    testWidgets('fills are painted under the lines, the cache only repaints '
        'their area', (tester) async {
      final grain = PaperGrain.generate();
      final renderer = DrawingRenderer(grain: grain);
      final live = LiveStroke();
      addTearDown(() {
        renderer.dispose();
        live.dispose();
        grain.dispose();
      });
      var drawing = Drawing(
        sheetSize: sheet,
        elements: [box, line(StrokeTool.crayon), line(StrokeTool.highlighter)],
      );
      final inside = (await tester.runAsync(
        () => bucketFill(drawing, const Offset(150, 90)),
      ))!;
      final outside = (await tester.runAsync(
        () => bucketFill(drawing, const Offset(20, 20)),
      ))!;
      renderer.show(drawing);
      drawing = drawing.withElementAdded(
        FillElement(id: 'in', color: const Color(0xFFFFD60A), mask: inside),
      );
      renderer.show(drawing);
      expect(renderer.lastUpdateWasRebuild, isFalse);
      // A newer fill over the older one: everything outside the box.
      drawing = drawing.withElementAdded(
        FillElement(id: 'out', color: const Color(0xFFBDE0FE), mask: outside),
      );
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
        matchesGoldenFile('goldens/bucket.png'),
      );
      // The same as rebuilding the whole cache.
      renderer.show(drawing.withElements([...drawing.elements]));
      expect(renderer.lastUpdateWasRebuild, isTrue);
      await tester.pump();
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/bucket.png'),
      );
    });
  });
}
