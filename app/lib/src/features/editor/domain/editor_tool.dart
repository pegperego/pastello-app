import 'package:pastello_engine/pastello_engine.dart';

/// The tools of the editor: the engine's drawing tools, the eraser and the
/// text tool (F-04, F-07). The order is the order of the toolbar.
enum EditorTool {
  pencil(StrokeTool.pencil, WidthPreset.thin),
  marker(StrokeTool.marker, WidthPreset.medium),
  brush(StrokeTool.brush, WidthPreset.thick),
  crayon(StrokeTool.crayon, WidthPreset.medium),
  rainbow(StrokeTool.rainbow, WidthPreset.medium),
  highlighter(StrokeTool.highlighter, WidthPreset.thick),
  neon(StrokeTool.neon, WidthPreset.medium),
  eraser(null, WidthPreset.thick),
  text(null, WidthPreset.medium),
  stickers(null, WidthPreset.medium),
  shapes(null, WidthPreset.medium),
  select(null, WidthPreset.medium);

  const EditorTool(this.strokeTool, this.defaultWidth);

  /// The engine tool, for the tools that draw strokes.
  final StrokeTool? strokeTool;

  /// Whether a finger on the sheet draws (or erases) with this tool.
  bool get draws => !selects;

  /// Whether the width presets apply to this tool.
  bool get usesWidth => !selects || this == shapes;

  /// Whether touching texts, stickers and shapes selects them (F-07): with
  /// drawing tools a touch always draws.
  bool get selects =>
      this == text || this == stickers || this == shapes || this == select;

  /// Width on first use (F-06); then each tool remembers its own.
  final WidthPreset defaultWidth;

  /// Whether the tool paints with the selected color.
  bool get usesColor =>
      this != eraser && this != rainbow && this != stickers && this != select;

  /// SVG icon; parts painted with `currentColor` take the selected color.
  String get iconAsset => 'assets/icons/tools/$name.svg';
}

/// The groups of tools shown in the toolbar (F-20). A category with more
/// than one tool opens a flyout with them.
enum ToolCategory {
  draw([
    EditorTool.pencil,
    EditorTool.marker,
    EditorTool.brush,
    EditorTool.crayon,
  ]),
  magic([EditorTool.rainbow, EditorTool.highlighter, EditorTool.neon]),
  eraser([EditorTool.eraser]),
  text([EditorTool.text]),
  stickers([EditorTool.stickers]),
  shapes([EditorTool.shapes]),
  select([EditorTool.select]);

  const ToolCategory(this.tools);

  /// The tools of the category, in the order shown in its flyout.
  final List<EditorTool> tools;

  /// Whether the category opens a flyout to choose among its tools.
  bool get hasFlyout => tools.length > 1;
}

extension EditorToolCategory on EditorTool {
  /// The category this tool belongs to.
  ToolCategory get category =>
      ToolCategory.values.firstWhere((c) => c.tools.contains(this));
}
