import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/tokens.dart';

/// The frame around the selected element (F-07): drag inside to move, drag
/// the corner to resize, drag the round handle to rotate. One finger only.
///
/// Positions are in the coordinates of the sheet widget: sheet units times
/// [scale].
class ElementSelectionOverlay extends StatefulWidget {
  const ElementSelectionOverlay({
    super.key,
    required this.element,
    required this.scale,
    required this.onTransform,
    required this.onTransformEnd,
    required this.actions,
    required this.rotateLabel,
    required this.resizeLabel,
  });

  final DrawingElement element;
  final double scale;
  final ValueChanged<ElementTransform> onTransform;
  final VoidCallback onTransformEnd;

  /// Buttons shown under the frame (edit, font, delete...).
  final List<Widget> actions;
  final String rotateLabel;
  final String resizeLabel;

  @override
  State<ElementSelectionOverlay> createState() =>
      _ElementSelectionOverlayState();
}

class _ElementSelectionOverlayState extends State<ElementSelectionOverlay> {
  static const double _handle = 44;

  ElementTransform? _start;
  Offset? _startPointer;

  ElementTransform get _transform => widget.element.transform;

  /// Center of the element, in overlay coordinates.
  Offset get _center => _transform.translation * widget.scale;

  Offset _toOverlay(Offset global) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(global);

  void _begin(DragStartDetails details) {
    _start = _transform;
    _startPointer = _toOverlay(details.globalPosition);
  }

  void _move(DragUpdateDetails details) {
    final start = _start!;
    final delta =
        (_toOverlay(details.globalPosition) - _startPointer!) / widget.scale;
    widget.onTransform(start.copyWith(translation: start.translation + delta));
  }

  void _resize(DragUpdateDetails details) {
    final start = _start!;
    final from = (_startPointer! - _center).distance;
    final to = (_toOverlay(details.globalPosition) - _center).distance;
    if (from < 1) return;
    widget.onTransform(start.copyWith(scale: start.scale * to / from));
  }

  void _rotate(DragUpdateDetails details) {
    final start = _start!;
    final from = _startPointer! - _center;
    final to = _toOverlay(details.globalPosition) - _center;
    widget.onTransform(
      start.copyWith(rotation: start.rotation + to.direction - from.direction),
    );
  }

  void _end(DragEndDetails _) {
    _start = null;
    widget.onTransformEnd();
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.element.localBounds;
    final size = local.size * _transform.scale * widget.scale;
    final rotation = _transform.rotation;
    final center = _center;

    // Handle positions follow the rotation of the frame.
    Offset rotated(Offset offset) {
      final c = math.cos(rotation), s = math.sin(rotation);
      return center +
          Offset(offset.dx * c - offset.dy * s, offset.dx * s + offset.dy * c);
    }

    final corner = rotated(Offset(size.width / 2, size.height / 2));
    final top = rotated(Offset(0, -size.height / 2 - 36));
    // The buttons stay upright, under the frame's bounding box.
    final aabb = _transform.applyToRect(local);
    final actionsTop = aabb.bottom * widget.scale + 16;

    Widget handle(
      Offset at,
      IconData icon,
      String label,
      GestureDragUpdateCallback onUpdate,
    ) => Positioned(
      left: at.dx - _handle / 2,
      top: at.dy - _handle / 2,
      width: _handle,
      height: _handle,
      child: Semantics(
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _begin,
          onPanUpdate: onUpdate,
          onPanEnd: _end,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Tokens.sheet,
                shape: BoxShape.circle,
                border: Border.all(color: Tokens.sky, width: 3),
              ),
              child: Icon(icon, size: 16, color: Tokens.sky),
            ),
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: center.dx - size.width / 2,
          top: center.dy - size.height / 2,
          width: size.width,
          height: size.height,
          child: Transform.rotate(
            angle: rotation,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _begin,
              onPanUpdate: _move,
              onPanEnd: _end,
              child: CustomPaint(painter: _DashedFramePainter()),
            ),
          ),
        ),
        handle(corner, Icons.open_in_full_rounded, widget.resizeLabel, _resize),
        handle(top, Icons.rotate_right_rounded, widget.rotateLabel, _rotate),
        if (_start == null)
          Positioned(
            left: center.dx - 200,
            width: 400,
            top: actionsTop,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.actions,
            ),
          ),
      ],
    );
  }
}

class _DashedFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Tokens.sky
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter oldDelegate) => false;
}

/// A round button shown under the selection frame.
class SelectionAction extends StatelessWidget {
  const SelectionAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Tokens.ink,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
      constraints: const BoxConstraints.tightFor(
        width: Tokens.minTouchTarget - 4,
        height: Tokens.minTouchTarget - 4,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Tokens.sheet,
        foregroundColor: color,
        elevation: 2,
        shadowColor: Tokens.ink.withValues(alpha: 0.3),
      ),
      icon: Icon(icon),
    ),
  );
}

/// The frame of a lasso group, as an element the selection overlay can
/// move, resize and rotate: a box of [size] centered on the frame's
/// transform.
class GroupFrame extends DrawingElement {
  const GroupFrame({required this.size, required super.transform})
    : super(id: 'group');

  final Size size;

  @override
  Rect get localBounds => Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );

  @override
  bool get erasable => false;

  @override
  GroupFrame withId(String id) => this;

  @override
  GroupFrame withTransform(ElementTransform transform) =>
      GroupFrame(size: size, transform: transform);
}

/// The lasso while it is drawn: a dashed line from the first point to the
/// finger, closed back to the start.
class LassoPainter extends CustomPainter {
  LassoPainter(this.points, this.scale);

  final List<Offset> points;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..addPolygon([for (final p in points) p * scale], true);
    final paint = Paint()
      ..color = Tokens.sky
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, Paint()..color = Tokens.sky.withValues(alpha: 0.08));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, d + 9), paint);
      }
    }
  }

  @override
  bool shouldRepaint(LassoPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.scale != scale;
}
