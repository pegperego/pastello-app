import 'dart:ui';

import '../geometry/simplify.dart';
import 'drawing_element.dart';
import 'element_transform.dart';
import 'sheet_point.dart';
import 'stroke_tool.dart';

/// An eraser pass attached to a stroke (ADR 0006).
///
/// Points are stored in the stroke's own coordinates, so the erased parts
/// follow the stroke when it is moved.
///
/// The same pass is attached to every stroke it touches; [id] identifies it,
/// so it can be removed from all of them on undo, also after the drawing was
/// saved and loaded again.
class Erasure {
  /// Creates an erasure along [points] with the given [width].
  const Erasure({required this.id, required this.points, required this.width});

  /// Identifier of the eraser pass.
  final String id;

  /// The eraser path.
  final List<SheetPoint> points;

  /// Eraser width in sheet units.
  final double width;
}

/// A freehand stroke drawn with one of the [StrokeTool]s.
///
/// Points and erasures are in local coordinates; they equal sheet
/// coordinates until the stroke is moved with the Select tool.
class StrokeElement extends DrawingElement {
  /// Creates a stroke.
  const StrokeElement({
    required super.id,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.erasures = const [],
    super.transform,
  });

  /// Tool used to draw the stroke.
  final StrokeTool tool;

  /// Base color. Ignored by [StrokeTool.rainbow].
  final Color color;

  /// Base width in sheet units.
  final double width;

  /// Input points, in sheet units.
  final List<SheetPoint> points;

  /// Eraser passes applied to this stroke, oldest first.
  final List<Erasure> erasures;

  /// Local bounds of the stroke, including its width.
  @override
  Rect get localBounds {
    if (points.isEmpty) return Rect.zero;
    var left = points.first.x, right = left;
    var top = points.first.y, bottom = top;
    for (final p in points) {
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
    return Rect.fromLTRB(left, top, right, bottom).inflate(width * tool.reach);
  }

  /// Returns a copy of this stroke with [erasure] added.
  StrokeElement withErasure(Erasure erasure) =>
      _copyWith(erasures: [...erasures, erasure]);

  /// Returns a copy of this stroke with [erasure] removed.
  StrokeElement withoutErasure(Erasure erasure) => _copyWith(
    erasures: [
      for (final e in erasures)
        if (e.id != erasure.id) e,
    ],
  );

  @override
  bool get erasable => true;

  /// A stroke is hit on its line, not anywhere in its bounding box.
  @override
  bool contains(Offset point, {double slop = 0}) {
    if (points.isEmpty) return false;
    final local = transform.invert(point);
    final reach = width / 2 + slop / transform.scale;
    if (!localBounds.inflate(reach).contains(local)) return false;
    final p = SheetPoint(local.dx, local.dy);
    if (points.length == 1) {
      return (points.first.offset - local).distance <= reach;
    }
    for (var i = 1; i < points.length; i++) {
      if (segmentDistanceSquared(p, points[i - 1], points[i]) <=
          reach * reach) {
        return true;
      }
    }
    return false;
  }

  @override
  StrokeElement withTransform(ElementTransform transform) =>
      _copyWith(transform: transform);

  @override
  StrokeElement withId(String id) => _copyWith(id: id);

  StrokeElement _copyWith({
    List<Erasure>? erasures,
    ElementTransform? transform,
    String? id,
  }) => StrokeElement(
    id: id ?? this.id,
    tool: tool,
    color: color,
    width: width,
    points: points,
    erasures: erasures ?? this.erasures,
    transform: transform ?? this.transform,
  );
}
