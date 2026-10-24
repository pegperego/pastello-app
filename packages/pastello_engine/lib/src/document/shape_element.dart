import 'dart:math' as math;
import 'dart:ui';

import 'drawing_element.dart';
import 'element_transform.dart';

/// The shapes of the Shapes tool (F-12).
enum ShapeKind {
  /// Circle or ellipse.
  ellipse,

  /// Square or rectangle.
  rectangle,

  /// Triangle pointing up.
  triangle,

  /// Five-pointed star.
  star,

  /// Heart.
  heart,

  /// Straight line.
  line,

  /// Straight line with an arrow head at its end.
  arrow;

  /// Whether the shape is a line (drawn from a start to an end point) rather
  /// than a figure inscribed in a box.
  bool get isLine => this == line || this == arrow;
}

/// A geometric shape (F-12).
///
/// The local origin is the center. Figures are inscribed in the box from
/// `-extent / 2` to `extent / 2`; lines go from `-extent / 2` to
/// `extent / 2`, so the sign of [extent] gives their direction.
class ShapeElement extends DrawingElement {
  /// Creates a shape.
  const ShapeElement({
    required super.id,
    required this.kind,
    required this.extent,
    required this.color,
    required this.strokeWidth,
    this.filled = false,
    super.transform,
  });

  /// Which shape.
  final ShapeKind kind;

  /// Size of the box (figures) or vector from start to end (lines), in
  /// sheet units before scaling.
  final Offset extent;

  /// Outline (and fill) color.
  final Color color;

  /// Outline width in sheet units.
  final double strokeWidth;

  /// Whether a figure is filled; lines are never filled.
  final bool filled;

  /// The box the figure is inscribed in, in local coordinates.
  Rect get box => Rect.fromCenter(
    center: Offset.zero,
    width: extent.dx.abs(),
    height: extent.dy.abs(),
  );

  @override
  Rect get localBounds {
    final b = box;
    // Arrow heads stick out of the line's box.
    final head = kind == ShapeKind.arrow ? arrowHeadLength : 0.0;
    return b.inflate(strokeWidth / 2 + head);
  }

  /// Length of the arrow head, proportional to the line and the width.
  double get arrowHeadLength => math.max(
    strokeWidth * 3,
    math.min(extent.distance * 0.25, strokeWidth * 8),
  );

  @override
  bool get erasable => false;

  /// The outline of the shape, in local coordinates.
  Path get path {
    final b = box;
    final w = b.width, h = b.height;
    switch (kind) {
      case ShapeKind.ellipse:
        return Path()..addOval(b);
      case ShapeKind.rectangle:
        return Path()..addRect(b);
      case ShapeKind.triangle:
        return Path()
          ..moveTo(0, -h / 2)
          ..lineTo(w / 2, h / 2)
          ..lineTo(-w / 2, h / 2)
          ..close();
      case ShapeKind.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          // Inner points at 40% of the radius make a classic star.
          final r = i.isEven ? 1.0 : 0.4;
          final angle = -math.pi / 2 + i * math.pi / 5;
          final p = Offset(
            math.cos(angle) * r * w / 2,
            math.sin(angle) * r * h / 2,
          );
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        return path..close();
      case ShapeKind.heart:
        // Two lobes and a point, drawn in a unit box and scaled.
        Offset at(double x, double y) => Offset(x * w, y * h);
        final p = Path();
        final top = at(0, -0.2), bottom = at(0, 0.5);
        p.moveTo(top.dx, top.dy);
        final c1 = at(-0.1, -0.5), c2 = at(-0.5, -0.45), l = at(-0.5, -0.15);
        p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, l.dx, l.dy);
        final c3 = at(-0.5, 0.15), c4 = at(-0.2, 0.3);
        p.cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, bottom.dx, bottom.dy);
        final c5 = at(0.2, 0.3), c6 = at(0.5, 0.15), r = at(0.5, -0.15);
        p.cubicTo(c5.dx, c5.dy, c6.dx, c6.dy, r.dx, r.dy);
        final c7 = at(0.5, -0.45), c8 = at(0.1, -0.5);
        p.cubicTo(c7.dx, c7.dy, c8.dx, c8.dy, top.dx, top.dy);
        return p..close();
      case ShapeKind.line:
      case ShapeKind.arrow:
        final start = -extent / 2, end = extent / 2;
        final p = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(end.dx, end.dy);
        if (kind == ShapeKind.arrow && extent.distance > 0) {
          final back = -extent / extent.distance * arrowHeadLength;
          for (final angle in const [0.5, -0.5]) {
            final wing = Offset(
              back.dx * math.cos(angle) - back.dy * math.sin(angle),
              back.dx * math.sin(angle) + back.dy * math.cos(angle),
            );
            p
              ..moveTo(end.dx, end.dy)
              ..lineTo(end.dx + wing.dx, end.dy + wing.dy);
          }
        }
        return p;
    }
  }

  /// Paints the shape, in local coordinates.
  void paintLocal(Canvas canvas) {
    final outline = path;
    if (filled && !kind.isLine) {
      canvas.drawPath(outline, Paint()..color = color);
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Returns a copy with the given fields replaced.
  ShapeElement copyWith({
    String? id,
    Offset? extent,
    Color? color,
    double? strokeWidth,
    bool? filled,
    ElementTransform? transform,
  }) => ShapeElement(
    id: id ?? this.id,
    kind: kind,
    extent: extent ?? this.extent,
    color: color ?? this.color,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    filled: filled ?? this.filled,
    transform: transform ?? this.transform,
  );

  @override
  ShapeElement withTransform(ElementTransform transform) =>
      copyWith(transform: transform);

  @override
  ShapeElement withId(String id) => copyWith(id: id);
}

/// Builds the shape drawn by dragging a finger from [start] to [end], in
/// sheet coordinates (F-12).
///
/// When the gesture is close to a perfect figure (a circle, a square) or to
/// a horizontal, vertical or 45° line, the shape "snaps" to it, like a
/// gentle magnet. Returns the shape and whether it snapped.
(ShapeElement, bool) shapeFromDrag({
  required String id,
  required ShapeKind kind,
  required Offset start,
  required Offset end,
  required Color color,
  required double strokeWidth,
  required bool filled,
}) {
  var vector = end - start;
  var snapped = false;
  if (kind.isLine) {
    // Snap to multiples of 45° within 7°.
    const step = math.pi / 4;
    final angle = vector.direction;
    final nearest = (angle / step).round() * step;
    if ((angle - nearest).abs() < 7 * math.pi / 180 && vector.distance > 0) {
      vector = Offset.fromDirection(nearest, vector.distance);
      snapped = true;
    }
  } else {
    // Snap to a perfect circle or square within 12%.
    final w = vector.dx.abs(), h = vector.dy.abs();
    final longest = math.max(w, h);
    if (longest > 0 && (w - h).abs() / longest < 0.12) {
      vector = Offset(
        longest * (vector.dx < 0 ? -1 : 1),
        longest * (vector.dy < 0 ? -1 : 1),
      );
      snapped = true;
    }
  }
  final shape = ShapeElement(
    id: id,
    kind: kind,
    extent: kind.isLine ? vector : Offset(vector.dx.abs(), vector.dy.abs()),
    color: color,
    strokeWidth: strokeWidth,
    filled: filled,
    transform: ElementTransform(translation: start + vector / 2),
  );
  return (shape, snapped);
}
