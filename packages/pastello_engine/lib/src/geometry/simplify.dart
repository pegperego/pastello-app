import '../document/sheet_point.dart';

/// Simplifies a polyline with the Ramer–Douglas–Peucker algorithm.
///
/// Points closer than [tolerance] (sheet units) to the simplified line are
/// dropped. The first and last points are always kept. Applied when a stroke
/// ends to reduce what is stored and redrawn (ADR 0005).
List<SheetPoint> simplify(List<SheetPoint> points, double tolerance) {
  if (points.length < 3 || tolerance <= 0) return List.of(points);
  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  // Iterative version, to avoid deep recursion on very long strokes.
  final stack = <(int, int)>[(0, points.length - 1)];
  final toleranceSquared = tolerance * tolerance;
  while (stack.isNotEmpty) {
    final (start, end) = stack.removeLast();
    var maxDistance = 0.0;
    var index = -1;
    for (var i = start + 1; i < end; i++) {
      final d = segmentDistanceSquared(points[i], points[start], points[end]);
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }
    if (index != -1 && maxDistance > toleranceSquared) {
      keep[index] = true;
      stack
        ..add((start, index))
        ..add((index, end));
    }
  }
  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

/// Squared distance from [p] to the segment [a]-[b].
double segmentDistanceSquared(SheetPoint p, SheetPoint a, SheetPoint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lengthSquared = dx * dx + dy * dy;
  var t = 0.0;
  if (lengthSquared > 0) {
    t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared).clamp(0.0, 1.0);
  }
  final cx = a.x + t * dx - p.x;
  final cy = a.y + t * dy - p.y;
  return cx * cx + cy * cy;
}
