import 'dart:ui';

import 'element_transform.dart';

/// Something on the sheet: a stroke, a text, and later stickers and shapes
/// (ADR 0004).
abstract class DrawingElement {
  /// Creates an element.
  const DrawingElement({
    required this.id,
    this.transform = ElementTransform.identity,
  });

  /// Unique identifier within the drawing.
  final String id;

  /// Position, scale and rotation on the sheet.
  final ElementTransform transform;

  /// Bounds in local coordinates, including the stroke width.
  Rect get localBounds;

  /// Axis-aligned bounds on the sheet.
  Rect get bounds =>
      transform.isIdentity ? localBounds : transform.applyToRect(localBounds);

  /// Whether the eraser removes pixels of this element (ADR 0006: only
  /// strokes, for now).
  bool get erasable;

  /// Whether a touch at the sheet point [point] lands on this element.
  ///
  /// [slop] extends the area, in sheet units, so small elements are easy to
  /// pick with a finger.
  bool contains(Offset point, {double slop = 0}) {
    final local = transform.invert(point);
    return localBounds.inflate(slop / transform.scale).contains(local);
  }

  /// Returns a copy with another [transform].
  DrawingElement withTransform(ElementTransform transform);

  /// Returns a copy with another [id] (to duplicate the element).
  DrawingElement withId(String id);
}
