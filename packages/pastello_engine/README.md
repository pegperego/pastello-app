# pastello_engine

The drawing engine of [Pastello](../../README.md): document model, undoable
commands, stroke geometry and rendering.

It is pure Flutter rendering code, with no dependency on the app, the file
system or platform plugins, and no third-party packages
([ADR 0012](../../docs/adr/0012-workspace-app-and-engine.md),
[ADR 0014](../../docs/adr/0014-dependency-policy.md)).

## What's inside

| Folder | Content |
|---|---|
| `lib/src/document/` | `Drawing`, `StrokeElement`, `SheetPoint`, tools and widths |
| `lib/src/commands/` | Reversible commands and the undo/redo `CommandStack` |
| `lib/src/geometry/` | Stroke outline, point simplification, eraser hit testing |
| `lib/src/rendering/` | Paper grain, per-tool painting, raster cache, `SheetPainter` |

## How rendering works

A frame must fill the sheet **once**: on Android, Flutter's Impeller backend
re-renders every layer each frame, so GPU cost grows with each full-sheet
pass ([ADR 0005](../../docs/adr/0005-in-house-drawing-engine.md)).

- Committed content and the background live in an opaque **cache** image,
  updated incrementally when a stroke is added or erased.
- The older part of the stroke in progress is periodically **frozen** into a
  copy of the cache; only its tail is painted live.
- The eraser paints the background along its path; erasures are stored on the
  strokes they touch ([ADR 0006](../../docs/adr/0006-stroke-attached-eraser.md)).

## Tests

```sh
flutter test                    # unit, widget and golden tests
flutter test --update-goldens   # after an intentional rendering change
```

Golden images live in `test/goldens/`. A dedicated test checks that a stroke
painted in pieces while it is drawn matches the committed stroke.
