import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A tileable noise texture that simulates the tooth of drawing paper.
///
/// Crayon and pencil strokes are "bitten" by this texture: where the grain is
/// opaque the stroke is removed, as if the wax skipped over the paper's
/// valleys. The texture is anchored to the sheet, not to the stroke, so
/// overlapping strokes share the same paper.
class PaperGrain {
  PaperGrain._(this.image, this.texelSize);

  /// Generates the grain procedurally, without any bundled asset.
  ///
  /// The texture is seamless value noise in two octaves plus a little white
  /// noise, passed through a contrast curve: most of the tile is transparent
  /// and only the "valleys" of the paper are opaque. [size] is the tile size
  /// in texels and [texelSize] how many sheet units a texel covers. The [seed]
  /// makes the texture deterministic (golden tests).
  factory PaperGrain.generate({
    int size = 256,
    double texelSize = 0.8,
    int seed = 7,
  }) {
    final random = math.Random(seed);
    final coarse = _PeriodicNoise(size ~/ 4, random);
    final fine = _PeriodicNoise(size ~/ 2, random);

    // Bucket texels by opacity so the whole tile is drawn with a few
    // drawRawPoints calls instead of one call per texel.
    const levels = 16;
    final buckets = List.generate(levels, (_) => <double>[]);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final u = x / size, v = y / size;
        final n =
            0.4 * coarse.sample(u, v) +
            0.35 * fine.sample(u, v) +
            0.25 * random.nextDouble();
        final alpha = _smoothstep(0.52, 0.74, n);
        final level = (alpha * (levels - 1)).round();
        if (level == 0) continue;
        buckets[level]
          ..add(x + 0.5)
          ..add(y + 0.5);
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (var level = 1; level < levels; level++) {
      final paint = ui.Paint()
        ..color = ui.Color.fromARGB(
          (255 * level / (levels - 1)).round(),
          0,
          0,
          0,
        )
        ..strokeWidth = 1
        ..strokeCap = ui.StrokeCap.square;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(buckets[level]),
        paint,
      );
    }
    final image = recorder.endRecording().toImageSync(size, size);
    return PaperGrain._(image, texelSize);
  }

  /// The grain tile. Only the alpha channel is meaningful.
  final ui.Image image;

  /// Sheet units covered by one texel.
  final double texelSize;

  /// A repeating shader that maps the grain onto sheet coordinates.
  ui.Shader shader() {
    final s = texelSize;
    return ui.ImageShader(
      image,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );
  }

  /// Releases the texture.
  void dispose() => image.dispose();
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Value noise on a [cells] x [cells] lattice that wraps around, so the tile
/// repeats without visible seams.
class _PeriodicNoise {
  _PeriodicNoise(this.cells, math.Random random)
    : _values = List.generate(cells * cells, (_) => random.nextDouble());

  final int cells;
  final List<double> _values;

  double _at(int x, int y) => _values[(y % cells) * cells + (x % cells)];

  /// Samples the noise at ([u], [v]), both in 0..1.
  double sample(double u, double v) {
    final x = u * cells, y = v * cells;
    final x0 = x.floor(), y0 = y.floor();
    final tx = _smoothstep(0, 1, x - x0), ty = _smoothstep(0, 1, y - y0);
    final top = _at(x0, y0) + (_at(x0 + 1, y0) - _at(x0, y0)) * tx;
    final bottom =
        _at(x0, y0 + 1) + (_at(x0 + 1, y0 + 1) - _at(x0, y0 + 1)) * tx;
    return top + (bottom - top) * ty;
  }
}
