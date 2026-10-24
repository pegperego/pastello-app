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
  List<DrawingElement> get floating => [?editing, ?preview];

  EditorState copyWith({
    EditorTool? tool,
    Color? color,
    Map<EditorTool, WidthPreset>? widths,
    Color? extraColor,
    TextFont? textFont,
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
    if (!tool.selects) {
      commitText();
      state = state.copyWith(selectedId: null);
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
    _saveSettings(
      (s) => s.copyWith(
        color: color.toARGB32(),
        extraColor: isExtra ? color.toARGB32() : null,
      ),
    );
  }

  /// Sets the width of the active tool.
  void selectWidth(WidthPreset width) {
    final widths = {...state.widths, state.tool: width};
    state = state.copyWith(widths: widths);
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

  /// A tap on the sheet with a tool that selects: selects the text under the
  /// finger, otherwise deselects or starts a new text there.
  void tapSheet(Offset point) {
    final drawing = state.drawing;
    if (drawing == null || !state.tool.selects) return;
    if (state.editing != null) {
      commitText();
      return;
    }
    final hit = drawing.elementAt(
      point,
      slop: selectionSlop,
      where: (e) => e is TextElement,
    );
    if (hit != null) {
      state = state.copyWith(selectedId: hit.id);
    } else if (state.selectedId != null) {
      state = state.copyWith(selectedId: null);
    } else {
      startText(point);
    }
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
    state = state.copyWith(selectedId: null);
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
    );
  }

  void _saveSettings(AppSettings Function(AppSettings) change) {
    unawaited(ref.read(settingsProvider.notifier).change(change));
  }
}
