import 'dart:ui';

import 'drawing_element.dart';
import 'fill_element.dart';
import 'sheet_background.dart';

/// A drawing: a fixed-size sheet and an ordered list of elements.
///
/// The list order is the z-order (ADR 0004). Drawings are immutable; commands
/// produce new instances.
class Drawing {
  /// Creates a drawing of [sheetSize] with the given [elements].
  const Drawing({
    required this.sheetSize,
    this.elements = const [],
    this.background = SheetBackground.white,
  });

  /// Logical size of the sheet, in sheet units (decision D-05).
  final Size sheetSize;

  /// Paper color and pattern (F-10).
  final SheetBackground background;

  /// Elements from bottom to top.
  final List<DrawingElement> elements;

  /// Elements in the order they are painted: the fills of the paint bucket
  /// first, under everything else (ADR 0021), then the other elements; each
  /// group keeps the order of [elements].
  List<DrawingElement> get paintOrder => [
    ...elements.whereType<FillElement>(),
    ...elements.where((e) => e is! FillElement),
  ];

  /// Whether nothing has been drawn yet (empty sheets are not saved, F-01).
  bool get isEmpty => elements.isEmpty;

  /// Returns a copy with [element] added on top.
  Drawing withElementAdded(DrawingElement element) => Drawing(
    sheetSize: sheetSize,
    background: background,
    elements: [...elements, element],
  );

  /// Returns a copy with the element whose id is [id] removed.
  Drawing withElementRemoved(String id) => Drawing(
    sheetSize: sheetSize,
    background: background,
    elements: [
      for (final e in elements)
        if (e.id != id) e,
    ],
  );

  /// Returns a copy where every element is passed through [update].
  Drawing withElementsMapped(DrawingElement Function(DrawingElement) update) =>
      Drawing(
        sheetSize: sheetSize,
        background: background,
        elements: [for (final e in elements) update(e)],
      );

  /// Returns a copy with another [background].
  Drawing withBackground(SheetBackground background) =>
      Drawing(sheetSize: sheetSize, background: background, elements: elements);

  /// The element with [id], or `null`.
  DrawingElement? elementById(String id) =>
      elements.where((e) => e.id == id).firstOrNull;

  /// Returns a copy where the element with the same id as [element] is
  /// replaced by it, keeping its place in the z-order.
  Drawing withElementReplaced(DrawingElement element) => Drawing(
    sheetSize: sheetSize,
    background: background,
    elements: [
      for (final e in elements)
        if (e.id == element.id) element else e,
    ],
  );

  /// Returns a copy with [element] inserted at [index] in the z-order.
  Drawing withElementInserted(int index, DrawingElement element) => Drawing(
    sheetSize: sheetSize,
    background: background,
    elements: [...elements]..insert(index.clamp(0, elements.length), element),
  );

  /// The topmost element under [point] accepted by [where], or `null`.
  DrawingElement? elementAt(
    Offset point, {
    double slop = 0,
    bool Function(DrawingElement element)? where,
  }) {
    for (final e in paintOrder.reversed) {
      if ((where == null || where(e)) && e.contains(point, slop: slop)) {
        return e;
      }
    }
    return null;
  }

  /// Returns a copy with the given [elements].
  Drawing withElements(List<DrawingElement> elements) =>
      Drawing(sheetSize: sheetSize, background: background, elements: elements);
}
