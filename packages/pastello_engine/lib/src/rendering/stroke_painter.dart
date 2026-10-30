import 'dart:math' as math;
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

/// Opacity of the highlighter. Its ink is painted opaque in a layer that is
/// composited with this opacity, so a stroke crossing itself does not get
/// darker.
const double highlighterOpacity = 0.45;

/// Paint for the layer a stroke drawn with [tool] is composited with.
Paint inkLayerPaint(StrokeTool tool) => tool == StrokeTool.highlighter
    ? (Paint()..color = const Color.fromRGBO(0, 0, 0, highlighterOpacity))
    : Paint();

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
  final needsLayer =
      strength > 0 ||
      stroke.erasures.isNotEmpty ||
      stroke.tool == StrokeTool.highlighter;
  final bounds = stroke.localBounds;

  if (needsLayer) canvas.saveLayer(bounds, inkLayerPaint(stroke.tool));
  paintStrokeInk(
    canvas,
    stroke.tool,
    stroke.color,
    stroke.width,
    stroke.points,
    seed: stroke.seed,
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
///
/// The random pieces of the magic brushes come from [seed] and from their
/// position along the whole stroke, so pieces painted separately are the
/// same as the whole stroke painted at once.
///
/// The neon paints its tube and core from [solidFrom] (default: [from]):
/// starting them earlier than the glow repaints them over the glow that a
/// piece spills onto the previous one.
void paintStrokeInk(
  Canvas canvas,
  StrokeTool tool,
  Color color,
  double width,
  List<SheetPoint> points, {
  int from = 0,
  int? to,
  int? solidFrom,
  int seed = 0,
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
    case StrokeTool.highlighter:
      canvas.drawPath(
        smoothPolyline(points.sublist(from, end)),
        _linePaint(color, width)..strokeCap = StrokeCap.square,
      );
    case StrokeTool.neon:
      _paintNeon(
        canvas,
        color,
        width,
        smoothPolyline(points.sublist(from, end)),
        smoothPolyline(points.sublist(solidFrom ?? from, end)),
        joint: (solidFrom ?? from) > 0
            ? points[solidFrom ?? from].offset
            : null,
      );
    case StrokeTool.glitter:
      _paintGlitter(canvas, color, width, seed, points, from, end);
    case StrokeTool.stars:
      _paintStars(canvas, color, width, seed, points, from, end);
    case StrokeTool.spray:
      _paintSpray(canvas, color, width, seed, points, from, end);
    case StrokeTool.watercolor:
      _paintWatercolor(canvas, color, width, seed, points, from, end);
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

/// Paints a neon tube: a blurred glow of [color] along [glow], then the
/// tube itself and a light core along [solid]. The glow stays within
/// [StrokeTool.margin].
///
/// When [solid] continues an earlier piece, the round cap of the tube at
/// the [joint] would cover the core already painted there: it is clipped
/// out.
void _paintNeon(
  Canvas canvas,
  Color color,
  double width,
  Path glow,
  Path solid, {
  Offset? joint,
}) {
  canvas.drawPath(
    glow,
    _linePaint(color.withValues(alpha: 0.6), width * 1.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.35),
  );
  if (joint != null) {
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(solid.getBounds().inflate(width))
          ..addOval(Rect.fromCircle(center: joint, radius: width * 0.35)),
      );
  }
  canvas
    ..drawPath(solid, _linePaint(color, width * 0.7))
    ..drawPath(
      solid,
      _linePaint(
        Color.lerp(color, const Color(0xFFFFFFFF), 0.75)!,
        width * 0.3,
      ),
    );
  if (joint != null) canvas.restore();
}

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

/// Calls [stamp] for the "stamps" spaced [spacing] apart along [points],
/// with their distance from the start of the stroke and their number.
///
/// Stamps are always counted from the start of the stroke, and only those
/// between the points [from] and [to] are reported, so a stroke painted in
/// pieces puts every stamp exactly where the whole stroke would, once.
void _walkStamps(
  List<SheetPoint> points,
  double spacing,
  int from,
  int to,
  void Function(Offset at, double distance, int index) stamp,
) {
  if (from == 0) stamp(points.first.offset, 0, 0);
  var distance = 0.0;
  var next = spacing;
  var index = 1;
  for (var i = 1; i < to; i++) {
    final a = points[i - 1].offset, b = points[i].offset;
    final length = (b - a).distance;
    // Segments before the range only advance the count.
    while (next <= distance + length) {
      if (i > from) {
        stamp(Offset.lerp(a, b, (next - distance) / length)!, next, index);
      }
      next += spacing;
      index++;
    }
    distance += length;
  }
  if (to == points.length && points.length > 1) {
    stamp(points.last.offset, distance, index);
  }
}

/// Paints the rainbow as round "stamps" spaced along the line.
///
/// Drawing one segment per color would show beads where round caps of
/// different colors overlap. Stamps placed every couple of units blend into a
/// continuous gradient, and grouping them by hue keeps it to at most
/// [_rainbowSteps] draw calls.
void _paintRainbow(
  Canvas canvas,
  double width,
  List<SheetPoint> points,
  int from,
  int to,
) {
  final spacing = (width / 8).clamp(0.75, 3.0);
  final buckets = List.generate(_rainbowSteps, (_) => <Offset>[]);
  _walkStamps(points, spacing, from, to, (at, distance, _) {
    final hueStep =
        ((distance / rainbowPeriod) * _rainbowSteps).floor() % _rainbowSteps;
    buckets[hueStep].add(at);
  });
  for (var step = 0; step < _rainbowSteps; step++) {
    if (buckets[step].isEmpty) continue;
    canvas.drawPoints(
      PointMode.points,
      buckets[step],
      _linePaint(rainbowColorAt(step / _rainbowSteps * rainbowPeriod), width),
    );
  }
}

/// A number in [0, 1) that depends only on [seed], [index] and [k]: the
/// same stamp of the same stroke always gets the same "random" look.
double _random(int seed, int index, int k) {
  var h = (seed ^ (index * 0x9E3779B1) ^ (k * 0x85EBCA77)) & 0xFFFFFFFF;
  h = ((h ^ (h >> 16)) * 0x7FEB352D) & 0xFFFFFFFF;
  h = ((h ^ (h >> 15)) * 0x846CA68B) & 0xFFFFFFFF;
  h ^= h >> 16;
  return h / 0x100000000;
}

/// A point at a random place within [radius] of [at]. With [centered] the
/// points are denser near the middle.
Offset _scatter(
  Offset at,
  double radius,
  int seed,
  int index,
  int k, {
  bool centered = false,
}) {
  final angle = _random(seed, index, k) * 2 * math.pi;
  final r = _random(seed, index, k + 1);
  final distance = radius * (centered ? r : math.sqrt(r));
  return at + Offset(math.cos(angle), math.sin(angle)) * distance;
}

/// Glitter: round sparkles of different sizes and brightness, with now and
/// then a bigger four-pointed twinkle.
void _paintGlitter(
  Canvas canvas,
  Color color,
  double width,
  int seed,
  List<SheetPoint> points,
  int from,
  int to,
) {
  final spacing = math.max(1.0, width * 0.1);
  final white = const Color(0xFFFFFFFF), black = const Color(0xFF000000);
  final paint = Paint();
  _walkStamps(points, spacing, from, to, (at, _, index) {
    final center = _scatter(at, width / 2, seed, index, 0);
    final shade = _random(seed, index, 2);
    // Most sparkles are lighter than the color, some a little darker.
    paint.color = shade < 0.25
        ? Color.lerp(color, black, shade)!
        : Color.lerp(color, white, (shade - 0.25) * 0.8)!;
    final size = math.max(0.6, width * (0.05 + 0.13 * _random(seed, index, 3)));
    if (_random(seed, index, 4) > 0.9) {
      paint.color = Color.lerp(color, white, 0.7)!;
      canvas.drawPath(_twinkle(center, size * 2.5), paint);
    } else {
      canvas.drawCircle(center, size, paint);
    }
  });
}

/// A four-pointed twinkle of radius [r].
Path _twinkle(Offset c, double r) {
  final w = r * 0.25;
  return Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
    ..close();
}

/// Stars: one every star and a half, each turned a little differently.
void _paintStars(
  Canvas canvas,
  Color color,
  double width,
  int seed,
  List<SheetPoint> points,
  int from,
  int to,
) {
  final size = starSize(width);
  final paint = Paint()..color = color;
  _walkStamps(points, size * 1.4, from, to, (at, _, index) {
    final turn = _random(seed, index, 0) * 2 * math.pi / 5;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? size / 2 : size / 4.4;
      final a = turn - math.pi / 2 + i * math.pi / 5;
      final p = at + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), paint);
  });
}

/// Spray: tiny dots scattered around the line, denser in the middle, in
/// three sizes (one draw call each).
void _paintSpray(
  Canvas canvas,
  Color color,
  double width,
  int seed,
  List<SheetPoint> points,
  int from,
  int to,
) {
  final spacing = math.max(1.0, width * 0.2);
  final dots = (3 + width * 0.7).round();
  final sizes = [
    for (final f in [0.7, 1.0, 1.4]) math.max(1.0, width * 0.05) * f,
  ];
  final buckets = [<Offset>[], <Offset>[], <Offset>[]];
  _walkStamps(points, spacing, from, to, (at, _, index) {
    for (var d = 0; d < dots; d++) {
      final k = d * 3;
      buckets[(_random(seed, index, k + 2) * 3).floor()].add(
        _scatter(at, width / 2, seed, index, k, centered: true),
      );
    }
  });
  for (var i = 0; i < 3; i++) {
    canvas.drawPoints(
      PointMode.points,
      buckets[i],
      _linePaint(color, sizes[i]),
    );
  }
}

/// Watercolor: soft, see-through blots with blurred edges. Each blot adds a
/// little color, so the middle of the line and the places painted twice
/// are darker.
void _paintWatercolor(
  Canvas canvas,
  Color color,
  double width,
  int seed,
  List<SheetPoint> points,
  int from,
  int to,
) {
  final spacing = math.max(1.0, width * 0.12);
  final paint = Paint();
  final clear = color.withValues(alpha: 0);
  _walkStamps(points, spacing, from, to, (at, _, index) {
    final radius = width / 2 * (0.92 + 0.16 * _random(seed, index, 0));
    final center = _scatter(at, width * 0.08, seed, index, 1);
    paint.shader = Gradient.radial(
      center,
      radius,
      [color.withValues(alpha: 0.12), color.withValues(alpha: 0.1), clear],
      const [0, 0.7, 1],
    );
    canvas.drawCircle(center, radius, paint);
  });
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
