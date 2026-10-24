import 'dart:ui';

import 'package:flutter/painting.dart'
    show FontWeight, HSVColor, TextDirection, TextPainter, TextSpan, TextStyle;

import '../document/drawing_element.dart';
import '../document/sheet_point.dart';
import '../document/shape_element.dart';
import '../document/sticker_element.dart';
import '../document/stroke_element.dart';
import '../document/text_element.dart';
import '../document/stroke_tool.dart';
import '../geometry/stroke_outline.dart';
import 'paper_grain.dart';

/// Distance, in sheet units, after which the rainbow repeats its colors.
const double rainbowPeriod = 600;

/// How much of the paper grain each tool shows, 0 (none) to 1.
double grainStrength(StrokeTool tool) => switch (tool) {
  StrokeTool.crayon => 0.75,
  StrokeTool.pencil => 0.35,
  _ => 0,
};

/// Paints any [element] on [canvas], in sheet coordinates.
///
/// Stickers are drawn with the pictures from [stickers]; without them, or
/// when a sticker is missing, a placeholder is drawn instead.
void paintElement(
  Canvas canvas,
  DrawingElement element,
  PaperGrain grain, {
  StickerArtwork? stickers,
}) {
  final t = element.transform;
  if (!t.isIdentity) {
    canvas
      ..save()
      ..transform(t.matrix);
  }
  switch (element) {
    case StrokeElement():
      paintStroke(canvas, element, grain);
    case TextElement():
      element.paintLocal(canvas);
    case StickerElement():
      paintSticker(canvas, element, stickers);
    case ShapeElement():
      element.paintLocal(canvas);
  }
  if (!t.isIdentity) canvas.restore();
}

/// Paints [stroke] on [canvas], in the stroke's local coordinates.
///
/// Strokes with grain or erasures are composited in their own layer so the
/// grain and the eraser only remove pixels of this stroke (ADR 0006).
void paintStroke(Canvas canvas, StrokeElement stroke, PaperGrain grain) {
  final strength = grainStrength(stroke.tool);
  final needsLayer = strength > 0 || stroke.erasures.isNotEmpty;
  final bounds = stroke.localBounds;

  if (needsLayer) canvas.saveLayer(bounds, Paint());
  paintStrokeInk(
    canvas,
    stroke.tool,
    stroke.color,
    stroke.width,
    stroke.points,
  );
  if (strength > 0) paintGrain(canvas, bounds, strength, grain);
  for (final erasure in stroke.erasures) {
    paintEraser(canvas, erasure.points, erasure.width);
  }
  if (needsLayer) canvas.restore();
}

/// Removes the paper grain from what is already in the current layer, within
/// [bounds].
void paintGrain(Canvas canvas, Rect bounds, double strength, PaperGrain grain) {
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = grain.shader()
      ..color = Color.fromRGBO(0, 0, 0, strength)
      ..blendMode = BlendMode.dstOut,
  );
}

/// Paints the ink of a stroke, without grain or erasures.
///
/// [from] and [to] paint only a range of [points], so that a long stroke can
/// be painted in pieces (ADR 0005); the pieces join seamlessly because the
/// rainbow colors and the brush widths depend on the whole stroke.
void paintStrokeInk(
  Canvas canvas,
  StrokeTool tool,
  Color color,
  double width,
  List<SheetPoint> points, {
  int from = 0,
  int? to,
}) {
  final end = to ?? points.length;
  if (end - from < 1) return;
  switch (tool) {
    case StrokeTool.brush:
      canvas.drawPath(
        strokeOutline(points, width, from: from, to: end),
        Paint()..color = color,
      );
    case StrokeTool.rainbow:
      _paintRainbow(canvas, width, points, from, end);
    case StrokeTool.pencil:
    case StrokeTool.marker:
    case StrokeTool.crayon:
      canvas.drawPath(
        smoothPolyline(points.sublist(from, end)),
        _linePaint(color, width),
      );
  }
}

/// Paints an eraser pass along [points].
///
/// Without a [color] or [shader] it clears the pixels under the path: used
/// inside a stroke's own layer, for the erasures attached to it (ADR 0006).
/// With a [shader] (an image of the paper) it paints the paper instead:
/// used on the opaque cache, where erasing means showing the background
/// again, lines and squares included.
void paintEraser(
  Canvas canvas,
  List<SheetPoint> points,
  double width, {
  Color? color,
  Shader? shader,
}) {
  final paint = _linePaint(color ?? const Color(0xFF000000), width);
  if (shader != null) {
    paint.shader = shader;
  } else if (color == null) {
    paint.blendMode = BlendMode.clear;
  }
  canvas.drawPath(smoothPolyline(points), paint);
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
///
/// Stamps are always spaced from the start of the stroke, and only those
/// between the points [from] and [to] are painted, so a stroke painted in
/// pieces puts every stamp exactly where the whole stroke would.
void _paintRainbow(
  Canvas canvas,
  double width,
  List<SheetPoint> points,
  int from,
  int to,
) {
  final spacing = (width / 8).clamp(0.75, 3.0);
  final buckets = List.generate(_rainbowSteps, (_) => <Offset>[]);
  void stamp(Offset at, double distance) {
    final hueStep =
        ((distance / rainbowPeriod) * _rainbowSteps).floor() % _rainbowSteps;
    buckets[hueStep].add(at);
  }

  if (from == 0) stamp(points.first.offset, 0);
  var distance = 0.0;
  var next = spacing;
  for (var i = 1; i < to; i++) {
    final a = points[i - 1].offset, b = points[i].offset;
    final length = (b - a).distance;
    // Segments before the range only advance the spacing.
    if (i > from) {
      while (next <= distance + length) {
        stamp(Offset.lerp(a, b, (next - distance) / length)!, next);
        next += spacing;
      }
    } else {
      while (next <= distance + length) {
        next += spacing;
      }
    }
    distance += length;
  }
  if (to == points.length) stamp(points.last.offset, distance);

  for (var step = 0; step < _rainbowSteps; step++) {
    if (buckets[step].isEmpty) continue;
    canvas.drawPoints(
      PointMode.points,
      buckets[step],
      _linePaint(rainbowColorAt(step / _rainbowSteps * rainbowPeriod), width),
    );
  }
}

/// Length of the polyline [points] up to (excluding) index [end].
double polylineLength(List<SheetPoint> points, [int? end]) {
  var total = 0.0;
  final last = end ?? points.length;
  for (var i = 1; i < last; i++) {
    total += points[i].distanceTo(points[i - 1]);
  }
  return total;
}

/// Paints a sticker in its local coordinates, or a "?" placeholder when its
/// artwork is not available (ADR 0018).
void paintSticker(
  Canvas canvas,
  StickerElement sticker,
  StickerArtwork? stickers,
) {
  final picture = stickers?.pictureFor(sticker.packId, sticker.elementId);
  final half = sticker.size / 2;
  if (picture != null) {
    final scale = sticker.size / stickers!.size;
    canvas
      ..save()
      ..translate(-half, -half)
      ..scale(scale)
      ..drawPicture(picture)
      ..restore();
    return;
  }
  final box = RRect.fromRectAndRadius(
    sticker.localBounds.deflate(sticker.size * 0.08),
    Radius.circular(sticker.size * 0.15),
  );
  canvas
    ..drawRRect(box, Paint()..color = const Color(0xFFEDE7DD))
    ..drawRRect(
      box,
      Paint()
        ..color = const Color(0xFFB9AE9E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sticker.size * 0.03,
    );
  final question = TextPainter(
    text: TextSpan(
      text: '?',
      style: TextStyle(
        fontSize: sticker.size * 0.5,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF8C8173),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  question.paint(canvas, Offset(-question.width / 2, -question.height / 2));
}
