import 'dart:math' as math;
import 'dart:ui';

/// The paper patterns (F-10).
enum BackgroundPattern {
  /// Plain paper.
  none,

  /// Notebook lines, light blue, with a red margin on the left.
  lines,

  /// Big squares, about 1 cm when printed on A4.
  bigSquares,

  /// Small squares, about 5 mm when printed on A4.
  smallSquares,

  /// A grid of light dots.
  dots,
}

/// The background of a sheet: a color and an optional pattern (F-10).
///
/// Patterns are measured on the printed page: one centimeter is the sheet's
/// long side divided by the long side of an A4 page (29.7 cm), so that a
/// printed sheet looks like a school notebook.
class SheetBackground {
  /// Creates a background.
  const SheetBackground({
    this.color = const Color(0xFFFFFFFF),
    this.pattern = BackgroundPattern.none,
  });

  /// Plain white paper, the default (F-02).
  static const white = SheetBackground();

  /// Paper color.
  final Color color;

  /// Pattern drawn on the paper.
  final BackgroundPattern pattern;

  /// Whether this is [white].
  bool get isDefault =>
      color == white.color && pattern == BackgroundPattern.none;

  /// Sheet units per printed centimeter for a sheet of [size].
  static double centimeter(Size size) => size.longestSide / 29.7;

  /// Paints the background on the whole sheet of [size], in sheet units.
  void paint(Canvas canvas, Size size) {
    final sheet = Offset.zero & size;
    canvas.drawRect(sheet, Paint()..color = color);
    if (pattern == BackgroundPattern.none) return;

    final cm = centimeter(size);
    // Pattern colors stay readable on light papers and soft on dark ones.
    final dark = color.computeLuminance() < 0.35;
    final ink = dark ? const Color(0x55FFFFFF) : const Color(0xFF9DC3E6);
    final line = Paint()
      ..color = ink
      ..strokeWidth = math.max(1, cm * 0.03);

    switch (pattern) {
      case BackgroundPattern.none:
        break;
      case BackgroundPattern.lines:
        for (var y = cm * 1.5; y < size.height; y += cm) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        canvas.drawLine(
          Offset(cm * 2.5, 0),
          Offset(cm * 2.5, size.height),
          Paint()
            ..color = dark ? const Color(0x88FF9A9A) : const Color(0xFFE8908A)
            ..strokeWidth = line.strokeWidth * 1.5,
        );
      case BackgroundPattern.bigSquares:
      case BackgroundPattern.smallSquares:
        final step = pattern == BackgroundPattern.bigSquares ? cm : cm / 2;
        for (var x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
        for (var y = step; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
      case BackgroundPattern.dots:
        final dot = Paint()
          ..color = dark ? const Color(0x77FFFFFF) : const Color(0xFF9AA8B8);
        for (var y = cm; y < size.height; y += cm) {
          for (var x = cm; x < size.width; x += cm) {
            canvas.drawCircle(Offset(x, y), cm * 0.05, dot);
          }
        }
    }
  }

  /// Returns a copy with the given fields replaced.
  SheetBackground copyWith({Color? color, BackgroundPattern? pattern}) =>
      SheetBackground(
        color: color ?? this.color,
        pattern: pattern ?? this.pattern,
      );

  @override
  bool operator ==(Object other) =>
      other is SheetBackground &&
      other.color == color &&
      other.pattern == pattern;

  @override
  int get hashCode => Object.hash(color, pattern);
}
