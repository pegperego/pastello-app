import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

import '../document/sheet_point.dart';
import '../document/stroke_element.dart';
import '../document/stroke_tool.dart';
import '../geometry/stroke_outline.dart';
import 'paper_grain.dart';

/// Distance, in sheet units, after which the rainbow repeats its colors.
const double rainbowPeriod = 600;

/// How much of the paper grain each tool lets through, 0..1.
double _grainStrength(StrokeTool tool) => switch (tool) {
  StrokeTool.crayon => 0.75,
  StrokeTool.pencil => 0.35,
  _ => 0,
};

/// Paints [stroke] on [canvas], in sheet coordinates.
///
/// Strokes with grain or erasures are composited in their own layer so the
/// grain and the eraser only remove pixels of this stroke (ADR 0006).
void paintStroke(Canvas canvas, StrokeElement stroke, PaperGrain grain) {
  final grainStrength = _grainStrength(stroke.tool);
  final needsLayer = grainStrength > 0 || stroke.erasures.isNotEmpty;
  final bounds = stroke.bounds;

  if (needsLayer) canvas.saveLayer(bounds, Paint());
  paintStrokeInk(
    canvas,
    stroke.tool,
    stroke.color,
    stroke.width,
    stroke.points,
  );
  if (grainStrength > 0) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = grain.shader()
        ..color = Color.fromRGBO(0, 0, 0, grainStrength)
        ..blendMode = BlendMode.dstOut,
    );
  }
  for (final erasure in stroke.erasures) {
    paintEraser(canvas, erasure.points, erasure.width);
  }
  if (needsLayer) canvas.restore();
}

/// Paints the ink of a stroke, without grain or erasures.
///
/// Also used for the stroke in progress.
void paintStrokeInk(
  Canvas canvas,
  StrokeTool tool,
  Color color,
  double width,
  List<SheetPoint> points,
) {
  if (points.isEmpty) return;
  switch (tool) {
    case StrokeTool.brush:
      canvas.drawPath(strokeOutline(points, width), Paint()..color = color);
    case StrokeTool.rainbow:
      _paintRainbow(canvas, width, points);
    case StrokeTool.pencil:
    case StrokeTool.marker:
    case StrokeTool.crayon:
      canvas.drawPath(smoothPolyline(points), _linePaint(color, width));
  }
}

/// Paints an eraser pass: clears the pixels under [points].
///
/// Must be drawn inside a layer, otherwise it would clear everything beneath,
/// background included.
void paintEraser(Canvas canvas, List<SheetPoint> points, double width) {
  canvas.drawPath(
    smoothPolyline(points),
    _linePaint(const Color(0xFF000000), width)..blendMode = BlendMode.clear,
  );
}

Paint _linePaint(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Color of the rainbow at [distance] sheet units from the stroke start.
///
/// Based on distance, not time, so colors are evenly spread regardless of how
/// fast the child draws.
Color rainbowColorAt(double distance) {
  final hue = (distance / rainbowPeriod * 360) % 360;
  return HSVColor.fromAHSV(1, hue, 0.8, 0.95).toColor();
}

/// Number of hue steps used to draw the rainbow: enough for a smooth
/// gradient, few enough to keep the number of draw calls small.
const int _rainbowSteps = 72;

/// Paints the rainbow as round "stamps" spaced along the line.
///
/// Drawing one segment per color would show beads where round caps of
/// different colors overlap. Stamps placed every couple of units blend into a
/// continuous gradient, and grouping them by hue keeps it to at most
/// [_rainbowSteps] draw calls.
void _paintRainbow(Canvas canvas, double width, List<SheetPoint> points) {
  final spacing = (width / 8).clamp(0.75, 3.0);
  final buckets = List.generate(_rainbowSteps, (_) => <Offset>[]);
  void stamp(Offset at, double distance) {
    final hueStep =
        ((distance / rainbowPeriod) * _rainbowSteps).floor() % _rainbowSteps;
    buckets[hueStep].add(at);
  }

  var distance = 0.0;
  stamp(points.first.offset, 0);
  var carry = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1].offset, b = points[i].offset;
    final length = (b - a).distance;
    var t = spacing - carry;
    while (t <= length) {
      stamp(Offset.lerp(a, b, t / length)!, distance + t);
      t += spacing;
    }
    carry = length - (t - spacing);
    distance += length;
  }
  stamp(points.last.offset, distance);

  for (var step = 0; step < _rainbowSteps; step++) {
    if (buckets[step].isEmpty) continue;
    canvas.drawPoints(
      PointMode.points,
      buckets[step],
      _linePaint(rainbowColorAt(step / _rainbowSteps * rainbowPeriod), width),
    );
  }
}
