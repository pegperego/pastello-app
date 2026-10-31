import 'dart:typed_data';

/// Half the widest gap in a border that the paint bucket closes, in sheet
/// units: gaps up to the "medium" width are closed (F-18).
const double bucketGap = 5;

/// The pixels colored by the paint bucket, as rows of runs (see
/// `FillMask`).
typedef BucketRegion = ({int left, int top, List<Int32List> rows});

/// The region a tap of the paint bucket at pixel ([x], [y]) colors, on a
/// map of [width] × [height] pixels where the nonzero bytes of [walls] are
/// borders (ADR 0021).
///
/// 1. Borders are grown by [gap], so small gaps in a line are closed.
/// 2. The free area around the tap is flooded. A tap close to a border
///    starts from the nearest free pixel; a tap in an area too narrow to
///    have free pixels floods that area without closing gaps.
/// 3. The flooded area is grown back by [gap] and a pixel and a half, so
///    the color reaches under the borders and no white edge is left.
///
/// Returns `null` when the tap is on a border or outside the map.
///
/// Pure computation on typed data: it can run in another isolate.
BucketRegion? bucketRegion(
  Uint8List walls,
  int width,
  int height,
  int x,
  int y, {
  double gap = bucketGap,
}) {
  if (x < 0 || y < 0 || x >= width || y >= height) return null;
  final size = width * height;
  final tap = y * width + x;
  if (walls[tap] != 0) return null;

  // Squared distance of every pixel from the nearest border.
  final distance = Float64List(size);
  for (var i = 0; i < size; i++) {
    distance[i] = walls[i] != 0 ? 0 : _far;
  }
  _distanceTransform(distance, width, height);
  final gapSquared = gap * gap;
  bool free(int i) => distance[i] > gapSquared;

  var seed = tap;
  var closesGaps = true;
  if (!free(tap)) {
    final nearest = _nearest(walls, width, height, tap, gap.ceil() + 1, free);
    if (nearest == null) {
      closesGaps = false;
    } else {
      seed = nearest;
    }
  }
  final region = _flood(
    width,
    height,
    seed,
    closesGaps ? free : (i) => walls[i] == 0,
  );

  // Grow the region back under the borders, working only around it.
  final reach = (closesGaps ? gap : 0) + 1.5;
  final margin = reach.ceil() + 1;
  final left = (region.left - margin).clamp(0, width - 1);
  final top = (region.top - margin).clamp(0, height - 1);
  final w = (region.right + margin).clamp(0, width - 1) - left + 1;
  final h = (region.bottom + margin).clamp(0, height - 1) - top + 1;
  final grown = Float64List(w * h);
  for (var y = 0; y < h; y++) {
    final from = (top + y) * width + left;
    for (var x = 0; x < w; x++) {
      grown[y * w + x] = region.pixels[from + x] != 0 ? 0 : _far;
    }
  }
  _distanceTransform(grown, w, h);
  final reachSquared = reach * reach;
  final mask = Uint8List(w * h);
  for (var i = 0; i < mask.length; i++) {
    if (grown[i] <= reachSquared) mask[i] = 1;
  }
  final runs = _runs(mask, w, h)!;
  return (left: runs.left + left, top: runs.top + top, rows: runs.rows);
}

/// Distance used for "no feature at all".
const double _far = 1e20;

/// The first pixel accepted by [wanted] found by walking at most [steps]
/// pixels from [start] without crossing a wall, or `null`.
int? _nearest(
  Uint8List walls,
  int width,
  int height,
  int start,
  int steps,
  bool Function(int) wanted,
) {
  var frontier = [start];
  final seen = {start};
  for (var step = 0; step < steps && frontier.isNotEmpty; step++) {
    final next = <int>[];
    for (final i in frontier) {
      final x = i % width;
      for (final n in [
        if (x > 0) i - 1,
        if (x < width - 1) i + 1,
        if (i >= width) i - width,
        if (i < width * (height - 1)) i + width,
      ]) {
        if (walls[n] != 0 || !seen.add(n)) continue;
        if (wanted(n)) return n;
        next.add(n);
      }
    }
    frontier = next;
  }
  return null;
}

/// The pixels reachable from [seed] through pixels accepted by [open],
/// moving up, down, left and right, and their bounds.
({Uint8List pixels, int left, int top, int right, int bottom}) _flood(
  int width,
  int height,
  int seed,
  bool Function(int) open,
) {
  final region = Uint8List(width * height);
  final stack = Int32List(width * height);
  var top = 0;
  stack[top++] = seed;
  region[seed] = 1;
  var minX = width, minY = height, maxX = 0, maxY = 0;
  while (top > 0) {
    final i = stack[--top];
    final x = i % width, y = i ~/ width;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
    void visit(int n) {
      if (region[n] == 0 && open(n)) {
        region[n] = 1;
        stack[top++] = n;
      }
    }

    if (x > 0) visit(i - 1);
    if (x < width - 1) visit(i + 1);
    if (i >= width) visit(i - width);
    if (i < width * (height - 1)) visit(i + width);
  }
  return (pixels: region, left: minX, top: minY, right: maxX, bottom: maxY);
}

/// Turns [result], 0 on the features and [_far] elsewhere, into the
/// squared Euclidean distance of every pixel from the nearest feature
/// (Felzenszwalb and Huttenlocher's linear-time algorithm, columns then
/// rows).
void _distanceTransform(Float64List result, int width, int height) {
  final longest = width > height ? width : height;
  final f = Float64List(longest);
  final d = Float64List(longest);
  final v = Int32List(longest);
  final z = Float64List(longest + 1);
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      f[y] = result[y * width + x];
    }
    _transform1d(f, height, d, v, z);
    for (var y = 0; y < height; y++) {
      result[y * width + x] = d[y];
    }
  }
  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      f[x] = result[row + x];
    }
    _transform1d(f, width, d, v, z);
    for (var x = 0; x < width; x++) {
      result[row + x] = d[x];
    }
  }
}

/// One dimensional squared distance transform of the first [n] values of
/// [f] into [d]; [v] and [z] are scratch space.
void _transform1d(
  Float64List f,
  int n,
  Float64List d,
  Int32List v,
  Float64List z,
) {
  const infinity = double.infinity;
  var k = 0;
  v[0] = 0;
  z[0] = -infinity;
  z[1] = infinity;
  for (var q = 1; q < n; q++) {
    double meet(int p) => ((f[q] + q * q) - (f[p] + p * p)) / (2 * q - 2 * p);
    var s = meet(v[k]);
    while (s <= z[k]) {
      k--;
      s = meet(v[k]);
    }
    k++;
    v[k] = q;
    z[k] = s;
    z[k + 1] = infinity;
  }
  k = 0;
  for (var q = 0; q < n; q++) {
    while (z[k + 1] < q) {
      k++;
    }
    final p = v[k];
    d[q] = (q - p) * (q - p) + f[p];
  }
}

/// The nonzero pixels of [mask] as rows of runs, cropped to their bounds.
BucketRegion? _runs(Uint8List mask, int width, int height) {
  var left = width, top = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      if (mask[row + x] == 0) continue;
      if (top < 0) top = y;
      bottom = y;
      if (x < left) left = x;
      break;
    }
  }
  if (top < 0) return null;
  final rows = <Int32List>[];
  for (var y = top; y <= bottom; y++) {
    final row = y * width;
    final runs = <int>[];
    var x = left;
    while (x < width) {
      if (mask[row + x] == 0) {
        x++;
        continue;
      }
      final start = x;
      while (x < width && mask[row + x] != 0) {
        x++;
      }
      runs
        ..add(start - left)
        ..add(x - start);
    }
    rows.add(Int32List.fromList(runs));
  }
  return (left: left, top: top, rows: rows);
}
