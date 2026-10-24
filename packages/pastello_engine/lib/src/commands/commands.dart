import '../document/drawing.dart';
import '../document/sheet_point.dart';
import '../document/stroke_element.dart';
import '../geometry/hit_test.dart';

/// A reversible change to a [Drawing] (ADR 0007).
///
/// Commands never mutate a drawing: [apply] and [revert] return new ones.
abstract interface class DrawingCommand {
  /// Returns [drawing] with this change applied.
  Drawing apply(Drawing drawing);

  /// Returns [drawing] with this change undone.
  Drawing revert(Drawing drawing);
}

/// Adds a stroke on top of the drawing.
class AddStrokeCommand implements DrawingCommand {
  /// Creates a command that adds [stroke].
  const AddStrokeCommand(this.stroke);

  /// The stroke to add.
  final StrokeElement stroke;

  @override
  Drawing apply(Drawing drawing) => drawing.withElementAdded(stroke);

  @override
  Drawing revert(Drawing drawing) => drawing.withElementRemoved(stroke.id);
}

/// Attaches an eraser pass to every stroke it touches (ADR 0006).
class EraseCommand implements DrawingCommand {
  /// Creates an erase command for the strokes listed in [strokeIds].
  ///
  /// Use [EraseCommand.forDrawing] to compute the affected strokes.
  const EraseCommand(this.erasure, this.strokeIds);

  /// Creates an erase command for the strokes of [drawing] touched by the
  /// eraser path [points] of the given [width].
  ///
  /// Returns `null` when the eraser touches nothing, so that empty passes do
  /// not pollute the undo history.
  static EraseCommand? forDrawing(
    Drawing drawing,
    List<SheetPoint> points,
    double width,
  ) {
    final ids = <String>{
      for (final e in drawing.elements)
        if (eraserTouchesStroke(points, width, e)) e.id,
    };
    if (ids.isEmpty) return null;
    return EraseCommand(Erasure(points: points, width: width), ids);
  }

  /// The eraser pass.
  final Erasure erasure;

  /// Ids of the strokes the pass is attached to.
  final Set<String> strokeIds;

  @override
  Drawing apply(Drawing drawing) => drawing.withElementsMapped(
    (e) => strokeIds.contains(e.id) ? e.withErasure(erasure) : e,
  );

  @override
  Drawing revert(Drawing drawing) => drawing.withElementsMapped(
    (e) => strokeIds.contains(e.id) ? e.withoutErasure(erasure) : e,
  );
}

/// Removes every element ("Clear sheet"). Undoable, like everything else.
class ClearCommand implements DrawingCommand {
  /// Creates a command that clears [removed] from the drawing.
  const ClearCommand(this.removed);

  /// The elements that were on the sheet before clearing.
  final List<StrokeElement> removed;

  @override
  Drawing apply(Drawing drawing) => drawing.withElements(const []);

  @override
  Drawing revert(Drawing drawing) => drawing.withElements(removed);
}

/// Undo and redo stacks for a drawing.
class CommandStack {
  /// Creates a stack starting from [initial], keeping at most [limit] steps.
  CommandStack(Drawing initial, {this.limit = 100}) : _drawing = initial;

  /// Maximum number of undo steps (ADR 0007).
  final int limit;

  Drawing _drawing;
  final List<DrawingCommand> _undo = [];
  final List<DrawingCommand> _redo = [];

  /// The current drawing.
  Drawing get drawing => _drawing;

  /// Whether [undo] would do something.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether [redo] would do something.
  bool get canRedo => _redo.isNotEmpty;

  /// Applies [command] and records it. Clears the redo stack.
  void execute(DrawingCommand command) {
    _drawing = command.apply(_drawing);
    _undo.add(command);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  /// Undoes the last command. Returns false if there was nothing to undo.
  bool undo() {
    if (_undo.isEmpty) return false;
    final command = _undo.removeLast();
    _drawing = command.revert(_drawing);
    _redo.add(command);
    return true;
  }

  /// Redoes the last undone command. Returns false if there was nothing.
  bool redo() {
    if (_redo.isEmpty) return false;
    final command = _redo.removeLast();
    _drawing = command.apply(_drawing);
    _undo.add(command);
    return true;
  }
}
