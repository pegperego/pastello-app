import 'dart:ui';

import '../document/drawing_element.dart';
import '../document/fill_element.dart';
import '../document/sheet_point.dart';
import '../document/stroke_element.dart';
import 'simplify.dart';

/// Whether an eraser path of [eraserWidth] touches [element]: only strokes
/// and fills can be erased (ADR 0006).
bool eraserTouches(
  List<SheetPoint> eraser,
  double eraserWidth,
  DrawingElement element,
) => switch (element) {
  StrokeElement() => eraserTouchesStroke(eraser, eraserWidth, element),
  FillElement() => eraserTouchesFill(eraser, eraserWidth, element),
  _ => false,
};

/// Whether an eraser path of [eraserWidth] touches [stroke].
///
/// Two polylines touch when any pair of their segments is closer than the sum
/// of their half widths. The test is consistent with what is rendered: every
/// pixel the eraser clears belongs to a stroke for which this returns true
/// (ADR 0006).
bool eraserTouchesStroke(
  List<SheetPoint> eraser,
  double eraserWidth,
  StrokeElement stroke,
) {
  if (eraser.isEmpty || stroke.points.isEmpty) return false;
  // Work in the stroke's own coordinates.
  final t = stroke.transform;
  if (!t.isIdentity) {
    eraser = [
      for (final p in eraser)
        () {
          final local = t.invert(p.offset);
          return SheetPoint(local.dx, local.dy);
        }(),
    ];
    eraserWidth /= t.scale;
  }
  final reach = (eraserWidth + stroke.tool.margin(stroke.width)) / 2;
  if (!polylineBounds(eraser).inflate(reach).overlaps(stroke.localBounds)) {
    return false;
  }
  final reachSquared = reach * reach;
  final a = _segments(eraser);
  final b = _segments(stroke.points);
  for (final (a0, a1) in a) {
    for (final (b0, b1) in b) {
      if (segmentsDistanceSquared(a0, a1, b0, b1) <= reachSquared) return true;
    }
  }
  return false;
}

/// Whether an eraser path of [eraserWidth] touches the area of [fill].
///
/// Each run of the mask is treated as a segment through the middle of its
/// row, half a pixel thick.
bool eraserTouchesFill(
  List<SheetPoint> eraser,
  double eraserWidth,
  FillElement fill,
) {
  if (eraser.isEmpty) return false;
  final t = fill.transform;
  if (!t.isIdentity) {
    eraser = [
      for (final p in eraser)
        () {
          final local = t.invert(p.offset);
          return SheetPoint(local.dx, local.dy);
        }(),
    ];
    eraserWidth /= t.scale;
  }
  final reach = eraserWidth / 2 + 0.5;
  final mask = fill.mask;
  if (!polylineBounds(eraser).inflate(reach).overlaps(mask.bounds)) {
    return false;
  }
  final reachSquared = reach * reach;
  for (final (a0, a1) in _segments(eraser)) {
    final box = polylineBounds([a0, a1]).inflate(reach);
    final first = (box.top - mask.top).floor().clamp(0, mask.height);
    final last = (box.bottom - mask.top).ceil().clamp(0, mask.height);
    for (var r = first; r < last; r++) {
      final row = mask.rows[r];
      final y = mask.top + r + 0.5;
      for (var i = 0; i < row.length; i += 2) {
        final b0 = SheetPoint(mask.left + row[i] + 0.5, y);
        final b1 = SheetPoint(mask.left + row[i] + row[i + 1] - 0.5, y);
        if (segmentsDistanceSquared(a0, a1, b0, b1) <= reachSquared) {
          return true;
        }
      }
    }
  }
  return false;
}

/// Squared distance between the segments [a0]-[a1] and [b0]-[b1].
double segmentsDistanceSquared(
  SheetPoint a0,
  SheetPoint a1,
  SheetPoint b0,
  SheetPoint b1,
) {
  if (_segmentsIntersect(a0, a1, b0, b1)) return 0;
  return [
    segmentDistanceSquared(a0, b0, b1),
    segmentDistanceSquared(a1, b0, b1),
    segmentDistanceSquared(b0, a0, a1),
    segmentDistanceSquared(b1, a0, a1),
  ].reduce((x, y) => x < y ? x : y);
}

/// A single point is treated as a zero length segment.
List<(SheetPoint, SheetPoint)> _segments(List<SheetPoint> points) => [
  if (points.length == 1) (points.first, points.first),
  for (var i = 1; i < points.length; i++) (points[i - 1], points[i]),
];

bool _segmentsIntersect(
  SheetPoint a0,
  SheetPoint a1,
  SheetPoint b0,
  SheetPoint b1,
) {
  double cross(SheetPoint o, SheetPoint p, SheetPoint q) =>
      (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x);
  final d1 = cross(b0, b1, a0);
  final d2 = cross(b0, b1, a1);
  final d3 = cross(a0, a1, b0);
  final d4 = cross(a0, a1, b1);
  // Proper crossings only; touching and collinear cases are covered by the
  // point-to-segment distances.
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

/// Axis-aligned bounds of [points] (without any width).
Rect polylineBounds(List<SheetPoint> points) {
  var left = points.first.x, right = left;
  var top = points.first.y, bottom = top;
  for (final p in points) {
    if (p.x < left) left = p.x;
    if (p.x > right) right = p.x;
    if (p.y < top) top = p.y;
    if (p.y > bottom) bottom = p.y;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}
