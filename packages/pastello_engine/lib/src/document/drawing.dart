import 'dart:math' as math;
import 'dart:ui';

import 'drawing_element.dart';
import 'fill_element.dart';
import 'sheet_background.dart';
import 'shape_element.dart';
import 'stroke_element.dart';

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
    this.outline,
  });

  /// Logical size of the sheet, in sheet units (decision D-05).
  final Size sheetSize;

  /// Paper color and pattern (F-10).
  final SheetBackground background;

  /// The outline of the coloring page this drawing started from, or `null`
  /// (F-19, ADR 0022). It is part of the sheet, like the paper: no command
  /// changes it.
  final ColoringOutline? outline;

  /// Elements from bottom to top.
  final List<DrawingElement> elements;

  /// Elements in the order they are painted: the fills of the paint bucket
  /// first, under everything else (ADR 0021), then the other elements; each
  /// group keeps the order of [elements].
  ///
  /// With an [outline], strokes and shapes are painted under it and the
  /// others (texts, stickers) above it: [underOutline] then [overOutline].
  List<DrawingElement> get paintOrder => [...underOutline, ...overOutline];

  /// The elements painted under the outline, in painting order: all of
  /// them when there is no outline.
  List<DrawingElement> get underOutline => [
    ...elements.whereType<FillElement>(),
    ...elements.where(
      (e) => e is! FillElement && (outline == null || isUnderOutline(e)),
    ),
  ];

  /// The elements painted above the outline, in painting order: none when
  /// there is no outline.
  List<DrawingElement> get overOutline => outline == null
      ? const []
      : [
          for (final e in elements)
            if (!isUnderOutline(e)) e,
        ];

  /// Whether [element] goes under a coloring outline: fills, strokes and
  /// shapes do, so the lines stay visible when coloring outside them.
  static bool isUnderOutline(DrawingElement element) =>
      element is FillElement ||
      element is StrokeElement ||
      element is ShapeElement;

  /// Whether nothing has been drawn yet (empty sheets are not saved, F-01).
  bool get isEmpty => elements.isEmpty;

  /// Returns a copy with [element] added on top.
  Drawing withElementAdded(DrawingElement element) =>
      withElements([...elements, element]);

  /// Returns a copy with the element whose id is [id] removed.
  Drawing withElementRemoved(String id) => withElements([
    for (final e in elements)
      if (e.id != id) e,
  ]);

  /// Returns a copy where every element is passed through [update].
  Drawing withElementsMapped(DrawingElement Function(DrawingElement) update) =>
      withElements([for (final e in elements) update(e)]);

  /// Returns a copy with another [background].
  Drawing withBackground(SheetBackground background) => Drawing(
    sheetSize: sheetSize,
    background: background,
    outline: outline,
    elements: elements,
  );

  /// The element with [id], or `null`.
  DrawingElement? elementById(String id) =>
      elements.where((e) => e.id == id).firstOrNull;

  /// Returns a copy where the element with the same id as [element] is
  /// replaced by it, keeping its place in the z-order.
  Drawing withElementReplaced(DrawingElement element) => withElements([
    for (final e in elements)
      if (e.id == element.id) element else e,
  ]);

  /// Returns a copy with [element] inserted at [index] in the z-order.
  Drawing withElementInserted(int index, DrawingElement element) =>
      withElements(
        [...elements]..insert(index.clamp(0, elements.length), element),
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
  Drawing withElements(List<DrawingElement> elements) => Drawing(
    sheetSize: sheetSize,
    background: background,
    outline: outline,
    elements: elements,
  );
}

/// The outline of a coloring page, from a content pack (F-19, ADR 0022).
///
/// Like a sticker, the drawing only stores which page it is; the artwork
/// comes from the installed pack.
class ColoringOutline {
  /// Creates a reference to page [pageId] of pack [packId].
  const ColoringOutline({required this.packId, required this.pageId});

  /// The content pack.
  final String packId;

  /// The page within the pack.
  final String pageId;

  /// Margin around the outline, as a fraction of the sheet's short side.
  static const double margin = 0.05;

  /// Where a page of [artworkSize] goes on a sheet of [sheetSize]: as big as
  /// it fits within the margin, centered (portrait or landscape).
  static Rect placement(Size artworkSize, Size sheetSize) {
    final inset = sheetSize.shortestSide * margin;
    final room = Size(
      sheetSize.width - 2 * inset,
      sheetSize.height - 2 * inset,
    );
    if (artworkSize.isEmpty || room.isEmpty) return Rect.zero;
    final scale = math.min(
      room.width / artworkSize.width,
      room.height / artworkSize.height,
    );
    return Rect.fromCenter(
      center: sheetSize.center(Offset.zero),
      width: artworkSize.width * scale,
      height: artworkSize.height * scale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ColoringOutline &&
      other.packId == packId &&
      other.pageId == pageId;

  @override
  int get hashCode => Object.hash(packId, pageId);
}
