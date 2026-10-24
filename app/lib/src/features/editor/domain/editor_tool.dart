import 'package:pastello_engine/pastello_engine.dart';

/// The tools of the editor: the engine's drawing tools plus the eraser
/// (F-04). The order is the order of the toolbar.
enum EditorTool {
  pencil(StrokeTool.pencil, WidthPreset.thin),
  marker(StrokeTool.marker, WidthPreset.medium),
  brush(StrokeTool.brush, WidthPreset.thick),
  crayon(StrokeTool.crayon, WidthPreset.medium),
  rainbow(StrokeTool.rainbow, WidthPreset.medium),
  eraser(null, WidthPreset.thick);

  const EditorTool(this.strokeTool, this.defaultWidth);

  /// The engine tool, or `null` for the eraser.
  final StrokeTool? strokeTool;

  /// Width on first use (F-06); then each tool remembers its own.
  final WidthPreset defaultWidth;

  /// Whether the tool paints with the selected color.
  bool get usesColor => this != eraser && this != rainbow;

  /// SVG icon; parts painted with `currentColor` take the selected color.
  String get iconAsset => 'assets/icons/tools/$name.svg';
}
