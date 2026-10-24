import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../document/sheet_point.dart';
import '../document/stroke_tool.dart';

/// The stroke currently being drawn.
///
/// It is deliberately a plain [ChangeNotifier] outside of the app's state
/// management: pointer moves repaint the sheet without rebuilding any widget
/// (ADR 0009).
class LiveStroke extends ChangeNotifier {
  final _Signal _eraserRepaint = _Signal();
  int _generation = 0;

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

  /// Changes every time a new stroke begins, so renderers can tell strokes
  /// apart even when they have the same number of points.
  int get generation => _generation;

  /// Notifies only for eraser passes.
  ///
  /// The eraser preview has to repaint the committed content; ink strokes
  /// don't, so the committed layer listens to this instead of the stroke.
  Listenable get eraserRepaint => _eraserRepaint;

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
    _generation++;
  }

  /// Adds a point and repaints.
  void add(SheetPoint point) {
    points.add(point);
    notifyListeners();
    if (isEraser) _eraserRepaint.ping();
  }

  /// Discards the stroke.
  void clear() {
    final wasEraser = isEraser;
    points.clear();
    notifyListeners();
    if (wasEraser) _eraserRepaint.ping();
  }

  @override
  void dispose() {
    _eraserRepaint.dispose();
    super.dispose();
  }
}

class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}
