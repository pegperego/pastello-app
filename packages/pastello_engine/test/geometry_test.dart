import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastello_engine/pastello_engine.dart';

List<SheetPoint> line(
  double fromX,
  double toX, {
  double y = 0,
  int step = 1,
}) => [
  for (var x = fromX; x <= toX; x += step) SheetPoint(x, y, time: x.toInt()),
];

StrokeElement stroke(List<SheetPoint> points, {double width = 4}) =>
    StrokeElement(
      id: newElementId(),
      tool: StrokeTool.marker,
      color: const Color(0xFF000000),
      width: width,
      points: points,
    );

void main() {
  group('simplify', () {
    test('drops collinear points but keeps the ends', () {
      final result = simplify(line(0, 100), 0.5);
      expect(result, [line(0, 100).first, line(0, 100).last]);
    });

    test('keeps corners', () {
      final points = [
        const SheetPoint(0, 0),
        const SheetPoint(50, 0),
        const SheetPoint(50, 50),
      ];
      expect(simplify(points, 1), points);
    });

    test('returns short lines unchanged', () {
      final points = [const SheetPoint(0, 0), const SheetPoint(1, 1)];
      expect(simplify(points, 1), points);
    });
  });

  group('segmentDistanceSquared', () {
    test('measures to the closest point of the segment', () {
      const a = SheetPoint(0, 0), b = SheetPoint(10, 0);
      expect(segmentDistanceSquared(const SheetPoint(5, 3), a, b), 9);
      expect(segmentDistanceSquared(const SheetPoint(-4, 3), a, b), 25);
    });

    test('handles degenerate segments', () {
      const a = SheetPoint(1, 1);
      expect(segmentDistanceSquared(const SheetPoint(4, 5), a, a), 25);
    });
  });

  group('eraserTouchesStroke', () {
    final target = stroke(line(0, 100), width: 10);

    test('touches when the eraser crosses the stroke', () {
      final eraser = [const SheetPoint(50, -20), const SheetPoint(50, 20)];
      expect(eraserTouchesStroke(eraser, 4, target), isTrue);
    });

    test('touches when the widths overlap without crossing', () {
      final eraser = [const SheetPoint(0, 10), const SheetPoint(100, 10)];
      // Half widths: 5 + 6 = 11 > 10.
      expect(eraserTouchesStroke(eraser, 12, target), isTrue);
      expect(eraserTouchesStroke(eraser, 8, target), isFalse);
    });

    test('handles single point strokes and erasers', () {
      final dot = stroke([const SheetPoint(10, 10)], width: 4);
      expect(eraserTouchesStroke([const SheetPoint(12, 10)], 4, dot), isTrue);
      expect(eraserTouchesStroke([const SheetPoint(30, 10)], 4, dot), isFalse);
    });

    test('touches when segments cross far from any vertex', () {
      final long = stroke([const SheetPoint(0, 0), const SheetPoint(100, 0)]);
      final eraser = [const SheetPoint(50, -50), const SheetPoint(50, 50)];
      expect(eraserTouchesStroke(eraser, 2, long), isTrue);
      expect(
        segmentsDistanceSquared(
          const SheetPoint(0, 0),
          const SheetPoint(10, 0),
          const SheetPoint(0, 3),
          const SheetPoint(10, 3),
        ),
        9,
      );
    });

    test('ignores far away strokes', () {
      final eraser = [const SheetPoint(500, 500), const SheetPoint(600, 600)];
      expect(eraserTouchesStroke(eraser, 50, target), isFalse);
    });
  });

  group('strokeOutline', () {
    test('a tap produces a dot of the stroke width', () {
      final path = strokeOutline([const SheetPoint(10, 10)], 8);
      final bounds = path.getBounds();
      expect(bounds.center, const Offset(10, 10));
      expect(bounds.width, closeTo(8, 0.01));
    });

    test('a line covers its points', () {
      final points = line(0, 200, step: 4);
      final bounds = strokeOutline(points, 10).getBounds();
      expect(bounds.left, lessThanOrEqualTo(0));
      expect(bounds.right, greaterThanOrEqualTo(200));
    });

    test('fast strokes are thinner than slow ones', () {
      List<SheetPoint> drawn(int msPerPoint) => [
        for (var i = 0; i <= 50; i++)
          SheetPoint(i * 4.0, 0, time: i * msPerPoint),
      ];
      final slow = strokeOutline(drawn(20), 20).getBounds().height;
      final fast = strokeOutline(drawn(1), 20).getBounds().height;
      expect(fast, lessThan(slow));
    });

    test('an empty input produces an empty path', () {
      expect(strokeOutline(const [], 8).getBounds(), Rect.zero);
    });
  });

  test('smoothPolyline passes through the end points', () {
    final points = [
      const SheetPoint(0, 0),
      const SheetPoint(10, 20),
      const SheetPoint(30, 0),
    ];
    final bounds = smoothPolyline(points).getBounds();
    expect(bounds.left, 0);
    expect(bounds.right, 30);
    expect(smoothPolyline(const []).getBounds(), Rect.zero);
  });

  test('rainbow colors depend on distance and repeat', () {
    expect(rainbowColorAt(0), rainbowColorAt(rainbowPeriod));
    expect(rainbowColorAt(0), isNot(rainbowColorAt(rainbowPeriod / 2)));
  });

  test('element ids are unique 32 character hex strings', () {
    final ids = {for (var i = 0; i < 1000; i++) newElementId()};
    expect(ids, hasLength(1000));
    expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
  });
}
