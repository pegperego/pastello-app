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

/// What the editor shows. Immutable; the controller emits a new one for
/// every change.
@immutable
class EditorState {
  const EditorState({
    required this.tool,
    required this.color,
    required this.widths,
    this.extraColor,
    this.drawing,
    this.canUndo = false,
    this.canRedo = false,
    this.revision = 0,
    this.lastErasure,
    this.loading = false,
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

  /// Width of the active tool, in sheet units.
  double get width => widths[tool]!.width;

  EditorState copyWith({
    EditorTool? tool,
    Color? color,
    Map<EditorTool, WidthPreset>? widths,
    Color? extraColor,
  }) => EditorState(
    tool: tool ?? this.tool,
    color: color ?? this.color,
    widths: widths ?? this.widths,
    extraColor: extraColor ?? this.extraColor,
    drawing: drawing,
    canUndo: canUndo,
    canRedo: canRedo,
    revision: revision,
    lastErasure: lastErasure,
    loading: loading,
  );
}

/// The editor's state: a fresh one for every editor opened.
final editorProvider =
    NotifierProvider.autoDispose<EditorController, EditorState>(
      EditorController.new,
    );

/// Drives the editor: tool, color and width choices (remembered in the
/// settings), the undoable drawing commands and autosave.
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

  /// Makes sure there is a sheet for the [available] space.
  ///
  /// The sheet takes the shape of the screen and keeps it once something is
  /// drawn (D-05). While it is empty, and there is nothing to undo, it
  /// follows the screen: on Android the first frames may be laid out in
  /// portrait before the device rotates.
  void ensureSheet(Size available) {
    if (available.isEmpty || _loading) return;
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
    state = EditorState(
      tool: state.tool,
      color: state.color,
      widths: state.widths,
      extraColor: state.extraColor,
      loading: true,
    );
    final saved = await ref.read(drawingRepositoryProvider).load(id);
    _loading = false;
    if (!ref.mounted) return;
    if (saved == null) {
      _publishLoaded();
      return;
    }
    _drawingId = id;
    _onDisk = true;
    _stack = CommandStack(saved.drawing)
      ..restore(saved.drawing, saved.undo, saved.redo);
    _publish(changed: false);
  }

  void _publishLoaded() {
    state = EditorState(
      tool: state.tool,
      color: state.color,
      widths: state.widths,
      extraColor: state.extraColor,
    );
  }

  /// Saves now if there are unsaved changes. Called when leaving the editor
  /// and when the app goes to the background.
  Future<void> flush() {
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

  /// Selects [tool].
  void selectTool(EditorTool tool) {
    state = state.copyWith(tool: tool);
    _saveSettings((s) => s.copyWith(tool: tool.name));
  }

  /// Selects [color]. A color outside the fixed 12 becomes the "extra"
  /// swatch.
  void selectColor(Color color) {
    final isExtra = !drawingColors.contains(color);
    state = state.copyWith(color: color, extraColor: isExtra ? color : null);
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

  /// Commits a finished stroke (or eraser pass) drawn through [points].
  void commitStroke(List<SheetPoint> points) {
    final stack = _stack;
    if (stack == null || points.isEmpty) return;
    final simplified = simplify(points, _simplifyTolerance);
    final strokeTool = state.tool.strokeTool;
    if (strokeTool == null) {
      final command = EraseCommand.forDrawing(
        stack.drawing,
        simplified,
        state.width,
      );
      if (command == null) return;
      stack.execute(command);
      _publish(erasure: command.erasure);
      return;
    }
    stack.execute(
      AddStrokeCommand(
        StrokeElement(
          id: newElementId(),
          tool: strokeTool,
          color: state.color,
          width: state.width,
          points: simplified,
        ),
      ),
    );
    _publish();
  }

  /// Undoes the last change.
  void undo() {
    if (_stack?.undo() ?? false) _publish();
  }

  /// Redoes the last undone change.
  void redo() {
    if (_stack?.redo() ?? false) _publish();
  }

  /// Clears the sheet (undoable).
  void clear() {
    final stack = _stack;
    if (stack == null || stack.drawing.isEmpty) return;
    stack.execute(ClearCommand(stack.drawing.elements));
    _publish();
  }

  void _publish({Erasure? erasure, bool changed = true}) {
    final stack = _stack!;
    if (changed) {
      _dirty = true;
      _autosave?.cancel();
      _autosave = Timer(autosaveDelay, flush);
    }
    state = EditorState(
      tool: state.tool,
      color: state.color,
      widths: state.widths,
      extraColor: state.extraColor,
      drawing: stack.drawing,
      canUndo: stack.canUndo,
      canRedo: stack.canRedo,
      revision: state.revision + 1,
      lastErasure: erasure,
    );
  }

  void _saveSettings(AppSettings Function(AppSettings) change) {
    ref.read(settingsProvider.notifier).change(change);
  }
}
