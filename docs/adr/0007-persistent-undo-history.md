# 0007. Undo/redo with commands, persisted with the drawing

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Undo is a child's safety net. It must cover every change, including
"Clear sheet", and it should still work when a drawing is reopened from the
gallery the next day.

## Decision

- Every change is a **reversible, serializable command** (`AddElement`,
  `EraseStrokes`, `TransformElements`, `ChangeStyle`, `DeleteElements`,
  `ClearSheet`, ...). The editor keeps an undo stack and a redo stack, limited
  to **100 steps**.
- A continuous gesture (for example dragging a sticker) produces a **single**
  command.
- The history is **saved with the drawing** in a separate `history.json` file,
  next to `drawing.json`.
  - `drawing.json` stays the clean, documented source of truth.
  - `history.json` stores both stacks and the **revision** of `drawing.json`
    it applies to. If they do not match (for example after an interrupted
    save), the history is discarded and the drawing is left untouched.
  - If the document schema changes and the history cannot be migrated, it is
    discarded in the same way.
  - The history is not included in exports and is not copied when a drawing
    is duplicated.

## Consequences

- Children can undo changes even after closing and reopening a drawing.
- In the worst case the history is lost, never the drawing.
- Commands must be serializable and covered by round-trip tests.
- Files grow a little; "Clear sheet" is the worst case because it keeps the
  removed elements.

## Alternatives considered

- **In-memory history only:** simpler and common in drawing apps, but undo
  would be lost when the drawing is closed.
- **History inside `drawing.json`:** a single file, but it would mix the
  document with editor state and make the format harder to document.
