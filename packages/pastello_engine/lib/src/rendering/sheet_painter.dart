import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'drawing_renderer.dart';
import 'live_stroke.dart';

/// Paints a sheet: committed content and the stroke in progress.
///
/// The canvas is scaled so that the sheet fills the painted area. Wrap it in
/// a `RepaintBoundary`: it repaints on every pointer move.
class SheetPainter extends CustomPainter {
  /// Creates a painter for [renderer] and [live].
  SheetPainter({
    required this.renderer,
    required this.live,
    required this.sheetSize,
  }) : super(repaint: Listenable.merge([renderer, live]));

  /// Committed content.
  final DrawingRenderer renderer;

  /// Stroke in progress.
  final LiveStroke live;

  /// Logical size of the sheet.
  final Size sheetSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / sheetSize.width)
      ..clipRect(Offset.zero & sheetSize);
    renderer.paint(canvas, live);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SheetPainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.live != live ||
      oldDelegate.sheetSize != sheetSize;
}
