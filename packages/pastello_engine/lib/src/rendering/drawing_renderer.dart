import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../document/drawing.dart';
import '../document/stroke_element.dart';
import '../document/stroke_tool.dart';
import '../geometry/hit_test.dart';
import 'live_stroke.dart';
import 'paper_grain.dart';
import 'stroke_painter.dart';

/// Renders a [Drawing], keeping committed content in a raster cache.
///
/// The cache is an image of every committed element at the current pixel
/// density. Painting a frame then costs one image draw, regardless of how many
/// strokes the drawing has (ADR 0005). The cache is updated incrementally when
/// a stroke is added or an eraser pass is applied, and rebuilt from scratch
/// otherwise (undo, redo, clear, density changes).
///
/// The stroke in progress gets the same treatment while it is being drawn:
/// its older part is periodically "frozen" into an image and only the tail is
/// redrawn every frame, so the cost per frame does not grow with the length
/// of the stroke.
class DrawingRenderer extends ChangeNotifier {
  /// Creates a renderer that draws grain with [grain].
  DrawingRenderer({required this.grain});

  /// Paper texture shared by every stroke.
  final PaperGrain grain;

  Drawing? _drawing;
  ui.Image? _cache;
  double _pixelScale = 1;
  bool _cacheEnabled = true;

  // Frozen part of the live stroke (see [paintLiveInk]).
  int _liveGeneration = -1;
  int _frozenUntil = 0;
  ui.Image? _frozen;

  /// How many new points of the live stroke trigger a freeze.
  static const int freezeBatch = 32;

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
    // The frozen live stroke was rendered at the old density.
    _liveGeneration = -1;
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

  /// Paints the ink of the live stroke, grain included, in sheet
  /// coordinates. Does nothing for eraser passes, see [paintWithEraser].
  ///
  /// The result is identical to painting the whole stroke at once: the frozen
  /// part only contains ink, and the grain is applied to frozen part and tail
  /// together.
  void paintLiveInk(ui.Canvas canvas, LiveStroke live) {
    final tool = live.tool;
    if (tool == null || live.points.isEmpty) return;
    _syncFrozen(live);
    final start = _tailStart(live);
    final strength = grainStrength(tool);
    final bounds = polylineBounds(live.points).inflate(live.width);

    if (strength > 0) canvas.saveLayer(bounds, ui.Paint());
    _paintFrozen(canvas);
    paintStrokeInk(
      canvas,
      tool,
      live.color,
      live.width,
      live.points,
      from: start,
    );
    if (strength > 0) {
      paintGrain(canvas, bounds, strength, grain);
      canvas.restore();
    }
  }

  /// Paints the committed content with the live eraser pass previewed on
  /// top, in sheet coordinates. Falls back to [paint] for ink strokes.
  void paintWithEraser(ui.Canvas canvas, LiveStroke live) {
    final drawing = _drawing;
    if (drawing == null) return;
    if (!live.isEraser || live.points.isEmpty) {
      paint(canvas);
      return;
    }
    _syncFrozen(live);
    // For the eraser the frozen image is the committed content with the
    // frozen part of the pass already cleared.
    canvas.saveLayer(ui.Offset.zero & drawing.sheetSize, ui.Paint());
    if (_frozen != null) {
      _paintFrozen(canvas);
    } else {
      paint(canvas);
    }
    paintEraser(canvas, live.points.sublist(_tailStart(live)), live.width);
    canvas.restore();
  }

  /// Index of the first point that is still painted live.
  ///
  /// The tail overlaps the frozen part by one point so the two join.
  int _tailStart(LiveStroke live) {
    if (_frozenUntil == 0) return 0;
    return (_frozenUntil - 1).clamp(0, live.points.length - 1);
  }

  /// Freezes the older points of the live stroke when enough have arrived.
  void _syncFrozen(LiveStroke live) {
    if (live.generation != _liveGeneration) {
      _liveGeneration = live.generation;
      _frozenUntil = 0;
      _frozen?.dispose();
      _frozen = null;
    }
    final drawing = _drawing;
    if (!_cacheEnabled || drawing == null) return;
    // Keep the newest points live: the brush outline still changes there.
    final keep = live.tool == StrokeTool.brush ? 8 : 4;
    final end = live.points.length - keep;
    if (end - _frozenUntil < freezeBatch) return;

    final width = (drawing.sheetSize.width * _pixelScale).ceil();
    final height = (drawing.sheetSize.height * _pixelScale).ceil();
    if (width <= 0 || height <= 0) return;

    final start = _tailStart(live);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final previous = _frozen;
    if (previous != null) {
      canvas.drawImage(previous, ui.Offset.zero, ui.Paint());
      canvas.scale(_pixelScale);
    } else {
      canvas.scale(_pixelScale);
      if (live.isEraser) paint(canvas);
    }
    final tool = live.tool;
    if (tool == null) {
      paintEraser(canvas, live.points.sublist(start, end), live.width);
    } else {
      paintStrokeInk(
        canvas,
        tool,
        live.color,
        live.width,
        live.points,
        from: start,
        to: end,
      );
    }
    final picture = recorder.endRecording();
    _frozen = picture.toImageSync(width, height);
    picture.dispose();
    previous?.dispose();
    _frozenUntil = end;
  }

  void _paintFrozen(ui.Canvas canvas) {
    final frozen = _frozen;
    final drawing = _drawing;
    if (frozen == null || drawing == null) return;
    canvas.drawImageRect(
      frozen,
      ui.Rect.fromLTWH(0, 0, frozen.width.toDouble(), frozen.height.toDouble()),
      ui.Offset.zero & drawing.sheetSize,
      ui.Paint()..filterQuality = ui.FilterQuality.low,
    );
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
    final width = (drawing.sheetSize.width * _pixelScale).ceil();
    final height = (drawing.sheetSize.height * _pixelScale).ceil();
    // An empty sheet or a view that is not laid out yet cannot be cached.
    if (_cacheEnabled && width > 0 && height > 0) {
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
    _frozen?.dispose();
    _cache?.dispose();
    super.dispose();
  }
}
