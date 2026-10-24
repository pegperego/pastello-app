import 'package:pastello_engine/pastello_engine.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/editor_tool.dart';

/// Localized name of [tool], for tooltips and screen readers.
String toolLabel(AppLocalizations l10n, EditorTool tool) => switch (tool) {
  EditorTool.pencil => l10n.toolPencil,
  EditorTool.marker => l10n.toolMarker,
  EditorTool.brush => l10n.toolBrush,
  EditorTool.crayon => l10n.toolCrayon,
  EditorTool.rainbow => l10n.toolRainbow,
  EditorTool.eraser => l10n.toolEraser,
  EditorTool.text => l10n.toolText,
  EditorTool.stickers => l10n.toolStickers,
  EditorTool.shapes => l10n.toolShapes,
  EditorTool.select => l10n.toolSelect,
};

/// Localized name of [width].
String widthLabel(AppLocalizations l10n, WidthPreset width) => switch (width) {
  WidthPreset.thin => l10n.widthThin,
  WidthPreset.medium => l10n.widthMedium,
  WidthPreset.thick => l10n.widthThick,
  WidthPreset.extraThick => l10n.widthExtraThick,
};

/// Localized name of a shape.
String shapeLabel(AppLocalizations l10n, ShapeKind kind) => switch (kind) {
  ShapeKind.ellipse => l10n.shapeEllipse,
  ShapeKind.rectangle => l10n.shapeRectangle,
  ShapeKind.triangle => l10n.shapeTriangle,
  ShapeKind.star => l10n.shapeStar,
  ShapeKind.heart => l10n.shapeHeart,
  ShapeKind.line => l10n.shapeLine,
  ShapeKind.arrow => l10n.shapeArrow,
};

/// Localized name of a paper pattern.
String patternLabel(AppLocalizations l10n, BackgroundPattern pattern) =>
    switch (pattern) {
      BackgroundPattern.none => l10n.patternNone,
      BackgroundPattern.lines => l10n.patternLines,
      BackgroundPattern.bigSquares => l10n.patternBigSquares,
      BackgroundPattern.smallSquares => l10n.patternSmallSquares,
      BackgroundPattern.dots => l10n.patternDots,
    };
