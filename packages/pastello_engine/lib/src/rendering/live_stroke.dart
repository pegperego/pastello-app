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
  int _generation = 0;

  /// The tool, or `null` for the eraser.
  StrokeTool? tool;

  /// Ink color (ignored by the eraser and the rainbow).
  Color color = const Color(0xFF000000);

  /// Width in sheet units.
  double width = 8;

  /// Seed of the random pieces of the magic brushes.
  int seed = 0;

  /// Points collected so far.
  final List<SheetPoint> points = [];

  /// Whether the live stroke is an eraser pass.
  bool get isEraser => tool == null;

  /// Changes every time a new stroke begins, so renderers can tell strokes
  /// apart even when they have the same number of points.
  int get generation => _generation;

  /// Starts a new stroke.
  void begin({
    required StrokeTool? tool,
    required Color color,
    required double width,
    int seed = 0,
  }) {
    this.tool = tool;
    this.seed = seed;
    this.color = color;
    this.width = width;
    points.clear();
    _generation++;
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
