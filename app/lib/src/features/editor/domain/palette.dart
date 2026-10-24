import 'dart:ui';

/// The 12 colors always visible (F-05, G-02).
const drawingColors = <Color>[
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

/// The "more colors" grid: 4 rows of 10 (F-05, G-02).
const moreColors = <Color>[
  // Skin tones.
  Color(0xFFFDE3CF), Color(0xFFF6CBA4), Color(0xFFE8B07F), Color(0xFFC98B5A),
  Color(0xFF9C6640), Color(0xFF6E4428), Color(0xFF4A2C1A), Color(0xFFF2D5C4),
  Color(0xFFDDB99A), Color(0xFFB98663),
  // Pastels.
  Color(0xFFFFC9CF), Color(0xFFFFDDB8), Color(0xFFFFF3B0), Color(0xFFD6F5C2),
  Color(0xFFC2EDE3), Color(0xFFCDEBFF), Color(0xFFD3D9FF), Color(0xFFE6D3FF),
  Color(0xFFFFD1EC), Color(0xFFEADBC8),
  // Darks.
  Color(0xFF9B1D2A), Color(0xFFB4521D), Color(0xFFB98B00), Color(0xFF4F7A1F),
  Color(0xFF14532D), Color(0xFF0E7490), Color(0xFF1E2A78), Color(0xFF4C1D6E),
  Color(0xFFA3135F), Color(0xFF4E342E),
  // Greys and vivid colors.
  Color(0xFFFFFFFF), Color(0xFFE5E5E5), Color(0xFFC4C4C4), Color(0xFF9A9A9A),
  Color(0xFF6E6E6E), Color(0xFF444444), Color(0xFF00C2A8), Color(0xFFFF5E78),
  Color(0xFFC0E218), Color(0xFFFFB000),
];
