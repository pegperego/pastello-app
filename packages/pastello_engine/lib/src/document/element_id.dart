import 'dart:math';

final Random _random = Random.secure();

/// Returns a new random identifier for a drawing element.
///
/// 128 random bits encoded as 32 hex characters. We generate it ourselves
/// instead of depending on a UUID package (ADR 0014).
String newElementId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
