import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../document/drawing.dart';
import '../document/stroke_element.dart';
import 'paper_grain.dart';
import 'stroke_painter.dart';

/// Renders a [Drawing], keeping committed content in a raster cache.
///
/// The cache is an image of every committed element at the current pixel
/// density. Painting a frame then costs one image draw, regardless of how many
/// strokes the drawing has (ADR 0005). The cache is updated incrementally when
/// a stroke is added or an eraser pass is applied, and rebuilt from scratch
/// otherwise (undo, redo, clear, density changes).
class DrawingRenderer extends ChangeNotifier {
  /// Creates a renderer that draws grain with [grain].
  DrawingRenderer({required this.grain});

  /// Paper texture shared by every stroke.
  final PaperGrain grain;

  Drawing? _drawing;
  ui.Image? _cache;
  double _pixelScale = 1;
  bool _cacheEnabled = true;

  /// Duration of the last cache update, for the performance panel.
  Duration lastCacheUpdate = Duration.zero;

  /// Whether the last cache update was a full rebuild.
  bool lastUpdateWasRebuild = false;

  /// The drawing currently shown.
  Drawing? get drawing => _drawing;

  /// Whether the raster cache is used. Disable it to measure its benefit.
  bool get cacheEnabled => _cacheEnabled;
  set cacheEnabled(bool value) {
    if (value == _cacheEnabled) return;
    _cacheEnabled = value;
    _rebuild();
  }

  /// Device pixels per sheet unit. Changing it rebuilds the cache.
  double get pixelScale => _pixelScale;
  set pixelScale(double value) {
    if ((value - _pixelScale).abs() < 1e-6) return;
    _pixelScale = value;
    _rebuild();
  }

  /// Shows [drawing], updating the cache as cheaply as possible.
  void show(Drawing drawing) {
    final previous = _drawing;
    _drawing = drawing;
    if (previous != null && _isAppend(previous, drawing)) {
      _update((canvas) => paintStroke(canvas, drawing.elements.last, grain));
    } else {
      _rebuild();
    }
  }

  /// Shows [drawing], which is the previous drawing after [erasure] was
  /// applied: the cache is updated by clearing the eraser path only.
  void showErased(Drawing drawing, Erasure erasure) {
    _drawing = drawing;
    _update((canvas) => paintEraser(canvas, erasure.points, erasure.width));
  }

  /// Paints the committed content on [canvas], in sheet coordinates.
  void paint(ui.Canvas canvas) {
    final drawing = _drawing;
    if (drawing == null) return;
    final cache = _cache;
    if (_cacheEnabled && cache != null) {
      final sheet = ui.Offset.zero & drawing.sheetSize;
      canvas.drawImageRect(
        cache,
        ui.Rect.fromLTWH(0, 0, cache.width.toDouble(), cache.height.toDouble()),
        sheet,
        ui.Paint()..filterQuality = ui.FilterQuality.low,
      );
    } else {
      _paintAll(canvas, drawing);
    }
  }

  bool _isAppend(Drawing previous, Drawing next) {
    if (next.elements.length != previous.elements.length + 1) return false;
    for (var i = 0; i < previous.elements.length; i++) {
      if (!identical(previous.elements[i], next.elements[i])) return false;
    }
    return true;
  }

  void _paintAll(ui.Canvas canvas, Drawing drawing) {
    for (final element in drawing.elements) {
      paintStroke(canvas, element, grain);
    }
  }

  /// Draws the old cache plus [paintDelta] into a new cache image.
  void _update(void Function(ui.Canvas canvas) paintDelta) {
    final old = _cache;
    if (!_cacheEnabled || old == null) {
      _rebuild();
      return;
    }
    final watch = Stopwatch()..start();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawImage(old, ui.Offset.zero, ui.Paint())
      ..scale(_pixelScale);
    paintDelta(canvas);
    _replaceCache(recorder.endRecording(), old.width, old.height);
    lastCacheUpdate = watch.elapsed;
    lastUpdateWasRebuild = false;
    notifyListeners();
  }

  void _rebuild() {
    final drawing = _drawing;
    if (drawing == null) return;
    final watch = Stopwatch()..start();
    if (_cacheEnabled) {
      final width = (drawing.sheetSize.width * _pixelScale).ceil();
      final height = (drawing.sheetSize.height * _pixelScale).ceil();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(_pixelScale);
      _paintAll(canvas, drawing);
      _replaceCache(recorder.endRecording(), width, height);
    } else {
      _cache?.dispose();
      _cache = null;
    }
    lastCacheUpdate = watch.elapsed;
    lastUpdateWasRebuild = true;
    notifyListeners();
  }

  void _replaceCache(ui.Picture picture, int width, int height) {
    final image = picture.toImageSync(width, height);
    picture.dispose();
    _cache?.dispose();
    _cache = image;
  }

  @override
  void dispose() {
    _cache?.dispose();
    super.dispose();
  }
}
