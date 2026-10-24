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
};

/// Localized name of [width].
String widthLabel(AppLocalizations l10n, WidthPreset width) => switch (width) {
  WidthPreset.thin => l10n.widthThin,
  WidthPreset.medium => l10n.widthMedium,
  WidthPreset.thick => l10n.widthThick,
  WidthPreset.extraThick => l10n.widthExtraThick,
};
