import 'package:flutter/painting.dart';

/// Design tokens from docs/design/README.md.
abstract final class Tokens {
  static const paper = Color(0xFFFFF8EE);
  static const sheet = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2D2A32);
  static const graphite = Color(0xFF6B6672);
  static const border = Color(0xFFEADFCF);
  static const coral = Color(0xFFE8553A);
  static const coralLight = Color(0xFFFFE3DA);
  static const sun = Color(0xFFFFC53D);
  static const sunLight = Color(0xFFFFF1C9);
  static const sky = Color(0xFF2C7BE5);
  static const skyLight = Color(0xFFDCEBFF);

  /// The 12 fixed drawing colors (F-05, G-02).
  static const drawingColors = [
    Color(0xFFE63946), // red
    Color(0xFFFF8C42), // orange
    Color(0xFFFFD23F), // yellow
    Color(0xFF8BD346), // light green
    Color(0xFF2A9D3F), // dark green
    Color(0xFF4CC9F0), // light blue
    Color(0xFF1D4ED8), // blue
    Color(0xFF8E44AD), // purple
    Color(0xFFFF7EB6), // pink
    Color(0xFF8B5A2B), // brown
    Color(0xFF1F1F1F), // black
    Color(0xFFFFFFFF), // white
  ];
}
