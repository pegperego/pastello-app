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
}

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
