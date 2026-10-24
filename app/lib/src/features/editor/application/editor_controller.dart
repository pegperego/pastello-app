import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pastello_engine/pastello_engine.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../drawings/application/drawings_providers.dart';
import '../domain/editor_tool.dart';
import '../domain/palette.dart';

/// Points closer than this to the simplified line are dropped when a stroke
/// ends (sheet units, ADR 0005).
const double _simplifyTolerance = 0.35;

/// Autosave delay after the last change (ADR 0010).
const autosaveDelay = Duration(milliseconds: 1500);

/// How far, in sheet units, a touch may land from an element and still
/// select it: fingers are not precise.
const double selectionSlop = 16;

/// Scale limits for texts and other elements.
const double minElementScale = 0.3;
const double maxElementScale = 8;

/// Marks a field left unchanged by [EditorState.copyWith].
const Object _keep = Object();

/// The sticker placed by the next tap with the Stickers tool (F-11).
@immutable
class StickerChoice {
  const StickerChoice(this.packId, this.itemId);

  final String packId;
  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is StickerChoice &&
      other.packId == packId &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(packId, itemId);
}

/// Offset of a duplicated element from the original, in sheet units.
const Offset duplicateOffset = Offset(28, 28);

/// Below this size, in sheet units, a drag does not create a shape.
const double minShapeSize = 8;

/// What the editor shows. Immutable; the controller emits a new one for
/// every change.
@immutable
class EditorState {
  const EditorState({
    required this.tool,
    required this.color,
    required this.widths,
    this.extraColor,
    this.textFont = TextFont.andika,
    this.sticker,
    this.shapeKind = ShapeKind.ellipse,
    this.shapeFilled = false,
    this.draft,
    this.shapeSnapped = false,
    this.groupIds = const [],
    this.groupBox,
    this.groupFrame,
    this.groupPreview = const [],
    this.lasso,
    this.drawing,
    this.canUndo = false,
    this.canRedo = false,
    this.revision = 0,
    this.lastErasure,
    this.loading = false,
    this.selectedId,
    this.editing,
    this.editingIsNew = false,
    this.preview,
  });

  /// Active tool.
  final EditorTool tool;

  /// Active drawing color.
  final Color color;

  /// Width preset of each tool (F-06).
  final Map<EditorTool, WidthPreset> widths;

  /// Last color picked from the "more colors" grid, shown next to the
  /// fixed ones (F-05).
  final Color? extraColor;

  /// Font of the next new text (F-08).
  final TextFont textFont;

  /// Sticker placed by the next tap with the Stickers tool.
  final StickerChoice? sticker;

  /// Shape drawn by the next drag with the Shapes tool (F-12).
  final ShapeKind shapeKind;

  /// Whether new shapes are filled.
  final bool shapeFilled;

  /// The shape being drawn by a finger, not yet in the drawing.
  final ShapeElement? draft;

  /// Whether [draft] snapped to a perfect figure or angle.
  final bool shapeSnapped;

  /// Elements selected together with the lasso (F-13), in z-order. Empty
  /// when there is no group; a single element uses [selectedId] instead.
  final List<String> groupIds;

  /// Bounds of the group when it was selected or last changed.
  final Rect? groupBox;

  /// Current transform of the group's frame: starts at the center of
  /// [groupBox] and follows the finger.
  final ElementTransform? groupFrame;

  /// The group's elements as they look while a finger moves them.
  final List<DrawingElement> groupPreview;

  /// The lasso being drawn, in sheet coordinates.
  final List<Offset>? lasso;

  /// The drawing, or `null` until the sheet size is known.
  final Drawing? drawing;

  /// Whether undo would do something.
  final bool canUndo;

  /// Whether redo would do something.
  final bool canRedo;

  /// Increases every time [drawing] changes.
  final int revision;

  /// Set when the last change was an eraser pass, so the renderer can update
  /// its cache incrementally.
  final Erasure? lastErasure;

  /// Whether a saved drawing is being loaded.
  final bool loading;

  /// The selected element, if any.
  final String? selectedId;

  /// The text being typed, as it currently looks.
  final TextElement? editing;

  /// Whether [editing] is a new text, not yet in the drawing.
  final bool editingIsNew;

  /// The selected element while a finger moves, resizes or rotates it.
  final DrawingElement? preview;

  /// Width of the active tool, in sheet units.
  double get width => widths[tool]!.width;

  /// The selected element, as currently shown (with the live preview).
  DrawingElement? get selected {
    final id = selectedId;
    if (id == null) return null;
    if (preview?.id == id) return preview;
    if (editing?.id == id) return editing;
    return drawing?.elementById(id);
  }

  /// Elements painted on top of the drawing, outside the cache.
  List<DrawingElement> get floating => [
    ?editing,
    ?preview,
    ?draft,
    ...groupPreview,
  ];

  EditorState copyWith({
    EditorTool? tool,
    Color? color,
    Map<EditorTool, WidthPreset>? widths,
    Color? extraColor,
    TextFont? textFont,
    StickerChoice? sticker,
    ShapeKind? shapeKind,
    bool? shapeFilled,
    Object? draft = _keep,
    bool? shapeSnapped,
    List<String>? groupIds,
    Object? groupBox = _keep,
    Object? groupFrame = _keep,
    List<DrawingElement>? groupPreview,
    Object? lasso = _keep,
    Object? selectedId = _keep,
    Object? editing = _keep,
    bool? editingIsNew,
    Object? preview = _keep,
  }) => EditorState(
    tool: tool ?? this.tool,
    color: color ?? this.color,
    widths: widths ?? this.widths,
    extraColor: extraColor ?? this.extraColor,
    textFont: textFont ?? this.textFont,
    sticker: sticker ?? this.sticker,
    shapeKind: shapeKind ?? this.shapeKind,
    shapeFilled: shapeFilled ?? this.shapeFilled,
    draft: identical(draft, _keep) ? this.draft : draft as ShapeElement?,
    shapeSnapped: shapeSnapped ?? this.shapeSnapped,
    groupIds: groupIds ?? this.groupIds,
    groupBox: identical(groupBox, _keep) ? this.groupBox : groupBox as Rect?,
    groupFrame: identical(groupFrame, _keep)
        ? this.groupFrame
        : groupFrame as ElementTransform?,
    groupPreview: groupPreview ?? this.groupPreview,
    lasso: identical(lasso, _keep) ? this.lasso : lasso as List<Offset>?,
    drawing: drawing,
    canUndo: canUndo,
    canRedo: canRedo,
    revision: revision,
    lastErasure: lastErasure,
    loading: loading,
    selectedId: identical(selectedId, _keep)
        ? this.selectedId
        : selectedId as String?,
    editing: identical(editing, _keep) ? this.editing : editing as TextElement?,
    editingIsNew: editingIsNew ?? this.editingIsNew,
    preview: identical(preview, _keep)
        ? this.preview
        : preview as DrawingElement?,
  );
}

/// The editor's state: a fresh one for every editor opened.
final editorProvider =
    NotifierProvider.autoDispose<EditorController, EditorState>(
      EditorController.new,
    );

/// Drives the editor: tool, color and width choices (remembered in the
/// settings), the undoable drawing commands, texts and autosave.
class EditorController extends Notifier<EditorState> {
  CommandStack? _stack;

  /// Id of the drawing; a new drawing gets one right away, but is only
  /// written once something has been drawn (F-01).
  String _drawingId = newElementId();
  bool _onDisk = false;
  bool _loading = false;
  bool _dirty = false;
  Timer? _autosave;
  Future<void> _saving = Future.value();

  /// Id of the drawing being edited.
  String get drawingId => _drawingId;

  @override
  EditorState build() {
    ref.onDispose(() => _autosave?.cancel());
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final tool = EditorTool.values
        .where((t) => t.name == settings.tool)
        .firstOrNull;
    return EditorState(
      tool: tool ?? EditorTool.crayon,
      color: settings.color != null
          ? Color(settings.color!)
          : drawingColors.first,
      extraColor: settings.extraColor != null
          ? Color(settings.extraColor!)
          : null,
      widths: {
        for (final t in EditorTool.values)
          t:
              WidthPreset.values
                  .where((w) => w.name == settings.widths[t.name])
                  .firstOrNull ??
              t.defaultWidth,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sheet, loading and saving

  /// Makes sure there is a sheet for the [available] space.
  ///
  /// The sheet takes the shape of the screen and keeps it once something is
  /// drawn (D-05). While it is empty, and there is nothing to undo, it
  /// follows the screen: on Android the first frames may be laid out in
  /// portrait before the device rotates.
  void ensureSheet(Size available) {
    if (available.isEmpty || _loading || state.editing != null) return;
    final stack = _stack;
    if (stack != null &&
        (!stack.drawing.isEmpty ||
            stack.canUndo ||
            stack.canRedo ||
            stack.drawing.sheetSize == available)) {
      return;
    }
    _stack = CommandStack(Drawing(sheetSize: available));
    _publish(changed: false);
  }

  /// Opens the saved drawing [id], with its undo history (ADR 0007).
  ///
  /// If it cannot be read, the editor starts with a new drawing instead.
  Future<void> open(String id) async {
    _loading = true;
    state = _fresh(loading: true);
    final saved = await ref.read(drawingRepositoryProvider).load(id);
    _loading = false;
    if (!ref.mounted) return;
    if (saved == null) {
      state = _fresh();
      return;
    }
    _drawingId = id;
    _onDisk = true;
    _stack = CommandStack(saved.drawing)
      ..restore(saved.drawing, saved.undo, saved.redo);
    _publish(changed: false);
  }

  /// The current choices, without any drawing.
  EditorState _fresh({bool loading = false}) => EditorState(
    tool: state.tool,
    color: state.color,
    widths: state.widths,
    extraColor: state.extraColor,
    textFont: state.textFont,
    sticker: state.sticker,
    shapeKind: state.shapeKind,
    shapeFilled: state.shapeFilled,
    loading: loading,
  );

  /// Saves now if there are unsaved changes. Called when leaving the editor
  /// and when the app goes to the background. A text being typed is
  /// committed first.
  Future<void> flush() {
    commitText();
    _autosave?.cancel();
    _autosave = null;
    if (_dirty) {
      _dirty = false;
      _saving = _saving.then((_) => _save()).catchError((Object _) {
        // Keep the changes pending: the next autosave tries again.
        _dirty = true;
      });
    }
    return _saving;
  }

  Future<void> _save() async {
    final stack = _stack;
    if (stack == null) return;
    // A sheet that never had anything on it is not worth keeping (F-01).
    if (!_onDisk && stack.drawing.isEmpty && !stack.canUndo) return;
    final drawing = stack.drawing;
    final thumbnail = await ref.read(thumbnailRendererProvider)(drawing);
    await ref
        .read(drawingRepositoryProvider)
        .save(
          _drawingId,
          drawing,
          undo: stack.undoCommands,
          redo: stack.redoCommands,
          thumbnail: thumbnail,
        );
    _onDisk = true;
  }

  // ---------------------------------------------------------------------------
  // Tools, colors and widths

  /// Selects [tool]. Leaving the text tool ends the text editing and the
  /// selection.
  void selectTool(EditorTool tool) {
    if (!tool.selects || tool != state.tool) {
      commitText();
      state = _withoutGroup().copyWith(selectedId: null, lasso: null);
    }
    state = state.copyWith(tool: tool);
    _saveSettings((s) => s.copyWith(tool: tool.name));
  }

  /// Selects [color]. A color outside the fixed 12 becomes the "extra"
  /// swatch. The selected text, if any, takes the color too.
  void selectColor(Color color) {
    final isExtra = !drawingColors.contains(color);
    state = state.copyWith(color: color, extraColor: isExtra ? color : null);
    _restyleSelected((t) => t.copyWith(color: color));
    _recolorSelectedShape(color);
    _saveSettings(
      (s) => s.copyWith(
        color: color.toARGB32(),
        extraColor: isExtra ? color.toARGB32() : null,
      ),
    );
  }

  /// Sets the width of the active tool; the selected shape takes it too.
  void selectWidth(WidthPreset width) {
    final widths = {...state.widths, state.tool: width};
    state = state.copyWith(widths: widths);
    final selected = state.selected;
    if (state.tool == EditorTool.shapes && selected is ShapeElement) {
      _execute(
        UpdateElementCommand(
          selected,
          selected.copyWith(strokeWidth: width.width),
        ),
      );
    }
    _saveSettings(
      (s) => s.copyWith(
        widths: {
          for (final MapEntry(:key, :value) in widths.entries)
            key.name: value.name,
        },
      ),
    );
  }

  /// Sets the font of the selected text and of the next new ones (F-08).
  void selectFont(TextFont font) {
    state = state.copyWith(textFont: font);
    _restyleSelected((t) => t.copyWith(font: font));
  }

  /// Applies [change] to the text being edited or selected.
  void _restyleSelected(TextElement Function(TextElement) change) {
    final editing = state.editing;
    if (editing != null) {
      state = state.copyWith(editing: change(editing));
      return;
    }
    final selected = state.selected;
    if (selected is TextElement) {
      _execute(UpdateElementCommand(selected, change(selected)));
    }
  }

  /// Gives the selected shape [color] (colors only apply to texts and
  /// shapes; stickers keep their own).
  void _recolorSelectedShape(Color color) {
    final selected = state.selected;
    if (selected is ShapeElement && state.editing == null) {
      _execute(UpdateElementCommand(selected, selected.copyWith(color: color)));
    }
  }

  // ---------------------------------------------------------------------------
  // Shapes (F-12)

  Offset? _shapeStart;

  /// Chooses the shape drawn by the next drag, and whether it is filled.
  void chooseShape(ShapeKind kind, {required bool filled}) {
    state = state.copyWith(
      shapeKind: kind,
      shapeFilled: filled,
      selectedId: null,
    );
  }

  /// A finger starts drawing a shape at [point].
  void beginShape(Offset point) {
    if (state.tool != EditorTool.shapes || state.drawing == null) return;
    _shapeStart = point;
  }

  /// The finger moved to [point]: the shape follows it.
  void updateShape(Offset point) {
    final start = _shapeStart;
    if (start == null) return;
    final (shape, snapped) = shapeFromDrag(
      id: state.draft?.id ?? newElementId(),
      kind: state.shapeKind,
      start: start,
      end: point,
      color: state.color,
      strokeWidth: state.width,
      filled: state.shapeFilled,
    );
    state = state.copyWith(
      draft: shape,
      shapeSnapped: snapped,
      selectedId: null,
    );
    _show();
  }

  /// The finger lifts: the shape is added and selected, unless it is too
  /// small to be a shape.
  void endShape() {
    final draft = state.draft;
    _shapeStart = null;
    state = state.copyWith(draft: null, shapeSnapped: false);
    if (draft == null || draft.extent.distance < minShapeSize) {
      _show();
      return;
    }
    state = state.copyWith(selectedId: draft.id);
    _execute(AddElementCommand(draft));
  }

  // ---------------------------------------------------------------------------
  // Strokes

  /// Commits a finished stroke (or eraser pass) drawn through [points].
  void commitStroke(List<SheetPoint> points) {
    final stack = _stack;
    if (stack == null || points.isEmpty) return;
    final simplified = simplify(points, _simplifyTolerance);
    final strokeTool = state.tool.strokeTool;
    if (strokeTool == null) {
      if (state.tool != EditorTool.eraser) return;
      final command = EraseCommand.forDrawing(
        stack.drawing,
        simplified,
        state.width,
      );
      if (command == null) return;
      stack.execute(command);
      _publish(erasure: command.sheetErasure);
      return;
    }
    _execute(
      AddElementCommand(
        StrokeElement(
          id: newElementId(),
          tool: strokeTool,
          color: state.color,
          width: state.width,
          points: simplified,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Texts and selection (F-07)

  /// A tap on the sheet with a tool that selects: selects the text or
  /// sticker under the finger, otherwise deselects, starts a new text or
  /// places the chosen sticker there.
  void tapSheet(Offset point) {
    final drawing = state.drawing;
    if (drawing == null || !state.tool.selects) return;
    if (state.editing != null) {
      commitText();
      return;
    }
    // Strokes are only selectable with the Select tool (ADR 0004).
    final hit = drawing.elementAt(
      point,
      slop: selectionSlop,
      where: (e) => state.tool == EditorTool.select || e is! StrokeElement,
    );
    if (hit != null) {
      state = _withoutGroup().copyWith(selectedId: hit.id);
    } else if (state.selectedId != null || state.groupIds.isNotEmpty) {
      state = _withoutGroup().copyWith(selectedId: null);
    } else if (state.tool == EditorTool.text) {
      startText(point);
    } else if (state.tool == EditorTool.stickers) {
      placeSticker(point);
    }
  }

  // ---------------------------------------------------------------------------
  // Lasso and groups (F-13)

  EditorState _withoutGroup() => state.copyWith(
    groupIds: const [],
    groupBox: null,
    groupFrame: null,
    groupPreview: const [],
  );

  /// Starts a lasso at [point].
  void beginLasso(Offset point) {
    if (state.tool != EditorTool.select || state.drawing == null) return;
    state = _withoutGroup().copyWith(selectedId: null, lasso: [point]);
  }

  /// Extends the lasso to [point].
  void updateLasso(Offset point) {
    final lasso = state.lasso;
    if (lasso == null) return;
    state = state.copyWith(lasso: [...lasso, point]);
  }

  /// Closes the lasso and selects what it caught: one element, or a group.
  void endLasso() {
    final lasso = state.lasso;
    final drawing = state.drawing;
    state = state.copyWith(lasso: null);
    if (lasso == null || drawing == null) return;
    final ids = lassoSelection(drawing, lasso);
    if (ids.length == 1) {
      state = state.copyWith(selectedId: ids.single);
    } else if (ids.length > 1) {
      _selectGroup(drawing, ids);
    }
  }

  void _selectGroup(Drawing drawing, List<String> ids) {
    final box = groupBounds([for (final id in ids) drawing.elementById(id)!]);
    state = state.copyWith(
      selectedId: null,
      groupIds: ids,
      groupBox: box,
      groupFrame: ElementTransform(translation: box.center),
      groupPreview: const [],
    );
  }

  List<DrawingElement> get _groupElements => [
    for (final id in state.groupIds) ?state.drawing?.elementById(id),
  ];

  /// Shows the group moved, resized or rotated while a finger is on its
  /// frame.
  void previewGroup(ElementTransform frame) {
    final box = state.groupBox;
    if (box == null) return;
    final clamped = frame.copyWith(
      scale: frame.scale.clamp(minElementScale, maxElementScale),
    );
    final g = groupTransform(box, clamped);
    state = state.copyWith(
      groupFrame: clamped,
      groupPreview: [
        for (final e in _groupElements) e.withTransform(e.transform.then(g)),
      ],
    );
    _show();
  }

  /// Commits the group's new position as one undo step.
  void commitGroup() {
    final moved = state.groupPreview;
    if (moved.isEmpty) return;
    final before = _groupElements;
    final ids = state.groupIds;
    state = state.copyWith(groupPreview: const []);
    _execute(
      BatchCommand([
        for (var i = 0; i < before.length; i++)
          UpdateElementCommand(before[i], moved[i]),
      ]),
    );
    _selectGroup(state.drawing!, ids);
  }

  /// Duplicates the group, a little lower and to the right, and selects
  /// the copies.
  void duplicateGroup() {
    final copies = [
      for (final e in _groupElements)
        e
            .withId(newElementId())
            .withTransform(
              e.transform.then(
                const ElementTransform(translation: duplicateOffset),
              ),
            ),
    ];
    if (copies.isEmpty) return;
    _execute(BatchCommand([for (final c in copies) AddElementCommand(c)]));
    _selectGroup(state.drawing!, [for (final c in copies) c.id]);
  }

  /// Deletes the whole group as one undo step.
  void deleteGroup() {
    final drawing = state.drawing;
    if (drawing == null || state.groupIds.isEmpty) return;
    final command = BatchCommand.deleteAll(drawing, state.groupIds);
    state = _withoutGroup();
    _execute(command);
  }

  /// Chooses the sticker placed by the next tap (F-11).
  void chooseSticker(StickerChoice choice) {
    state = state.copyWith(sticker: choice, selectedId: null);
  }

  /// Places the chosen sticker centered on [point] and selects it.
  void placeSticker(Offset point) {
    final choice = state.sticker;
    if (choice == null || _stack == null) return;
    final sticker = StickerElement(
      id: newElementId(),
      packId: choice.packId,
      elementId: choice.itemId,
      transform: ElementTransform(translation: point),
    );
    state = state.copyWith(selectedId: sticker.id);
    _execute(AddElementCommand(sticker));
  }

  /// Duplicates the selected element, a little lower and to the right, and
  /// selects the copy.
  void duplicateSelected() {
    final selected = state.selected;
    if (selected == null || state.editing != null || _stack == null) return;
    final t = selected.transform;
    final copy = selected
        .withId(newElementId())
        .withTransform(
          t.copyWith(translation: t.translation + duplicateOffset),
        );
    state = state.copyWith(selectedId: copy.id);
    _execute(AddElementCommand(copy));
  }

  /// Starts typing a new text centered on [point].
  void startText(Offset point) {
    final text = TextElement(
      id: newElementId(),
      text: '',
      color: state.color,
      font: state.textFont,
      transform: ElementTransform(translation: point),
    );
    state = state.copyWith(
      editing: text,
      editingIsNew: true,
      selectedId: text.id,
    );
    _show();
  }

  /// Starts editing the selected text.
  void editSelected() {
    final selected = state.selected;
    if (selected is! TextElement) return;
    state = state.copyWith(editing: selected, editingIsNew: false);
    _show();
  }

  /// Updates the text being typed; the sheet shows it live.
  void updateText(String text) {
    final editing = state.editing;
    if (editing == null) return;
    state = state.copyWith(editing: editing.copyWith(text: text));
    _show();
  }

  /// Ends the text editing: adds the new text, saves the changes, or deletes
  /// a text that was emptied.
  void commitText() {
    final editing = state.editing;
    if (editing == null) return;
    final existing = state.drawing?.elementById(editing.id);
    final isEmpty = editing.text.trim().isEmpty;
    state = state.copyWith(
      editing: null,
      editingIsNew: false,
      selectedId: isEmpty ? null : editing.id,
    );
    if (existing == null) {
      if (isEmpty) {
        _show();
      } else {
        _execute(AddElementCommand(editing));
      }
    } else if (isEmpty) {
      _execute(DeleteElementCommand.forDrawing(_stack!.drawing, editing.id)!);
    } else if (!identical(existing, editing)) {
      _execute(UpdateElementCommand(existing, editing));
    } else {
      _show();
    }
  }

  /// Shows the selected element moved, resized or rotated, while a finger
  /// is still on it.
  void previewTransform(ElementTransform transform) {
    final selected = state.drawing?.elementById(state.selectedId ?? '');
    if (selected == null) return;
    state = state.copyWith(
      preview: selected.withTransform(
        transform.copyWith(
          scale: transform.scale.clamp(minElementScale, maxElementScale),
        ),
      ),
    );
    _show();
  }

  /// Commits the transform previewed with [previewTransform] (one undo step
  /// for the whole gesture, ADR 0007).
  void commitTransform() {
    final preview = state.preview;
    if (preview == null) return;
    final before = state.drawing!.elementById(preview.id)!;
    state = state.copyWith(preview: null);
    if (before.transform == preview.transform) {
      _show();
    } else {
      _execute(UpdateElementCommand(before, preview));
    }
  }

  /// Deletes the selected element.
  void deleteSelected() {
    final id = state.selectedId;
    final stack = _stack;
    if (id == null || stack == null) return;
    state = state.copyWith(selectedId: null, editing: null, preview: null);
    final command = DeleteElementCommand.forDrawing(stack.drawing, id);
    if (command == null) {
      _show();
    } else {
      _execute(command);
    }
  }

  /// Clears the selection.
  void deselect() {
    commitText();
    state = _withoutGroup().copyWith(selectedId: null);
  }

  // ---------------------------------------------------------------------------
  // History

  /// Undoes the last change.
  void undo() {
    commitText();
    if (_stack?.undo() ?? false) _publish(keepSelection: false);
  }

  /// Redoes the last undone change.
  void redo() {
    commitText();
    if (_stack?.redo() ?? false) _publish(keepSelection: false);
  }

  /// Clears the sheet (undoable).
  void clear() {
    commitText();
    final stack = _stack;
    if (stack == null || stack.drawing.isEmpty) return;
    _execute(ClearCommand(stack.drawing.elements), keepSelection: false);
  }

  void _execute(DrawingCommand command, {bool keepSelection = true}) {
    _stack!.execute(command);
    _publish(keepSelection: keepSelection);
  }

  /// Repaints the floating elements without changing the drawing.
  void _show() {
    state = state.copyWith();
  }

  void _publish({
    Erasure? erasure,
    bool changed = true,
    bool keepSelection = true,
  }) {
    final stack = _stack!;
    if (changed) {
      _dirty = true;
      _autosave?.cancel();
      _autosave = Timer(autosaveDelay, flush);
    }
    final selectedId = state.selectedId;
    state = EditorState(
      tool: state.tool,
      color: state.color,
      widths: state.widths,
      extraColor: state.extraColor,
      textFont: state.textFont,
      sticker: state.sticker,
      shapeKind: state.shapeKind,
      shapeFilled: state.shapeFilled,
      drawing: stack.drawing,
      canUndo: stack.canUndo,
      canRedo: stack.canRedo,
      revision: state.revision + 1,
      lastErasure: erasure,
      selectedId:
          keepSelection &&
              selectedId != null &&
              stack.drawing.elementById(selectedId) != null
          ? selectedId
          : null,
      editing: state.editing,
      editingIsNew: state.editingIsNew,
      preview: state.preview,
      draft: state.draft,
      groupIds: keepSelection
          ? [
              for (final id in state.groupIds)
                if (stack.drawing.elementById(id) != null) id,
            ]
          : const [],
      groupBox: keepSelection ? state.groupBox : null,
      groupFrame: keepSelection ? state.groupFrame : null,
      groupPreview: state.groupPreview,
    );
  }

  void _saveSettings(AppSettings Function(AppSettings) change) {
    unawaited(ref.read(settingsProvider.notifier).change(change));
  }
}
