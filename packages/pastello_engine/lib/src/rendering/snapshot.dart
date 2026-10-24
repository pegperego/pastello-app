import 'dart:ui' as ui;

import '../document/drawing.dart';
import 'paper_grain.dart';
import 'stroke_painter.dart';

/// Renders [drawing] on its [background] into a picture [width] pixels wide,
/// keeping the sheet's proportions.
///
/// Used for gallery thumbnails and, later, for exporting images. Call
/// `toImage` on the result to get pixels.
ui.Picture renderDrawing(
  Drawing drawing,
  PaperGrain grain, {
  required int width,
  ui.Color background = const ui.Color(0xFFFFFFFF),
}) {
  final scale = width / drawing.sheetSize.width;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(scale);
  canvas.drawRect(
    ui.Offset.zero & drawing.sheetSize,
    ui.Paint()..color = background,
  );
  for (final element in drawing.elements) {
    paintStroke(canvas, element, grain);
  }
  return recorder.endRecording();
}

/// Height in pixels of a [renderDrawing] picture [width] pixels wide.
int renderedHeight(Drawing drawing, int width) =>
    (width * drawing.sheetSize.height / drawing.sheetSize.width).round();
