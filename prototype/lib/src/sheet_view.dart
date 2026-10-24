import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pastello_engine/pastello_engine.dart';

import 'tokens.dart';

/// Shows the sheet scaled to fit the available space and turns pointer
/// events into sheet points.
///
/// Only the first pointer draws; any other finger or palm touching the
/// screen while a stroke is in progress is ignored (ADR 0008).
class SheetView extends StatefulWidget {
  const SheetView({
    super.key,
    required this.sheetSize,
    required this.renderer,
    required this.live,
    required this.onStrokeStart,
    required this.onStrokeEnd,
  });

  final Size sheetSize;
  final DrawingRenderer renderer;
  final LiveStroke live;

  /// Called when a stroke starts; must call [LiveStroke.begin].
  final VoidCallback onStrokeStart;

  /// Called when the finger lifts.
  final VoidCallback onStrokeEnd;

  @override
  State<SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends State<SheetView> {
  int? _activePointer;
  final Stopwatch _clock = Stopwatch();
  double _scale = 1;

  SheetPoint _toSheet(PointerEvent event) {
    final p = event.localPosition / _scale;
    final pressure = event.kind == PointerDeviceKind.stylus
        ? event.pressure.clamp(0.0, 1.0)
        : 0.5;
    return SheetPoint(
      p.dx,
      p.dy,
      pressure: pressure,
      time: _clock.elapsedMilliseconds,
    );
  }

  void _down(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _clock
      ..reset()
      ..start();
    widget.onStrokeStart();
    widget.live.add(_toSheet(event));
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    widget.live.add(_toSheet(event));
  }

  void _up(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    widget.onStrokeEnd();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheet = widget.sheetSize;
        _scale = [
          constraints.maxWidth / sheet.width,
          constraints.maxHeight / sheet.height,
        ].reduce((a, b) => a < b ? a : b);
        // Cache at device resolution for crisp strokes.
        widget.renderer.pixelScale = _scale * dpr;
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Tokens.ink.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Listener(
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: sheet * _scale,
                  painter: SheetPainter(
                    renderer: widget.renderer,
                    live: widget.live,
                    sheetSize: sheet,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
