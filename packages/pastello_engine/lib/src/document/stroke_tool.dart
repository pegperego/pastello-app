/// The freehand drawing tools (functional decision F-04).
enum StrokeTool {
  /// Thin, precise line with a light graphite grain. Constant width.
  pencil,

  /// Solid, opaque line with clean edges. Constant width.
  marker,

  /// Soft line whose width follows the drawing speed.
  brush,

  /// Waxy line with a strong paper grain: the app's signature tool.
  crayon,

  /// Line whose color cycles through the rainbow along its length.
  rainbow,

  /// Wide, semi-transparent line with a flat tip (F-17). Going over the
  /// same stroke again does not make it darker.
  highlighter,

  /// Light core with a glow of the selected color (F-17).
  neon,

  /// Sparkles of different sizes and brightness along the line (F-17).
  glitter,

  /// A trail of stars at regular spacing, sized by the width (F-17).
  stars,

  /// A cloud of dots, denser in the middle, like a spray can (F-17).
  spray,

  /// Soft, transparent color with blurred edges; going over it again makes
  /// it darker (F-17).
  watercolor;

  /// How far the ink reaches beyond the input points, for a stroke [width].
  double margin(double width) => switch (this) {
    neon => width * 2,
    stars => starSize(width) / 2 + 1,
    _ => width,
  };

  /// Whether the stroke is made of pieces placed with a random seed: its
  /// points are kept as they were drawn, so the pieces stay where the child
  /// saw them (F-17).
  bool get isRandom =>
      this == glitter || this == stars || this == spray || this == watercolor;

  /// Whether the paint bucket stops at strokes of this tool (F-18): solid
  /// lines do; see-through ones and the ones made of loose pieces do not.
  bool get isBorder => switch (this) {
    pencil || marker || brush || crayon || rainbow || neon => true,
    _ => false,
  };
}

/// Size of the stars of [StrokeTool.stars] for a stroke [width]: even the
/// thin ones are big enough to look like stars.
double starSize(double width) => width * 1.2 + 8;

/// Width presets offered by the toolbar (functional decision F-06).
///
/// Values are in sheet units and will be tuned on the reference device.
enum WidthPreset {
  /// Thin.
  thin(4),

  /// Medium.
  medium(10),

  /// Thick.
  thick(20),

  /// Extra thick.
  extraThick(40);

  const WidthPreset(this.width);

  /// Stroke width in sheet units.
  final double width;
}
