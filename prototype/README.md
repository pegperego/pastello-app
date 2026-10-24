# Pastello prototype

A **throwaway** app used to validate the drawing engine
([`packages/pastello_engine`](../packages/pastello_engine)) before the real app
is written. The engine is kept; this app will be deleted.

It shows a full-screen sheet with the v1 drawing tools (pencil, marker, brush,
crayon, rainbow, eraser), 12 colors, 4 widths, undo/redo/clear, and a
performance panel.

## Run it

```sh
# In the browser (quick visual checks)
flutter run -d chrome

# On the reference tablet, in profile mode (real performance numbers)
flutter run --profile -d <device-id>
```

Performance must only be judged on the device in profile mode: debug mode and
the browser use a different, much slower rendering path.

## Toolbar

| Button | What it does |
|---|---|
| ↶ ↷ | Undo / redo |
| Clear | Clear the sheet (undoable) |
| +100 / +500 | Add random strokes to stress the engine (one undo step) |
| cache / no cache | Toggle the raster cache to measure its benefit |
| Speed | Show / hide the performance panel |
| Rotation | Lock the current orientation |

## Performance panel

- **FPS** and **worst frame**: measured from the interval between frames.
- **build / raster**: per-frame cost reported by the engine (`FrameTiming`).
  At 90 Hz the budget is about 11 ms per frame.
- **strokes / points**: size of the drawing.
- **cache**: duration of the last cache update (incremental after a stroke or
  an eraser pass, full rebuild after undo/redo/clear).
