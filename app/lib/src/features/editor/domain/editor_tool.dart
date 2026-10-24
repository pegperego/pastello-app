import 'package:pastello_engine/pastello_engine.dart';

/// The tools of the editor: the engine's drawing tools, the eraser and the
/// text tool (F-04, F-07). The order is the order of the toolbar.
enum EditorTool {
  pencil(StrokeTool.pencil, WidthPreset.thin),
  marker(StrokeTool.marker, WidthPreset.medium),
  brush(StrokeTool.brush, WidthPreset.thick),
  crayon(StrokeTool.crayon, WidthPreset.medium),
  rainbow(StrokeTool.rainbow, WidthPreset.medium),
  eraser(null, WidthPreset.thick),
  text(null, WidthPreset.medium);

  const EditorTool(this.strokeTool, this.defaultWidth);

  /// The engine tool, for the tools that draw strokes.
  final StrokeTool? strokeTool;

  /// Whether a finger on the sheet draws (or erases) with this tool.
  bool get draws => this != text;

  /// Whether the width presets apply to this tool.
  bool get usesWidth => this != text;

  /// Whether touching texts (and later stickers and shapes) selects them
  /// (F-07): with drawing tools a touch always draws.
  bool get selects => this == text;

  /// Width on first use (F-06); then each tool remembers its own.
  final WidthPreset defaultWidth;

  /// Whether the tool paints with the selected color.
  bool get usesColor => this != eraser && this != rainbow;

  /// SVG icon; parts painted with `currentColor` take the selected color.
  String get iconAsset => 'assets/icons/tools/$name.svg';
}
