import 'dart:math' as math;
import 'dart:ui';

import '../document/sheet_point.dart';

/// Parameters of the variable-width stroke outline.
///
/// The approach is inspired by perfect-freehand (MIT, by Steve Ruiz): the
/// radius of each point shrinks as the stroke gets faster, then the left and
/// right edges are offset along the normals and closed with round caps.
class OutlineOptions {
  /// Creates outline options.
  const OutlineOptions({
    this.thinning = 0.6,
    this.minRatio = 0.35,
    this.referenceSpeed = 2.0,
    this.smoothing = 0.6,
    this.streamline = 0.35,
  });

  /// How much speed thins the stroke, 0 (never) to 1 (a lot).
  final double thinning;

  /// The radius never goes below `minRatio * width / 2`.
  final double minRatio;

  /// Speed, in sheet units per millisecond, considered "fast".
  final double referenceSpeed;

  /// Smoothing of the radius between consecutive points, 0..1.
  final double smoothing;

  /// Low-pass filter applied to the input points, 0 (none) to 1 (frozen).
  final double streamline;
}

/// Returns a closed [Path] outlining a variable-width stroke.
///
/// Used by tools whose width depends on speed (the brush, ADR 0008). Constant
/// width tools are cheaper to render as a stroked polyline, see
/// [smoothPolyline].
Path strokeOutline(
  List<SheetPoint> input,
  double width, {
  OutlineOptions options = const OutlineOptions(),
}) {
  final path = Path();
  if (input.isEmpty) return path;

  final points = _streamline(input, options.streamline);
  final radii = _radii(points, width / 2, options);

  if (points.length == 1 || _length(points) < width * 0.25) {
    // A tap leaves a dot (ADR 0008).
    return path
      ..addOval(Rect.fromCircle(center: points.first.offset, radius: radii[0]));
  }

  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < points.length; i++) {
    final normal = _normalAt(points, i);
    final p = points[i].offset;
    left.add(p + normal * radii[i]);
    right.add(p - normal * radii[i]);
  }

  // Left edge forward, round end cap, right edge backward, round start cap.
  // With y pointing down, the caps bulge outwards when drawn
  // counterclockwise.
  _addSmoothedEdge(path, left, moveToStart: true);
  path.arcToPoint(
    right.last,
    radius: Radius.circular(radii.last),
    clockwise: false,
  );
  _addSmoothedEdge(path, right.reversed.toList(), moveToStart: false);
  path.arcToPoint(
    left.first,
    radius: Radius.circular(radii.first),
    clockwise: false,
  );
  return path..close();
}

/// Returns an open [Path] through [points], smoothed with quadratic curves.
///
/// Stroke it with a round cap and join to draw a constant width line.
Path smoothPolyline(List<SheetPoint> points) {
  final path = Path();
  if (points.isEmpty) return path;
  final offsets = [for (final p in points) p.offset];
  path.moveTo(offsets.first.dx, offsets.first.dy);
  if (offsets.length == 1) {
    // A zero length segment still paints a dot with a round cap.
    path.lineTo(offsets.first.dx, offsets.first.dy);
    return path;
  }
  for (var i = 1; i < offsets.length - 1; i++) {
    final mid = (offsets[i] + offsets[i + 1]) / 2;
    path.quadraticBezierTo(offsets[i].dx, offsets[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(offsets.last.dx, offsets.last.dy);
  return path;
}

List<SheetPoint> _streamline(List<SheetPoint> input, double amount) {
  if (amount <= 0 || input.length < 3) return input;
  final t = 1 - amount;
  final out = <SheetPoint>[input.first];
  var prev = input.first;
  for (var i = 1; i < input.length; i++) {
    final p = input[i];
    prev = SheetPoint(
      prev.x + (p.x - prev.x) * t,
      prev.y + (p.y - prev.y) * t,
      pressure: p.pressure,
      time: p.time,
    );
    out.add(prev);
  }
  // Keep the real end point so the stroke ends under the finger.
  out[out.length - 1] = input.last;
  return out;
}

List<double> _radii(List<SheetPoint> points, double base, OutlineOptions o) {
  final radii = List<double>.filled(points.length, base);
  var current = base;
  for (var i = 1; i < points.length; i++) {
    final dt = math.max(1, points[i].time - points[i - 1].time);
    final speed = points[i].distanceTo(points[i - 1]) / dt;
    final factor = 1 - o.thinning * math.min(1.0, speed / o.referenceSpeed);
    final target = base * math.max(o.minRatio, factor);
    current = current * o.smoothing + target * (1 - o.smoothing);
    radii[i] = current;
  }
  if (points.length > 1) radii[0] = radii[1];
  return radii;
}

Offset _normalAt(List<SheetPoint> points, int i) {
  final before = points[math.max(0, i - 1)].offset;
  final after = points[math.min(points.length - 1, i + 1)].offset;
  var d = after - before;
  if (d.distance == 0) d = const Offset(1, 0);
  d = d / d.distance;
  return Offset(-d.dy, d.dx);
}

void _addSmoothedEdge(
  Path path,
  List<Offset> edge, {
  required bool moveToStart,
}) {
  if (moveToStart) {
    path.moveTo(edge.first.dx, edge.first.dy);
  } else {
    path.lineTo(edge.first.dx, edge.first.dy);
  }
  for (var i = 1; i < edge.length - 1; i++) {
    final mid = (edge[i] + edge[i + 1]) / 2;
    path.quadraticBezierTo(edge[i].dx, edge[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(edge.last.dx, edge.last.dy);
}

double _length(List<SheetPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += points[i].distanceTo(points[i - 1]);
  }
  return total;
}
