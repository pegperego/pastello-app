import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/tokens.dart';
import '../../../core/feedback/feedback.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../export/application/export_actions.dart';
import '../../stickers/application/stickers_providers.dart';
import '../../stickers/presentation/sticker_panel.dart';
import '../application/editor_controller.dart';
import '../domain/editor_tool.dart';
import '../domain/palette.dart';
import 'editor_buttons.dart';
import 'font_sheet.dart';
import 'labels.dart';
import 'more_colors_sheet.dart';
import 'paper_panel.dart';
import 'selection_overlay.dart';
import 'shape_panel.dart';
import 'sheet_view.dart';
import 'text_edit_panel.dart';

/// The editor: action bar on top, tools and colors on the sides (landscape)
/// or at the bottom (portrait), the sheet in the middle (F-03).
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, this.drawingId});

  /// The saved drawing to open, or `null` for a new one.
  final String? drawingId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final PaperGrain _grain = PaperGrain.generate();
  late final DrawingRenderer _renderer = DrawingRenderer(grain: _grain);
  final LiveStroke _live = LiveStroke();
  late final AppLifecycleListener _lifecycle;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // Save as soon as the app is hidden: it may never come back (ADR 0010).
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(editorProvider.notifier).flush(),
    );
    final id = widget.drawingId;
    if (id != null) {
      // Not during build: opening changes the editor's state.
      Future.microtask(() => ref.read(editorProvider.notifier).open(id));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _live.dispose();
    _renderer.dispose();
    _grain.dispose();
    super.dispose();
  }

  /// Saves, then goes back to the gallery. There is no Save button: leaving
  /// always keeps the drawing.
  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await ref.read(editorProvider.notifier).flush();
    if (mounted) Navigator.of(context).pop();
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

  /// Selects the Stickers tool and opens the panel; choosing a sticker arms
  /// it for the next tap on the sheet (F-11).
  Future<void> _openStickers(AppLocalizations l10n) async {
    final controller = ref.read(editorProvider.notifier)
      ..selectTool(EditorTool.stickers);
    final packs = await ref.read(stickerPacksProvider.future);
    if (!mounted) return;
    final choice = await showStickerPanel(
      context,
      packs: packs,
      languageCode: Localizations.localeOf(context).languageCode,
      title: l10n.chooseSticker,
      selectedPackId: ref.read(editorProvider).sticker?.packId,
    );
    if (choice != null) {
      controller.chooseSticker(StickerChoice(choice.$1, choice.$2));
    }
  }

  /// Selects the Shapes tool and opens the panel (F-12).
  Future<void> _openShapes() async {
    final controller = ref.read(editorProvider.notifier)
      ..selectTool(EditorTool.shapes);
    final state = ref.read(editorProvider);
    final choice = await showShapePanel(
      context,
      selected: state.shapeKind,
      filled: state.shapeFilled,
      color: state.color,
    );
    if (choice != null) controller.chooseShape(choice.$1, filled: choice.$2);
  }

  /// Saves, prints or shares the current drawing; `null` (disabled) for an
  /// empty sheet. A text being typed is committed first.
  VoidCallback? _exportAction(EditorState state, ExportAction action) {
    final drawing = state.drawing;
    if (drawing == null || drawing.isEmpty) return null;
    return () {
      final controller = ref.read(editorProvider.notifier)..commitText();
      final current = ref.read(editorProvider).drawing ?? drawing;
      unawaited(controller.flush());
      runExport(context, ref, current, action);
    };
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

    // Sticker artwork loads once in the background; until then stickers are
    // drawn as placeholders.
    final artwork = ref.watch(stickerArtworkProvider).value;
    if (artwork != null && !identical(_renderer.stickers, artwork)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _renderer.stickers = artwork,
      );
    }

    // A light tick when a shape snaps to a perfect figure (F-12).
    ref.listen(editorProvider.select((s) => s.shapeSnapped), (
      previous,
      snapped,
    ) {
      if (snapped && previous == false) ref.read(feedbackProvider).tick();
    });

    // Sounds for what lands on or leaves the sheet (F-15).
    ref.listen(editorProvider, (previous, next) {
      if (previous == null || previous.revision == next.revision) return;
      final before = previous.drawing?.elements.length ?? 0;
      final after = next.drawing?.elements.length ?? 0;
      final feedback = ref.read(feedbackProvider);
      if (after > before && next.drawing!.elements.last is StickerElement) {
        feedback.sound(AppSound.pop);
      } else if (after < before && next.canUndo) {
        feedback.sound(AppSound.whoosh);
      }
    });
    ref.listen(editorProvider.select((s) => s.tool), (previous, tool) {
      if (previous != null && previous != tool) {
        ref.read(feedbackProvider).tick();
      }
    });

    // Keep the renderer in sync with the drawing and the floating elements
    // (the text being typed, the element being moved).
    ref.listen(editorProvider, (previous, next) {
      final drawing = next.drawing;
      if (drawing == null) return;
      final erasure = next.lastErasure;
      if (previous?.revision != next.revision && erasure != null) {
        _renderer.showErased(drawing, erasure);
      } else if (previous?.revision != next.revision ||
          !listEquals(previous?.floating, next.floating)) {
        _renderer.show(drawing, floating: next.floating);
      }
    });

    final sheet = Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.biggest;
          final drawing = state.drawing;
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
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
            draws: state.tool.draws,
            onTap: controller.tapSheet,
            onDragStart: switch (state.tool) {
              EditorTool.shapes => controller.beginShape,
              EditorTool.select => controller.beginLasso,
              _ => null,
            },
            onDragUpdate: switch (state.tool) {
              EditorTool.shapes => controller.updateShape,
              EditorTool.select => controller.updateLasso,
              _ => null,
            },
            onDragEnd: switch (state.tool) {
              EditorTool.shapes => controller.endShape,
              EditorTool.select => controller.endLasso,
              _ => null,
            },
            overlayBuilder: (context, scale) =>
                _selectionOverlay(l10n, state, scale),
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
          onPressed: switch (tool) {
            EditorTool.stickers => () => _openStickers(l10n),
            EditorTool.shapes => _openShapes,
            _ => () => controller.selectTool(tool),
          },
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
      if (state.tool.usesWidth)
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
      // Two columns, so that all the tools are visible without scrolling.
      final toolColumn = _ScrollColumn(
        width: 148,
        children: [Wrap(children: tools)],
      );
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

    final editing = state.editing;
    if (editing != null) {
      // The text field sits above the keyboard; the sheet does not shrink
      // (see resizeToAvoidBottomInset), so it never changes shape.
      body = Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
            child: TextEditPanel(
              key: ValueKey(editing.id),
              initialText: editing.text,
              hint: l10n.writeHere,
              doneLabel: l10n.done,
              onChanged: controller.updateText,
              onDone: controller.commitText,
            ),
          ),
        ],
      );
    }

    final locked = settings.rotationLock != null;
    return PopScope(
      canPop: false,
      // The system back gesture saves too.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
                      onPressed: _leave,
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
                      icon: Icons.description_rounded,
                      tooltip: l10n.paper,
                      onPressed: state.drawing == null
                          ? null
                          : () => showPaperPanel(
                              context,
                              current: () =>
                                  ref.read(editorProvider).drawing!.background,
                              onChanged: controller.changeBackground,
                            ),
                    ),
                    ActionButton(
                      icon: locked
                          ? Icons.screen_lock_rotation_rounded
                          : Icons.screen_rotation_rounded,
                      tooltip: locked ? l10n.unlockRotation : l10n.lockRotation,
                      active: locked,
                      onPressed: () => _toggleRotationLock(locked),
                    ),
                    ActionButton(
                      icon: Icons.print_rounded,
                      tooltip: l10n.print,
                      onPressed: _exportAction(state, ExportAction.print),
                    ),
                    _MoreMenu(
                      tooltip: l10n.more,
                      items: [
                        (
                          Icons.photo_library_rounded,
                          l10n.saveToGallery,
                          _exportAction(state, ExportAction.save),
                        ),
                        (
                          Icons.share_rounded,
                          l10n.share,
                          _exportAction(state, ExportAction.share),
                        ),
                        (
                          Icons.layers_clear_rounded,
                          l10n.clearSheet,
                          (state.drawing?.isEmpty ?? true)
                              ? null
                              : controller.clear,
                        ),
                      ],
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
      ),
    );
  }
}

extension on _EditorPageState {
  /// The selection frame and its buttons, for the selected text (F-07).
  Widget _selectionOverlay(
    AppLocalizations l10n,
    EditorState state,
    double scale,
  ) {
    final controller = ref.read(editorProvider.notifier);
    final lasso = state.lasso;
    if (lasso != null) {
      return IgnorePointer(
        child: CustomPaint(painter: LassoPainter(lasso, scale)),
      );
    }
    final box = state.groupBox, frame = state.groupFrame;
    if (state.groupIds.isNotEmpty && box != null && frame != null) {
      return ElementSelectionOverlay(
        element: GroupFrame(size: box.size, transform: frame),
        scale: scale,
        rotateLabel: l10n.rotate,
        resizeLabel: l10n.resize,
        onTransform: controller.previewGroup,
        onTransformEnd: controller.commitGroup,
        actions: [
          SelectionAction(
            icon: Icons.content_copy_rounded,
            tooltip: l10n.duplicateElement,
            onPressed: controller.duplicateGroup,
          ),
          SelectionAction(
            icon: Icons.delete_rounded,
            tooltip: l10n.deleteElement,
            color: Tokens.raspberry,
            onPressed: controller.deleteGroup,
          ),
        ],
      );
    }
    final selected = state.selected;
    if (!state.tool.selects || selected == null || state.editing != null) {
      return const SizedBox.shrink();
    }
    return ElementSelectionOverlay(
      element: selected,
      scale: scale,
      rotateLabel: l10n.rotate,
      resizeLabel: l10n.resize,
      onTransform: controller.previewTransform,
      onTransformEnd: controller.commitTransform,
      actions: [
        SelectionAction(
          icon: Icons.content_copy_rounded,
          tooltip: l10n.duplicateElement,
          onPressed: controller.duplicateSelected,
        ),
        if (selected is TextElement) ...[
          SelectionAction(
            icon: Icons.edit_rounded,
            tooltip: l10n.editText,
            onPressed: controller.editSelected,
          ),
          SelectionAction(
            icon: Icons.font_download_rounded,
            tooltip: l10n.font,
            onPressed: () async {
              final font = await showFontSheet(
                context,
                selected: selected.font,
                sample: l10n.fontSample,
              );
              if (font != null) controller.selectFont(font);
            },
          ),
        ],
        SelectionAction(
          icon: Icons.delete_rounded,
          tooltip: l10n.deleteElement,
          color: Tokens.raspberry,
          onPressed: controller.deleteSelected,
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.tooltip, required this.items});

  final String tooltip;

  /// Icon, label and action of each entry; a `null` action disables it.
  final List<(IconData, String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final (icon, label, onPressed) in items)
          MenuItemButton(
            leadingIcon: Icon(icon),
            onPressed: onPressed,
            child: Text(label, style: const TextStyle(fontSize: 18)),
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
