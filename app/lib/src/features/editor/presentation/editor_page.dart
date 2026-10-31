import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../app/app_icon.dart';
import '../../../app/tokens.dart';
import '../../../core/feedback/feedback.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../export/application/export_actions.dart';
import '../../coloring/application/coloring_providers.dart';
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
  const EditorPage({super.key, this.drawingId, this.outline});

  /// The saved drawing to open, or `null` for a new one.
  final String? drawingId;

  /// The coloring page a new drawing starts from (F-19).
  final ColoringOutline? outline;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final PaperGrain _grain = PaperGrain.generate();
  late final DrawingRenderer _renderer = DrawingRenderer(grain: _grain);
  final LiveStroke _live = LiveStroke();
  final math.Random _random = math.Random();
  late final AppLifecycleListener _lifecycle;
  bool _leaving = false;

  // Flyouts of the toolbar (F-20): the category whose tools are shown, and
  // the width presets in portrait. They close by themselves when a choice is
  // made or the sheet is touched.
  final GlobalKey _stackKey = GlobalKey();
  final Map<ToolCategory, GlobalKey> _categoryKeys = {
    for (final c in ToolCategory.values) c: GlobalKey(),
  };
  final GlobalKey _widthKey = GlobalKey();
  ToolCategory? _flyout;
  bool _widthsOpen = false;
  Orientation? _orientation;

  @override
  void initState() {
    super.initState();
    // Save as soon as the app is hidden: it may never come back (ADR 0010).
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(editorProvider.notifier).flush(),
    );
    final outline = widget.outline;
    if (outline != null) {
      ref.read(editorProvider.notifier).startColoring(outline);
    }
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
      seed: _random.nextInt(1 << 31),
    );
  }

  void _onStrokeEnd() {
    ref
        .read(editorProvider.notifier)
        .commitStroke(List.of(_live.points), seed: _live.seed);
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

  /// Selects [tool], opening its panel for stickers and shapes.
  void _useTool(EditorTool tool, AppLocalizations l10n) => switch (tool) {
    EditorTool.stickers => _openStickers(l10n),
    EditorTool.shapes => _openShapes(),
    _ => ref.read(editorProvider.notifier).selectTool(tool),
  };

  /// A tap on a category selects its last tool and, if it holds more,
  /// opens the flyout with them; a second tap closes it (F-20).
  void _tapCategory(ToolCategory category, AppLocalizations l10n) {
    setState(() {
      _widthsOpen = false;
      _flyout = category.hasFlyout && _flyout != category ? category : null;
    });
    _useTool(ref.read(editorProvider).toolOf(category), l10n);
  }

  /// A long press opens the flyout without changing tool.
  void _showFlyout(ToolCategory category) {
    if (!category.hasFlyout) return;
    setState(() {
      _widthsOpen = false;
      _flyout = category;
    });
  }

  void _closeFlyouts() {
    if (_flyout == null && !_widthsOpen) return;
    setState(() {
      _flyout = null;
      _widthsOpen = false;
    });
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
    // The same for the outlines of coloring pages.
    final coloring = ref.watch(coloringArtworkProvider).value;
    if (coloring != null && !identical(_renderer.coloring, coloring)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _renderer.coloring = coloring,
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
      final last = next.drawing?.elements.lastOrNull;
      // A new fill may replace the fills it hides: the count can go down.
      // Undo can bring back an old fill: no sound then.
      if (last is FillElement &&
          !next.canRedo &&
          previous.drawing?.elementById(last.id) == null) {
        feedback.sound(AppSound.pop);
      } else if (after > before && last is StickerElement) {
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

    final orientation = MediaQuery.orientationOf(context);
    if (orientation != _orientation) {
      // The buttons move: a flyout would point at the wrong place.
      _orientation = orientation;
      _flyout = null;
      _widthsOpen = false;
    }

    // The touch that closes a flyout still draws: Listener does not take
    // part in the gesture arena.
    final sheet = Listener(
      onPointerDown: (_) => _closeFlyouts(),
      child: _sheet(l10n, state, controller),
    );

    final tools = [
      for (final category in ToolCategory.values)
        ToolButton(
          key: _categoryKeys[category],
          tool: state.toolOf(category),
          label: toolLabel(l10n, state.toolOf(category)),
          color: state.color,
          selected: state.tool.category == category,
          hasMore: category.hasFlyout,
          onPressed: () => _tapCategory(category, l10n),
          onLongPress: () => _showFlyout(category),
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

    final widthColor = state.tool.usesColor ? state.color : Tokens.graphite;
    WidthButton widthButton(WidthPreset width, {required bool inFlyout}) =>
        WidthButton(
          width: inFlyout ? 80 : 112,
          dotSize: 6.0 + width.index * 9,
          color: widthColor,
          label: widthLabel(l10n, width),
          selected: state.widths[state.tool] == width,
          onPressed: () {
            if (inFlyout) setState(() => _widthsOpen = false);
            controller.selectWidth(width);
          },
        );

    final landscape = orientation == Orientation.landscape;
    Widget body;
    if (landscape) {
      // One column of categories (F-20), centered when it fits.
      final toolColumn = _ScrollColumn(
        width: 84,
        centered: true,
        children: tools,
      );
      final colorColumn = _ScrollColumn(
        width: 124,
        children: [
          Wrap(children: colors),
          const SizedBox(height: 8),
          if (state.tool.usesWidth)
            for (final width in WidthPreset.values)
              widthButton(width, inFlyout: false),
        ],
      );
      body = Row(
        children: settings.leftHanded
            ? [colorColumn, Expanded(child: sheet), toolColumn]
            : [toolColumn, Expanded(child: sheet), colorColumn],
      );
    } else {
      // In portrait the widths fold into one button at the end of the
      // tools, so that the colors keep their own row (F-20).
      final current = state.widths[state.tool]!;
      body = Column(
        children: [
          Expanded(child: sheet),
          _ScrollRow(children: colors),
          _ScrollRow(
            children: [
              ...tools,
              if (state.tool.usesWidth) ...[
                const SizedBox(width: 12),
                WidthButton(
                  key: _widthKey,
                  width: 64,
                  dotSize: 6.0 + current.index * 9,
                  color: widthColor,
                  label: widthLabel(l10n, current),
                  // Highlighted like the current width in landscape, so
                  // that a lone dot still reads as a button.
                  selected: true,
                  onPressed: () => setState(() {
                    _flyout = null;
                    _widthsOpen = !_widthsOpen;
                  }),
                ),
              ],
            ],
          ),
        ],
      );
    }

    // Tools on the left (or right) open their flyout beside them; in
    // portrait the flyouts open above their button.
    final side = !landscape
        ? AxisDirection.up
        : settings.leftHanded
        ? AxisDirection.left
        : AxisDirection.right;
    final flyout = _flyout;
    final flyouts = [
      if (flyout != null)
        _Flyout(
          stackKey: _stackKey,
          anchorKey: _categoryKeys[flyout]!,
          direction: side,
          children: [
            for (final tool in flyout.tools)
              ToolButton(
                tool: tool,
                label: toolLabel(l10n, tool),
                color: state.color,
                selected: tool == state.tool,
                onPressed: () {
                  setState(() => _flyout = null);
                  _useTool(tool, l10n);
                },
              ),
          ],
        ),
      if (_widthsOpen && !landscape && state.tool.usesWidth)
        _Flyout(
          stackKey: _stackKey,
          anchorKey: _widthKey,
          direction: AxisDirection.up,
          children: [
            for (final width in WidthPreset.values)
              widthButton(width, inFlyout: true),
          ],
        ),
    ];

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
    final compact = isCompact(context);
    return PopScope(
      canPop: false,
      // The system back gesture saves too.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            key: _stackKey,
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 72,
                    child: _ActionBar(
                      leading: [
                        ActionButton(
                          icon: const AppIcon(AppIcons.home),
                          tooltip: l10n.backToGallery,
                          onPressed: _leave,
                        ),
                        SizedBox(width: compact ? 4 : 12),
                        ActionButton(
                          icon: const AppIcon(AppIcons.undo),
                          tooltip: l10n.undo,
                          onPressed: state.canUndo ? controller.undo : null,
                        ),
                        ActionButton(
                          icon: const AppIcon(AppIcons.redo),
                          tooltip: l10n.redo,
                          onPressed: state.canRedo ? controller.redo : null,
                        ),
                      ],
                      trailing: [
                        ActionButton(
                          icon: const AppIcon(AppIcons.paper),
                          tooltip: l10n.paper,
                          onPressed: state.drawing == null
                              ? null
                              : () => showPaperPanel(
                                  context,
                                  current: () => ref
                                      .read(editorProvider)
                                      .drawing!
                                      .background,
                                  onChanged: controller.changeBackground,
                                ),
                        ),
                        ActionButton(
                          icon: const AppIcon(AppIcons.lock),
                          tooltip: locked
                              ? l10n.unlockRotation
                              : l10n.lockRotation,
                          active: locked,
                          onPressed: () => _toggleRotationLock(locked),
                        ),
                        ActionButton(
                          icon: const AppIcon(AppIcons.print),
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
                      ],
                    ),
                  ),
                  const Divider(height: 1.5),
                  Expanded(child: body),
                ],
              ),
              ...flyouts,
            ],
          ),
        ),
      ),
    );
  }
}

extension on _EditorPageState {
  /// The sheet, with as much space as the toolbars leave.
  Widget _sheet(
    AppLocalizations l10n,
    EditorState state,
    EditorController controller,
  ) => Padding(
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
          onTap: state.tool == EditorTool.bucket
              ? controller.pourBucket
              : controller.tapSheet,
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
            icon: const AppIcon(AppIcons.duplicate),
            tooltip: l10n.duplicateElement,
            onPressed: controller.duplicateGroup,
          ),
          SelectionAction(
            icon: const AppIcon(AppIcons.delete),
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
          icon: const AppIcon(AppIcons.duplicate),
          tooltip: l10n.duplicateElement,
          onPressed: controller.duplicateSelected,
        ),
        if (selected is TextElement) ...[
          SelectionAction(
            icon: const Icon(Icons.edit_rounded),
            tooltip: l10n.editText,
            onPressed: controller.editSelected,
          ),
          SelectionAction(
            icon: const Icon(Icons.font_download_rounded),
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
          icon: const AppIcon(AppIcons.delete),
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
        icon: const AppIcon(AppIcons.more),
        tooltip: tooltip,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// The editor's top bar: [leading] on the left and [trailing] on the right.
/// On a narrow screen (a phone held upright) it scrolls rather than hiding
/// the last buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.leading, required this.trailing});

  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final edge = isCompact(context) ? 4.0 : 8.0;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: edge),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth - 2 * edge,
            minHeight: constraints.maxHeight,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: leading),
              Row(children: trailing),
            ],
          ),
        ),
      );
    },
  );
}

class _ScrollColumn extends StatelessWidget {
  const _ScrollColumn({
    required this.width,
    required this.children,
    this.centered = false,
  });

  final double width;
  final List<Widget> children;

  /// Whether the children sit in the middle when they fit.
  final bool centered;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: centered ? constraints.maxHeight - 16 : 0,
          ),
          child: Column(
            mainAxisAlignment: centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ),
  );
}

/// A small panel of choices next to the toolbar button it belongs to
/// (F-20), kept on screen.
class _Flyout extends StatelessWidget {
  const _Flyout({
    required this.stackKey,
    required this.anchorKey,
    required this.direction,
    required this.children,
  });

  /// The stack the flyout is drawn in, and the button it points at.
  final GlobalKey stackKey;
  final GlobalKey anchorKey;

  /// Where the flyout opens, seen from the button.
  final AxisDirection direction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // The button was laid out in an earlier frame: the flyout only opens
    // after a touch on it.
    final stack = stackKey.currentContext?.findRenderObject() as RenderBox?;
    final anchor = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || anchor == null || !anchor.attached) {
      return const SizedBox.shrink();
    }
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: stack);
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _FlyoutLayout(topLeft & anchor.size, direction),
        child: Material(
          color: Tokens.sheet,
          elevation: 6,
          shadowColor: Tokens.ink.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Tokens.border, width: 2),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(6),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _FlyoutLayout extends SingleChildLayoutDelegate {
  _FlyoutLayout(this.anchor, this.direction);

  final Rect anchor;
  final AxisDirection direction;

  static const double _gap = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(constraints.maxWidth - 2 * _gap, constraints.maxHeight - 2 * _gap),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final position = switch (direction) {
      AxisDirection.right => Offset(
        anchor.right + _gap,
        anchor.center.dy - child.height / 2,
      ),
      AxisDirection.left => Offset(
        anchor.left - _gap - child.width,
        anchor.center.dy - child.height / 2,
      ),
      AxisDirection.up => Offset(
        anchor.center.dx - child.width / 2,
        anchor.top - _gap - child.height,
      ),
      AxisDirection.down => Offset(
        anchor.center.dx - child.width / 2,
        anchor.bottom + _gap,
      ),
    };
    return Offset(
      position.dx.clamp(_gap, size.width - child.width - _gap),
      position.dy.clamp(_gap, size.height - child.height - _gap),
    );
  }

  @override
  bool shouldRelayout(_FlyoutLayout oldDelegate) =>
      anchor != oldDelegate.anchor || direction != oldDelegate.direction;
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
