import 'dart:ui';

/// A sampled input point, in sheet units.
///
/// Sheet units are independent from screen pixels (ADR 0004): a drawing looks
/// the same on every device and can be exported at any resolution.
class SheetPoint {
  /// Creates a point at ([x], [y]).
  ///
  /// [pressure] is in the range 0..1 and is only meaningful for styluses; for
  /// fingers it is left at the neutral value 0.5. [time] is the time in
  /// milliseconds since the stroke started and is used to derive speed.
  const SheetPoint(this.x, this.y, {this.pressure = 0.5, this.time = 0});

  /// Horizontal position in sheet units.
  final double x;

  /// Vertical position in sheet units.
  final double y;

  /// Normalized pressure, 0..1.
  final double pressure;

  /// Milliseconds since the first point of the stroke.
  final int time;

  /// This point as an [Offset].
  Offset get offset => Offset(x, y);

  /// Euclidean distance to [other].
  double distanceTo(SheetPoint other) => (offset - other.offset).distance;

  @override
  bool operator ==(Object other) =>
      other is SheetPoint &&
      other.x == x &&
      other.y == y &&
      other.pressure == pressure &&
      other.time == time;

  @override
  int get hashCode => Object.hash(x, y, pressure, time);

  @override
  String toString() => 'SheetPoint($x, $y)';
}
