import 'package:flutter/painting.dart';

/// Design tokens, see docs/design/README.md.
abstract final class Tokens {
  /// App background.
  static const paper = Color(0xFFFFF8EE);

  /// Drawing area.
  static const sheet = Color(0xFFFFFFFF);

  /// Text and icon outlines.
  static const ink = Color(0xFF2D2A32);

  /// Secondary text.
  static const graphite = Color(0xFF6B6672);

  /// Dividers.
  static const border = Color(0xFFEADFCF);

  /// Primary: the "+" button and the active tool.
  static const coral = Color(0xFFE8553A);

  /// Darker coral, for the 3D edge of the "+" button.
  static const coralDark = Color(0xFFB83E26);

  /// Accent, toggles on.
  static const sun = Color(0xFFFFC53D);

  /// Selection and handles.
  static const sky = Color(0xFF2C7BE5);

  /// Confirm.
  static const mint = Color(0xFF1E9E85);

  /// Delete.
  static const raspberry = Color(0xFFD93D42);

  /// Minimum size of anything a child can tap (G-08).
  static const double minTouchTarget = 56;
}
