import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'drawing_renderer.dart';
import 'live_stroke.dart';

/// Paints the sheet background and the committed content.
///
/// It repaints when the drawing changes and during eraser passes, but not
/// while an ink stroke is drawn: that is [LiveStrokePainter]'s job, on its
/// own layer, so the bottom layer is reused as is (ADR 0005).
///
/// The canvas is scaled so that the sheet fills the painted area.
class CommittedPainter extends CustomPainter {
  /// Creates a painter for the committed content of [renderer].
  CommittedPainter({
    required this.renderer,
    required this.live,
    required this.sheetSize,
    this.background = const Color(0xFFFFFFFF),
  }) : super(repaint: Listenable.merge([renderer, live.eraserRepaint]));

  /// Committed content.
  final DrawingRenderer renderer;

  /// Stroke in progress, needed for the eraser preview.
  final LiveStroke live;

  /// Logical size of the sheet.
  final Size sheetSize;

  /// Sheet background color.
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = Offset.zero & sheetSize;
    canvas
      ..save()
      ..scale(size.width / sheetSize.width)
      ..clipRect(sheet)
      ..drawRect(sheet, Paint()..color = background);
    renderer.paintWithEraser(canvas, live);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CommittedPainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.live != live ||
      oldDelegate.sheetSize != sheetSize ||
      oldDelegate.background != background;
}

/// Paints the ink stroke in progress, on top of [CommittedPainter].
class LiveStrokePainter extends CustomPainter {
  /// Creates a painter for [live].
  LiveStrokePainter({
    required this.renderer,
    required this.live,
    required this.sheetSize,
  }) : super(repaint: live);

  /// Renderer that keeps the frozen part of the stroke.
  final DrawingRenderer renderer;

  /// Stroke in progress.
  final LiveStroke live;

  /// Logical size of the sheet.
  final Size sheetSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (live.isEraser || live.points.isEmpty) return;
    canvas
      ..save()
      ..scale(size.width / sheetSize.width)
      ..clipRect(Offset.zero & sheetSize);
    renderer.paintLiveInk(canvas, live);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiveStrokePainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.live != live ||
      oldDelegate.sheetSize != sheetSize;
}

/// Paints everything on a single canvas: [CommittedPainter] followed by
/// [LiveStrokePainter].
///
/// Simpler to use, for tests and thumbnails. Interactive views should use the
/// two painters on separate layers instead.
class SheetPainter extends CustomPainter {
  /// Creates a painter for [renderer] and [live].
  SheetPainter({
    required this.renderer,
    required this.live,
    required this.sheetSize,
    this.background = const Color(0xFFFFFFFF),
  }) : _committed = CommittedPainter(
         renderer: renderer,
         live: live,
         sheetSize: sheetSize,
         background: background,
       ),
       _live = LiveStrokePainter(
         renderer: renderer,
         live: live,
         sheetSize: sheetSize,
       ),
       super(repaint: Listenable.merge([renderer, live]));

  /// Committed content.
  final DrawingRenderer renderer;

  /// Stroke in progress.
  final LiveStroke live;

  /// Logical size of the sheet.
  final Size sheetSize;

  /// Sheet background color.
  final Color background;

  final CommittedPainter _committed;
  final LiveStrokePainter _live;

  @override
  void paint(Canvas canvas, Size size) {
    _committed.paint(canvas, size);
    _live.paint(canvas, size);
  }

  @override
  bool shouldRepaint(SheetPainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.live != live ||
      oldDelegate.sheetSize != sheetSize ||
      oldDelegate.background != background;
}
