import 'dart:ui';

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
class StrokeElement {
  /// Creates a stroke.
  const StrokeElement({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.erasures = const [],
  });

  /// Unique identifier.
  final String id;

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

  /// Axis-aligned bounds of the stroke, including its width.
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var left = points.first.x, right = left;
    var top = points.first.y, bottom = top;
    for (final p in points) {
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
    return Rect.fromLTRB(left, top, right, bottom).inflate(width);
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

  StrokeElement _copyWith({List<Erasure>? erasures}) => StrokeElement(
    id: id,
    tool: tool,
    color: color,
    width: width,
    points: points,
    erasures: erasures ?? this.erasures,
  );
}
