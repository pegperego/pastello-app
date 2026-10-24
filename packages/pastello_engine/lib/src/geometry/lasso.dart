import 'dart:ui';

import '../document/drawing.dart';
import '../document/drawing_element.dart';
import '../document/element_transform.dart';
import '../document/stroke_element.dart';

/// Whether [point] is inside the closed polygon [polygon] (even-odd rule).
bool pointInPolygon(Offset point, List<Offset> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i], b = polygon[j];
    if ((a.dy > point.dy) != (b.dy > point.dy) &&
        point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// Ids of the elements of [drawing] caught by the closed [lasso], in z-order
/// (F-13).
///
/// A stroke is caught when most of its points are inside, so the lasso does
/// not have to be precise; any other element when its center is inside.
List<String> lassoSelection(Drawing drawing, List<Offset> lasso) {
  if (lasso.length < 3) return const [];
  bool caught(DrawingElement e) {
    if (e is StrokeElement) {
      if (e.points.isEmpty) return false;
      final inside = e.points
          .where((p) => pointInPolygon(e.transform.apply(p.offset), lasso))
          .length;
      return inside * 2 > e.points.length;
    }
    return pointInPolygon(e.bounds.center, lasso);
  }

  return [
    for (final e in drawing.elements)
      if (caught(e)) e.id,
  ];
}

/// Bounds, on the sheet, of all [elements] together.
Rect groupBounds(Iterable<DrawingElement> elements) =>
    elements.map((e) => e.bounds).reduce((a, b) => a.expandToInclude(b));

/// The transform that turns a group's frame, starting as [box] (axis-aligned,
/// unrotated), into a frame with the transform [frame]: apply it to every
/// element of the group with [ElementTransform.then].
ElementTransform groupTransform(Rect box, ElementTransform frame) {
  final unmoved = ElementTransform(
    scale: frame.scale,
    rotation: frame.rotation,
  );
  return ElementTransform(
    translation: frame.translation - unmoved.apply(box.center),
    scale: frame.scale,
    rotation: frame.rotation,
  );
}
