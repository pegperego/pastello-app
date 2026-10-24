import 'dart:ui';

import '../document/drawing.dart';
import '../document/drawing_element.dart';
import '../document/element_id.dart';
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

/// Adds an element on top of the drawing: a stroke, a text, a duplicate...
class AddElementCommand implements DrawingCommand {
  /// Creates a command that adds [element].
  const AddElementCommand(this.element);

  /// The element to add.
  final DrawingElement element;

  @override
  Drawing apply(Drawing drawing) => drawing.withElementAdded(element);

  @override
  Drawing revert(Drawing drawing) => drawing.withElementRemoved(element.id);
}

/// Replaces an element with a changed version of itself: moved, resized,
/// rotated, recolored, a text edited... (ADR 0004).
class UpdateElementCommand implements DrawingCommand {
  /// Creates a command that turns [before] into [after]; both must have the
  /// same id.
  UpdateElementCommand(this.before, this.after)
    : assert(before.id == after.id, 'An update keeps the element id');

  /// The element as it was.
  final DrawingElement before;

  /// The element as it becomes.
  final DrawingElement after;

  @override
  Drawing apply(Drawing drawing) => drawing.withElementReplaced(after);

  @override
  Drawing revert(Drawing drawing) => drawing.withElementReplaced(before);
}

/// Removes an element, remembering its place in the z-order.
class DeleteElementCommand implements DrawingCommand {
  /// Creates a command that deletes [element], found at [index].
  const DeleteElementCommand(this.element, this.index);

  /// Creates a command that deletes the element [id] from [drawing], or
  /// returns `null` if there is no such element.
  static DeleteElementCommand? forDrawing(Drawing drawing, String id) {
    final index = drawing.elements.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    return DeleteElementCommand(drawing.elements[index], index);
  }

  /// The deleted element.
  final DrawingElement element;

  /// Its index in the z-order.
  final int index;

  @override
  Drawing apply(Drawing drawing) => drawing.withElementRemoved(element.id);

  @override
  Drawing revert(Drawing drawing) =>
      drawing.withElementInserted(index, element);
}

/// Attaches an eraser pass to every stroke it touches (ADR 0006).
///
/// The pass is stored on each stroke in that stroke's local coordinates, so
/// [erasures] holds one [Erasure] per stroke id, all sharing the same id.
class EraseCommand implements DrawingCommand {
  /// Creates an erase command.
  const EraseCommand(this.sheetErasure, this.erasures);

  /// Creates an erase command for the strokes of [drawing] touched by the
  /// eraser path [points] of the given [width], in sheet units.
  ///
  /// Returns `null` when the eraser touches nothing, so that empty passes do
  /// not pollute the undo history. Only erasable elements are affected.
  static EraseCommand? forDrawing(
    Drawing drawing,
    List<SheetPoint> points,
    double width,
  ) {
    final sheetErasure = Erasure(
      id: newElementId(),
      points: points,
      width: width,
    );
    final erasures = <String, Erasure>{
      for (final e in drawing.elements)
        if (e is StrokeElement && eraserTouchesStroke(points, width, e))
          e.id: _toLocal(sheetErasure, e),
    };
    if (erasures.isEmpty) return null;
    return EraseCommand(sheetErasure, erasures);
  }

  static Erasure _toLocal(Erasure erasure, DrawingElement element) {
    final t = element.transform;
    if (t.isIdentity) return erasure;
    return Erasure(
      id: erasure.id,
      width: erasure.width / t.scale,
      points: [
        for (final p in erasure.points)
          () {
            final local = t.invert(Offset(p.x, p.y));
            return SheetPoint(
              local.dx,
              local.dy,
              pressure: p.pressure,
              time: p.time,
            );
          }(),
      ],
    );
  }

  /// The eraser pass in sheet coordinates, as the child drew it.
  final Erasure sheetErasure;

  /// The pass in each touched stroke's coordinates, by stroke id.
  final Map<String, Erasure> erasures;

  /// Ids of the strokes the pass is attached to.
  Set<String> get strokeIds => erasures.keys.toSet();

  @override
  Drawing apply(Drawing drawing) => drawing.withElementsMapped(
    (e) => e is StrokeElement && erasures.containsKey(e.id)
        ? e.withErasure(erasures[e.id]!)
        : e,
  );

  @override
  Drawing revert(Drawing drawing) => drawing.withElementsMapped(
    (e) => e is StrokeElement && erasures.containsKey(e.id)
        ? e.withoutErasure(erasures[e.id]!)
        : e,
  );
}

/// Removes every element ("Clear sheet"). Undoable, like everything else.
class ClearCommand implements DrawingCommand {
  /// Creates a command that clears [removed] from the drawing.
  const ClearCommand(this.removed);

  /// The elements that were on the sheet before clearing.
  final List<DrawingElement> removed;

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

  /// Commands that [undo] would revert, oldest first.
  List<DrawingCommand> get undoCommands => List.unmodifiable(_undo);

  /// Commands that [redo] would apply again, the next one last.
  List<DrawingCommand> get redoCommands => List.unmodifiable(_redo);

  /// Restores a stack saved with [undoCommands] and [redoCommands] on top of
  /// [drawing] (ADR 0007).
  void restore(
    Drawing drawing,
    List<DrawingCommand> undo,
    List<DrawingCommand> redo,
  ) {
    _drawing = drawing;
    _undo
      ..clear()
      ..addAll(undo.skip(undo.length > limit ? undo.length - limit : 0));
    _redo
      ..clear()
      ..addAll(redo);
  }

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
