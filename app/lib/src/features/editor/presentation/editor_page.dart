import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/tokens.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/editor_controller.dart';
import '../domain/editor_tool.dart';
import '../domain/palette.dart';
import 'editor_buttons.dart';
import 'labels.dart';
import 'more_colors_sheet.dart';
import 'sheet_view.dart';

/// The editor: action bar on top, tools and colors on the sides (landscape)
/// or at the bottom (portrait), the sheet in the middle (F-03).
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final PaperGrain _grain = PaperGrain.generate();
  late final DrawingRenderer _renderer = DrawingRenderer(grain: _grain);
  final LiveStroke _live = LiveStroke();

  @override
  void dispose() {
    _live.dispose();
    _renderer.dispose();
    _grain.dispose();
    super.dispose();
  }

  void _onStrokeStart() {
    final state = ref.read(editorProvider);
    _live.begin(
      tool: state.tool.strokeTool,
      color: state.color,
      width: state.width,
    );
  }

  void _onStrokeEnd() {
    ref.read(editorProvider.notifier).commitStroke(List.of(_live.points));
    _live.clear();
  }

  Future<void> _pickMoreColors(AppLocalizations l10n) async {
    final color = await showMoreColors(
      context,
      selected: ref.read(editorProvider).color,
      colorLabel: l10n.color,
    );
    if (color != null) ref.read(editorProvider.notifier).selectColor(color);
  }

  void _toggleRotationLock(bool locked) {
    final orientation = MediaQuery.orientationOf(context);
    final lock = locked
        ? null
        : orientation == Orientation.landscape
        ? LockedOrientation.landscape
        : LockedOrientation.portrait;
    ref
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(rotationLock: () => lock));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(editorProvider);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final controller = ref.read(editorProvider.notifier);

    // Keep the renderer in sync with the drawing.
    ref.listen(editorProvider, (previous, next) {
      final drawing = next.drawing;
      if (drawing == null || previous?.revision == next.revision) return;
      final erasure = next.lastErasure;
      if (erasure != null) {
        _renderer.showErased(drawing, erasure);
      } else {
        _renderer.show(drawing);
      }
    });

    final sheet = Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.biggest;
          final drawing = state.drawing;
          if (drawing == null || drawing.sheetSize != available) {
            // The controller decides whether the sheet may change shape.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) controller.ensureSheet(available);
            });
          }
          if (drawing == null) return const SizedBox.expand();
          return SheetView(
            sheetSize: drawing.sheetSize,
            renderer: _renderer,
            live: _live,
            semanticLabel: l10n.sheet,
            onStrokeStart: _onStrokeStart,
            onStrokeEnd: _onStrokeEnd,
          );
        },
      ),
    );

    final tools = [
      for (final tool in EditorTool.values)
        ToolButton(
          tool: tool,
          label: toolLabel(l10n, tool),
          color: state.color,
          selected: tool == state.tool,
          onPressed: () => controller.selectTool(tool),
        ),
    ];

    final extra = state.extraColor;
    final colors = [
      for (final color in drawingColors)
        ColorSwatchButton(
          color: color,
          label: l10n.color,
          selected: color == state.color,
          onPressed: () => controller.selectColor(color),
        ),
      if (extra != null)
        ColorSwatchButton(
          color: extra,
          label: l10n.color,
          selected: extra == state.color,
          onPressed: () => controller.selectColor(extra),
        ),
      ColorSwatchButton(
        color: Tokens.sheet,
        label: l10n.moreColors,
        selected: false,
        onPressed: () => _pickMoreColors(l10n),
        child: const Icon(Icons.palette_rounded, color: Tokens.ink),
      ),
    ];

    final widths = [
      for (final width in WidthPreset.values)
        WidthButton(
          dotSize: 6.0 + width.index * 9,
          color: state.tool.usesColor ? state.color : Tokens.graphite,
          label: widthLabel(l10n, width),
          selected: state.widths[state.tool] == width,
          onPressed: () => controller.selectWidth(width),
        ),
    ];

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    Widget body;
    if (landscape) {
      final toolColumn = _ScrollColumn(width: 84, children: tools);
      final colorColumn = _ScrollColumn(
        width: 124,
        children: [
          Wrap(children: colors),
          const SizedBox(height: 8),
          ...widths,
        ],
      );
      body = Row(
        children: settings.leftHanded
            ? [colorColumn, Expanded(child: sheet), toolColumn]
            : [toolColumn, Expanded(child: sheet), colorColumn],
      );
    } else {
      body = Column(
        children: [
          Expanded(child: sheet),
          _ScrollRow(children: [...colors, ...widths]),
          _ScrollRow(children: tools),
        ],
      );
    }

    final locked = settings.rotationLock != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 72,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  ActionButton(
                    icon: Icons.home_rounded,
                    tooltip: l10n.backToGallery,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  ActionButton(
                    icon: Icons.undo_rounded,
                    tooltip: l10n.undo,
                    onPressed: state.canUndo ? controller.undo : null,
                  ),
                  ActionButton(
                    icon: Icons.redo_rounded,
                    tooltip: l10n.redo,
                    onPressed: state.canRedo ? controller.redo : null,
                  ),
                  const Spacer(),
                  ActionButton(
                    icon: locked
                        ? Icons.screen_lock_rotation_rounded
                        : Icons.screen_rotation_rounded,
                    tooltip: locked ? l10n.unlockRotation : l10n.lockRotation,
                    active: locked,
                    onPressed: () => _toggleRotationLock(locked),
                  ),
                  _MoreMenu(
                    tooltip: l10n.more,
                    clearLabel: l10n.clearSheet,
                    onClear: (state.drawing?.isEmpty ?? true)
                        ? null
                        : controller.clear,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(height: 1.5),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.tooltip,
    required this.clearLabel,
    required this.onClear,
  });

  final String tooltip;
  final String clearLabel;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.layers_clear_rounded),
          onPressed: onClear,
          child: Text(clearLabel, style: const TextStyle(fontSize: 18)),
        ),
      ],
      builder: (context, menu, _) => ActionButton(
        icon: Icons.more_horiz_rounded,
        tooltip: tooltip,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _ScrollColumn extends StatelessWidget {
  const _ScrollColumn({required this.width, required this.children});

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: children),
    ),
  );
}

class _ScrollRow extends StatelessWidget {
  const _ScrollRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: children),
    ),
  );
}
