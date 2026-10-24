import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../document/drawing.dart';
import '../document/drawing_element.dart';
import '../document/sheet_point.dart';
import '../document/stroke_element.dart';
import '../document/stroke_tool.dart';
import '../geometry/hit_test.dart';
import 'live_stroke.dart';
import 'paper_grain.dart';
import 'stroke_painter.dart';

/// Renders a [Drawing] and the stroke in progress.
///
/// The GPU cost of a frame is dominated by how many times the whole sheet is
/// filled, so the renderer makes sure a frame covers the sheet **once**
/// (ADR 0005):
///
/// - The **cache** is an opaque image of the background and of every
///   committed element. It is updated incrementally when a stroke is added or
///   an eraser pass is applied, and rebuilt otherwise (undo, redo, clear,
///   density changes).
/// - While a stroke is drawn, its older part is periodically **frozen** into a
///   copy of the cache (the *working* image), and only the tail is painted
///   live. The cost per frame does not grow with the length of the stroke.
/// - The eraser paints the background along its path instead of punching
///   holes in a layer: the result is the same and no extra layer is needed.
class DrawingRenderer extends ChangeNotifier {
  /// Creates a renderer that draws grain with [grain] on a [background].
  DrawingRenderer({
    required this.grain,
    this.background = const ui.Color(0xFFFFFFFF),
  });

  /// Paper texture shared by every stroke.
  final PaperGrain grain;

  /// Color of the sheet.
  final ui.Color background;

  /// How many new points of the live stroke trigger a freeze.
  static const int freezeBatch = 48;

  Drawing? _drawing;
  ui.Image? _cache;
  double _pixelScale = 1;
  bool _cacheEnabled = true;

  /// Elements painted on top of everything, outside the cache: the one being
  /// moved or edited (ADR 0005). Their committed versions are hidden.
  List<DrawingElement> _floating = const [];
  Set<String> _hidden = const {};

  int _liveGeneration = -1;
  int _frozenUntil = 0;
  ui.Image? _working;

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
    _resetLive();
    _rebuild();
  }

  /// Device pixels per sheet unit. Changing it rebuilds the cache.
  double get pixelScale => _pixelScale;
  set pixelScale(double value) {
    if ((value - _pixelScale).abs() < 1e-6) return;
    _pixelScale = value;
    // The frozen live stroke was rendered at the old density.
    _resetLive();
    _rebuild();
  }

  /// Shows [drawing], updating the cache as cheaply as possible.
  ///
  /// [floating] elements are painted on top of everything without touching
  /// the cache, so they can follow a finger at full frame rate. If one of
  /// them is also in the drawing (an element being moved), its committed
  /// version is left out of the cache meanwhile.
  void show(Drawing drawing, {List<DrawingElement> floating = const []}) {
    final previous = _drawing;
    _drawing = drawing;
    final hidden = {
      for (final f in floating)
        if (drawing.elementById(f.id) != null) f.id,
    };
    final hiddenChanged = !setEquals(hidden, _hidden);
    _floating = floating;
    _hidden = hidden;
    if (!hiddenChanged && identical(previous, drawing)) {
      notifyListeners();
    } else if (!hiddenChanged &&
        previous != null &&
        _isAppend(previous, drawing) &&
        !hidden.contains(drawing.elements.last.id)) {
      _update((canvas) => paintElement(canvas, drawing.elements.last, grain));
    } else {
      _rebuild();
    }
  }

  /// Shows [drawing], which is the previous drawing after [erasure] was
  /// applied: the cache is updated by painting the background along the
  /// eraser path.
  ///
  /// Elements the eraser does not affect (texts...) would be covered by the
  /// background: when the pass crosses one, the cache is rebuilt instead.
  void showErased(Drawing drawing, Erasure erasure) {
    _drawing = drawing;
    final area = polylineBounds(erasure.points).inflate(erasure.width);
    if (_protectedIn(drawing, area).isNotEmpty) {
      _rebuild();
      return;
    }
    _update(
      (canvas) => _paintBackgroundStroke(canvas, erasure.points, erasure.width),
    );
  }

  /// Elements the eraser leaves untouched whose bounds meet [area].
  Iterable<DrawingElement> _protectedIn(Drawing drawing, ui.Rect area) =>
      drawing.elements.where(
        (e) =>
            !e.erasable && !_hidden.contains(e.id) && e.bounds.overlaps(area),
      );

  /// Paints the background along an eraser path, then repaints on top the
  /// elements the eraser does not affect. During a live pass the z-order of
  /// those elements is approximate; it is exact again once the pass is
  /// committed.
  void _paintEraserPreview(
    ui.Canvas canvas,
    List<SheetPoint> points,
    double width,
  ) {
    _paintBackgroundStroke(canvas, points, width);
    final drawing = _drawing;
    if (drawing == null || points.isEmpty) return;
    final area = polylineBounds(points).inflate(width);
    for (final element in _protectedIn(drawing, area)) {
      paintElement(canvas, element, grain);
    }
  }

  /// Paints the sheet with the committed content and [live] on top, in sheet
  /// coordinates.
  void paint(ui.Canvas canvas, LiveStroke live) {
    final drawing = _drawing;
    if (drawing == null) return;
    final cache = _cache;
    if (!_cacheEnabled || cache == null) {
      _paintUncached(canvas, drawing, live);
      return;
    }
    final hasLive = live.points.isNotEmpty;
    if (hasLive) _syncFrozen(live);
    _paintImage(canvas, hasLive ? (_working ?? cache) : cache);
    if (hasLive) _paintTail(canvas, live);
    _paintFloating(canvas);
  }

  void _paintFloating(ui.Canvas canvas) {
    for (final element in _floating) {
      paintElement(canvas, element, grain);
    }
  }

  // ---------------------------------------------------------------------------
  // Live stroke

  /// Paints the points of [live] that are not frozen yet.
  void _paintTail(ui.Canvas canvas, LiveStroke live) {
    final start = _tailStart(live);
    final tool = live.tool;
    if (tool == null) {
      _paintEraserPreview(canvas, live.points.sublist(start), live.width);
    } else {
      _paintInkRange(canvas, live, tool, start, live.points.length);
    }
  }

  /// Paints the points [from]..[to] of an ink stroke, grain included.
  ///
  /// When the range continues an earlier piece, the round cap where they meet
  /// was already painted by that piece. It is clipped out here (minus half a
  /// pixel, so no hairline shows) to avoid painting grain twice there.
  void _paintInkRange(
    ui.Canvas canvas,
    LiveStroke live,
    StrokeTool tool,
    int from,
    int to,
  ) {
    final strength = grainStrength(tool);
    if (strength == 0) {
      paintStrokeInk(
        canvas,
        tool,
        live.color,
        live.width,
        live.points,
        from: from,
        to: to,
      );
      return;
    }
    final bounds = polylineBounds(
      live.points.sublist(from, to),
    ).inflate(live.width);
    canvas.saveLayer(bounds, ui.Paint());
    if (from > 0) {
      final joint = live.points[from].offset;
      final radius = live.width / 2 - 0.5 / _pixelScale;
      canvas.clipPath(
        ui.Path()
          ..fillType = ui.PathFillType.evenOdd
          ..addRect(bounds)
          ..addOval(ui.Rect.fromCircle(center: joint, radius: radius)),
        doAntiAlias: false,
      );
    }
    paintStrokeInk(
      canvas,
      tool,
      live.color,
      live.width,
      live.points,
      from: from,
      to: to,
    );
    paintGrain(canvas, bounds, strength, grain);
    canvas.restore();
  }

  /// Index of the first point that is still painted live. The tail starts
  /// at the last frozen point, so the two pieces join.
  int _tailStart(LiveStroke live) {
    if (_frozenUntil == 0) return 0;
    return (_frozenUntil - 1).clamp(0, live.points.length - 1);
  }

  /// Freezes the older points of the live stroke when enough have arrived.
  void _syncFrozen(LiveStroke live) {
    if (live.generation != _liveGeneration) {
      _resetLive();
      _liveGeneration = live.generation;
    }
    final cache = _cache;
    if (cache == null) return;
    // The newest points stay live: smoothing still moves them.
    const keep = 8;
    final end = live.points.length - keep;
    if (end - _frozenUntil < freezeBatch) return;

    final start = _tailStart(live);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final base = _working ?? cache;
    canvas
      ..drawImage(
        base,
        ui.Offset.zero,
        ui.Paint()..blendMode = ui.BlendMode.src,
      )
      ..scale(_pixelScale);
    final tool = live.tool;
    if (tool == null) {
      _paintEraserPreview(canvas, live.points.sublist(start, end), live.width);
    } else {
      _paintInkRange(canvas, live, tool, start, end);
    }
    final picture = recorder.endRecording();
    final working = picture.toImageSync(base.width, base.height);
    picture.dispose();
    _working?.dispose();
    _working = working;
    _frozenUntil = end;
  }

  void _resetLive() {
    _liveGeneration = -1;
    _frozenUntil = 0;
    _working?.dispose();
    _working = null;
  }

  // ---------------------------------------------------------------------------
  // Committed content

  bool _isAppend(Drawing previous, Drawing next) {
    if (next.elements.length != previous.elements.length + 1) return false;
    for (var i = 0; i < previous.elements.length; i++) {
      if (!identical(previous.elements[i], next.elements[i])) return false;
    }
    return true;
  }

  void _paintBackground(ui.Canvas canvas, ui.Size sheetSize) {
    canvas.drawRect(ui.Offset.zero & sheetSize, ui.Paint()..color = background);
  }

  /// Paints the background along [points]: what the eraser leaves behind.
  void _paintBackgroundStroke(
    ui.Canvas canvas,
    List<SheetPoint> points,
    double width,
  ) {
    paintEraser(canvas, points, width, color: background);
  }

  void _paintElements(ui.Canvas canvas, Drawing drawing) {
    for (final element in drawing.elements) {
      if (!_hidden.contains(element.id)) paintElement(canvas, element, grain);
    }
  }

  /// Slow path, used to measure the benefit of the cache: everything is
  /// painted from scratch every frame.
  void _paintUncached(ui.Canvas canvas, Drawing drawing, LiveStroke live) {
    _paintBackground(canvas, drawing.sheetSize);
    _paintElements(canvas, drawing);
    _paintFloating(canvas);
    if (live.points.isEmpty) return;
    final tool = live.tool;
    if (tool == null) {
      _paintEraserPreview(canvas, live.points, live.width);
    } else {
      paintStroke(
        canvas,
        StrokeElement(
          id: 'live',
          tool: tool,
          color: live.color,
          width: live.width,
          points: live.points,
        ),
        grain,
      );
    }
  }

  void _paintImage(ui.Canvas canvas, ui.Image image) {
    final drawing = _drawing!;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Offset.zero & drawing.sheetSize,
      ui.Paint()
        // The cache is opaque: no need to blend with what is underneath.
        ..blendMode = ui.BlendMode.src
        ..filterQuality = ui.FilterQuality.low,
    );
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
      ..drawImage(old, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.src)
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
      _paintBackground(canvas, drawing.sheetSize);
      _paintElements(canvas, drawing);
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
    _working?.dispose();
    _cache?.dispose();
    super.dispose();
  }
}
