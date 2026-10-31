import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'drawing_element.dart';
import 'element_transform.dart';
import 'stroke_element.dart';

/// An area of the sheet, one pixel per sheet unit, stored as runs of
/// pixels on each row (ADR 0021).
///
/// Row `i` is the sheet row `top + i`; its runs are pairs
/// `(start, length)` with `start` relative to [left], sorted and not
/// overlapping.
class FillMask {
  /// Creates a mask from its rows of runs.
  FillMask({required this.left, required this.top, required this.rows});

  /// Sheet column of the run starts' origin.
  final int left;

  /// Sheet row of the first row.
  final int top;

  /// Runs of each row, as `[start, length, start, length, ...]`.
  final List<Int32List> rows;

  /// Number of rows.
  int get height => rows.length;

  /// Bounds of the mask, in sheet units.
  late final Rect bounds = () {
    var minX = 1 << 30, maxX = -(1 << 30), first = -1, last = -1;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      if (row.isEmpty) continue;
      if (first < 0) first = y;
      last = y;
      minX = math.min(minX, row[0]);
      maxX = math.max(maxX, row[row.length - 2] + row[row.length - 1]);
    }
    if (first < 0) return Rect.zero;
    return Rect.fromLTRB(
      (left + minX).toDouble(),
      (top + first).toDouble(),
      (left + maxX).toDouble(),
      (top + last + 1).toDouble(),
    );
  }();

  /// Number of pixels in the mask.
  late final int area = () {
    var total = 0;
    for (final row in rows) {
      for (var i = 1; i < row.length; i += 2) {
        total += row[i];
      }
    }
    return total;
  }();

  /// Whether the pixel at sheet column [x] and row [y] is in the mask.
  bool containsPixel(int x, int y) {
    final r = y - top;
    if (r < 0 || r >= rows.length) return false;
    final row = rows[r];
    final c = x - left;
    for (var i = 0; i < row.length; i += 2) {
      if (c < row[i]) return false;
      if (c < row[i] + row[i + 1]) return true;
    }
    return false;
  }

  /// Whether every pixel of [other] is also in this mask.
  bool covers(FillMask other) {
    for (var r = 0; r < other.rows.length; r++) {
      final row = other.rows[r];
      final y = other.top + r;
      for (var i = 0; i < row.length; i += 2) {
        final start = other.left + row[i];
        if (!_coversRun(y, start, start + row[i + 1])) return false;
      }
    }
    return true;
  }

  /// Whether the pixels from [start] to [end] (excluded) of the sheet row
  /// [y] are all in a single run of this mask (runs never touch).
  bool _coversRun(int y, int start, int end) {
    final r = y - top;
    if (r < 0 || r >= rows.length) return false;
    final row = rows[r];
    for (var i = 0; i < row.length; i += 2) {
      final s = left + row[i];
      if (s <= start && end <= s + row[i + 1]) return true;
    }
    return false;
  }

  /// The mask as a path, built once. Runs repeated on consecutive rows
  /// become a single rectangle, which keeps the path small.
  late final Path path = () {
    final path = Path();
    void close(int start, (int, int) open, int y) => path.addRect(
      Rect.fromLTWH(
        (left + start).toDouble(),
        (top + open.$2).toDouble(),
        open.$1.toDouble(),
        (y - open.$2).toDouble(),
      ),
    );
    // Rectangles still growing, by start: (length, first row).
    var open = <int, (int, int)>{};
    for (var y = 0; y <= rows.length; y++) {
      final next = <int, (int, int)>{};
      if (y < rows.length) {
        final row = rows[y];
        for (var i = 0; i < row.length; i += 2) {
          final start = row[i], length = row[i + 1];
          final previous = open.remove(start);
          if (previous != null && previous.$1 == length) {
            next[start] = previous;
          } else {
            if (previous != null) close(start, previous, y);
            next[start] = (length, y);
          }
        }
      }
      open.forEach((start, o) => close(start, o, y));
      open = next;
    }
    return path;
  }();
}

/// An area colored by the paint bucket (F-18).
///
/// Fills are painted under every other element, newer fills above older
/// ones (ADR 0021). Like strokes, they carry the eraser passes applied to
/// them, in their local coordinates.
class FillElement extends DrawingElement {
  /// Creates a fill.
  const FillElement({
    required super.id,
    required this.color,
    required this.mask,
    this.erasures = const [],
    super.transform,
  });

  /// The color.
  final Color color;

  /// The colored area, in local coordinates.
  final FillMask mask;

  /// Eraser passes applied to this fill, oldest first.
  final List<Erasure> erasures;

  @override
  Rect get localBounds => mask.bounds;

  @override
  bool get erasable => true;

  /// A fill is hit inside its area, not anywhere in its bounding box.
  @override
  bool contains(Offset point, {double slop = 0}) {
    final local = transform.invert(point);
    return mask.containsPixel(local.dx.floor(), local.dy.floor());
  }

  /// Returns a copy of this fill with [erasure] added.
  FillElement withErasure(Erasure erasure) =>
      _copyWith(erasures: [...erasures, erasure]);

  /// Returns a copy of this fill with [erasure] removed.
  FillElement withoutErasure(Erasure erasure) => _copyWith(
    erasures: [
      for (final e in erasures)
        if (e.id != erasure.id) e,
    ],
  );

  @override
  FillElement withTransform(ElementTransform transform) =>
      _copyWith(transform: transform);

  @override
  FillElement withId(String id) => _copyWith(id: id);

  FillElement _copyWith({
    List<Erasure>? erasures,
    ElementTransform? transform,
    String? id,
  }) => FillElement(
    id: id ?? this.id,
    color: color,
    mask: mask,
    erasures: erasures ?? this.erasures,
    transform: transform ?? this.transform,
  );
}
