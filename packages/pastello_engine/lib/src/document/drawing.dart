import 'dart:ui';

import 'stroke_element.dart';

/// A drawing: a fixed-size sheet and an ordered list of elements.
///
/// The list order is the z-order (ADR 0004). Drawings are immutable; commands
/// produce new instances.
///
/// The prototype only knows about strokes. Text, stickers and shapes will be
/// added as further element types.
class Drawing {
  /// Creates a drawing of [sheetSize] with the given [elements].
  const Drawing({required this.sheetSize, this.elements = const []});

  /// Logical size of the sheet, in sheet units (decision D-05).
  final Size sheetSize;

  /// Elements from bottom to top.
  final List<StrokeElement> elements;

  /// Whether nothing has been drawn yet (empty sheets are not saved, F-01).
  bool get isEmpty => elements.isEmpty;

  /// Returns a copy with [element] added on top.
  Drawing withElementAdded(StrokeElement element) =>
      Drawing(sheetSize: sheetSize, elements: [...elements, element]);

  /// Returns a copy with the element whose id is [id] removed.
  Drawing withElementRemoved(String id) => Drawing(
    sheetSize: sheetSize,
    elements: [
      for (final e in elements)
        if (e.id != id) e,
    ],
  );

  /// Returns a copy where every element is passed through [update].
  Drawing withElementsMapped(StrokeElement Function(StrokeElement) update) =>
      Drawing(
        sheetSize: sheetSize,
        elements: [for (final e in elements) update(e)],
      );

  /// Returns a copy with the given [elements].
  Drawing withElements(List<StrokeElement> elements) =>
      Drawing(sheetSize: sheetSize, elements: elements);
}
