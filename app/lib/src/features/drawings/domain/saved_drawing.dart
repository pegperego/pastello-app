import 'package:pastello_engine/pastello_engine.dart';

/// A drawing loaded from storage, with its undo history (ADR 0007).
class SavedDrawing {
  const SavedDrawing({
    required this.drawing,
    this.undo = const [],
    this.redo = const [],
  });

  final Drawing drawing;

  /// Undo commands, oldest first. Empty when the history was discarded.
  final List<DrawingCommand> undo;

  /// Redo commands, the next one last.
  final List<DrawingCommand> redo;
}
