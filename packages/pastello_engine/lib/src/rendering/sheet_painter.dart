import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../document/sheet_point.dart';
import '../document/stroke_element.dart';
import '../document/stroke_tool.dart';
import 'drawing_renderer.dart';
import 'stroke_painter.dart';

/// The stroke currently being drawn.
///
/// It is deliberately a plain [ChangeNotifier] outside of the app's state
/// management: pointer moves repaint the sheet without rebuilding any widget
/// (ADR 0009).
class LiveStroke extends ChangeNotifier {
  /// The tool, or `null` for the eraser.
  StrokeTool? tool;

  /// Ink color (ignored by the eraser and the rainbow).
  Color color = const Color(0xFF000000);

  /// Width in sheet units.
  double width = 8;

  /// Points collected so far.
  final List<SheetPoint> points = [];

  /// Whether the live stroke is an eraser pass.
  bool get isEraser => tool == null;

  /// Starts a new stroke.
  void begin({
    required StrokeTool? tool,
    required Color color,
    required double width,
  }) {
    this.tool = tool;
    this.color = color;
    this.width = width;
    points.clear();
  }

  /// Adds a point and repaints.
  void add(SheetPoint point) {
    points.add(point);
    notifyListeners();
  }

  /// Discards the stroke.
  void clear() {
    points.clear();
    notifyListeners();
  }
}

/// Paints a sheet: background, committed content and the live stroke.
///
/// The canvas is scaled so that the sheet fills the painted area.
class SheetPainter extends CustomPainter {
  /// Creates a painter for [renderer] and [live].
  SheetPainter({
    required this.renderer,
    required this.live,
    required this.sheetSize,
    this.background = const Color(0xFFFFFFFF),
  }) : super(repaint: Listenable.merge([renderer, live]));

  /// Committed content.
  final DrawingRenderer renderer;

  /// Stroke in progress.
  final LiveStroke live;

  /// Logical size of the sheet.
  final Size sheetSize;

  /// Sheet background color.
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / sheetSize.width);
    final sheet = Offset.zero & sheetSize;
    canvas
      ..clipRect(sheet)
      ..drawRect(sheet, Paint()..color = background);

    if (live.isEraser && live.points.isNotEmpty) {
      // Preview the eraser on committed content only, never on the background.
      canvas.saveLayer(sheet, Paint());
      renderer.paint(canvas);
      paintEraser(canvas, live.points, live.width);
      canvas.restore();
    } else {
      renderer.paint(canvas);
      final tool = live.tool;
      if (tool != null && live.points.isNotEmpty) {
        // Painted exactly like a committed stroke, grain included, so nothing
        // changes when the finger lifts.
        paintStroke(
          canvas,
          StrokeElement(
            id: 'live',
            tool: tool,
            color: live.color,
            width: live.width,
            points: live.points,
          ),
          renderer.grain,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SheetPainter oldDelegate) =>
      oldDelegate.renderer != renderer ||
      oldDelegate.live != live ||
      oldDelegate.sheetSize != sheetSize ||
      oldDelegate.background != background;
}
