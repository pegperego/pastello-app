import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../document/drawing.dart';
import '../document/drawing_element.dart';
import '../document/fill_element.dart';
import '../document/shape_element.dart';
import '../document/stroke_element.dart';
import '../geometry/bucket_fill.dart';
import 'coloring.dart';
import 'stroke_painter.dart';

/// Whether the paint bucket stops at [element] (F-18): strokes of solid
/// tools and shapes do; fills, texts and stickers do not.
bool isBucketBorder(DrawingElement element) => switch (element) {
  StrokeElement(:final tool) => tool.isBorder,
  ShapeElement() => true,
  _ => false,
};

/// The topmost border of [drawing] whose ink covers [point], or `null`
/// (F-18: a tap of the paint bucket on a line recolors the line).
///
/// The test paints each candidate on a single pixel, so it agrees with the
/// borders [bucketFill] sees.
Future<DrawingElement?> bucketBorderAt(Drawing drawing, ui.Offset point) async {
  for (final element in drawing.paintOrder.reversed) {
    if (!isBucketBorder(element) || !element.bounds.contains(point)) continue;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..translate(-point.dx.floorToDouble(), -point.dy.floorToDouble());
    _paintBorder(canvas, element);
    if ((await _alpha(recorder.endRecording(), 1, 1))[0] != 0) return element;
  }
  return null;
}

/// The area a tap of the paint bucket at [point] colors, or `null` when
/// there is nothing to color there (ADR 0021).
///
/// The borders are painted at one pixel per sheet unit; the area is then
/// computed in another isolate, so the editor stays responsive. The outline
/// of a coloring page, taken from [coloring], is a border too (ADR 0022).
Future<FillMask?> bucketFill(
  Drawing drawing,
  ui.Offset point, {
  ColoringArtwork? coloring,
}) async {
  final width = drawing.sheetSize.width.ceil();
  final height = drawing.sheetSize.height.ceil();
  if (width <= 0 || height <= 0) return null;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (final element in drawing.paintOrder) {
    if (isBucketBorder(element)) _paintBorder(canvas, element);
  }
  if (drawing.outline != null) {
    // Only the dark lines of the page are walls: a white area in the
    // artwork must not stop the color.
    canvas.saveLayer(null, ui.Paint()..colorFilter = _darkness);
    paintOutline(canvas, drawing, coloring);
    canvas.restore();
  }
  final walls = await _alpha(recorder.endRecording(), width, height);
  final region = await compute(_region, (
    walls,
    width,
    height,
    point.dx.floor(),
    point.dy.floor(),
  ));
  if (region == null) return null;
  return FillMask(left: region.left, top: region.top, rows: region.rows);
}

/// Turns how dark a pixel is into its opacity, and its color into black.
const _darkness = ui.ColorFilter.matrix([
  0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  -0.2126, -0.7152, -0.0722, 1, 0, //
]);

BucketRegion? _region((Uint8List, int, int, int, int) args) {
  final (walls, width, height, x, y) = args;
  return bucketRegion(walls, width, height, x, y);
}

/// One byte per pixel of [picture]: 1 where it is at least half opaque.
Future<Uint8List> _alpha(ui.Picture picture, int width, int height) async {
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  final rgba = data!.buffer.asUint8List();
  final walls = Uint8List(width * height);
  for (var i = 0; i < walls.length; i++) {
    if (rgba[i * 4 + 3] >= 128) walls[i] = 1;
  }
  return walls;
}

/// Paints the ink of a border, without grain: the holes of the crayon must
/// not let the color through.
void _paintBorder(ui.Canvas canvas, DrawingElement element) {
  const ink = ui.Color(0xFF000000);
  final t = element.transform;
  canvas
    ..save()
    ..transform(t.matrix);
  switch (element) {
    case StrokeElement():
      final erased = element.erasures.isNotEmpty;
      if (erased) canvas.saveLayer(element.localBounds, ui.Paint());
      paintStrokeInk(
        canvas,
        element.tool,
        ink,
        element.width,
        element.points,
        seed: element.seed,
      );
      for (final erasure in element.erasures) {
        paintEraser(canvas, erasure.points, erasure.width);
      }
      if (erased) canvas.restore();
    case ShapeElement():
      element.copyWith(color: ink).paintLocal(canvas);
  }
  canvas.restore();
}
