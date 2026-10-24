# 0005. In-house drawing engine with raster cache

- **Status:** accepted, validated by the prototype on the reference device
- **Date:** 2026-10-24

## Context

The drawing engine is the heart of Pastello. It must render the vector
document model (ADR 0004), including per-stroke erasures and the lasso Select
tool, at the display's full frame rate (90 Hz on the reference Redmi Pad 2)
with hundreds or thousands of strokes. Ready-made "drawing board" packages
impose their own data model and depend on external maintainers.

## Decision

The drawing engine is **developed and owned by this project**, on top of
Flutter's `CustomPainter`. This is not negotiable: if performance problems
appear, we optimize our engine rather than switching to a third-party package.

- The **stroke in progress** is painted live by a dedicated painter.
- **Committed content** is flattened into a cached image
  (`Picture` → `ui.Image`) that is rebuilt only when the document changes, so
  the per-frame cost stays constant.
- **Fixed layers**, each in its own `RepaintBoundary`: background → drawing →
  elements (text, stickers, shapes) → selection UI.
- While the **Select tool** is active, selected elements are taken out of the
  cache and painted on top while they move.
- The stroke outline algorithm (variable width from speed or pressure) is
  chosen in a separate decision.

### Planned optimizations, if needed

1. Incremental cache updates: paint a new stroke on top of the existing image.
2. Point simplification when a stroke ends (e.g. Ramer–Douglas–Peucker).
3. Tiled cache: repaint only the region that changed.
4. Periodic cache snapshots for instant undo/redo.
5. Serialization and saving in a separate isolate.

### Lessons from the prototype

- On Android, Flutter uses Impeller, which re-renders every layer each frame:
  `RepaintBoundary` saves CPU work, not GPU work. The GPU cost is driven by
  how many times a frame fills the whole sheet, so a frame must fill it
  **once**: the cache includes the background, the frozen part of the live
  stroke is merged into a copy of the cache, and the eraser paints the
  background instead of using a layer.
- Measured on the Redmi Pad 2: about 5–7 ms per frame at rest and 6–8 ms
  while drawing (budget at 90 Hz: 11.1 ms), regardless of the number of
  strokes; undo with 500 strokes takes about 40–60 ms.

## Consequences

- Full control over look, performance and file format.
- More code to write and test: rendering is covered by golden tests.
- A throwaway prototype measures performance on the reference device before
  the real implementation starts.

## Alternatives considered

- **Ready-made drawing board package:** faster to start, but incompatible with
  our data model and outside the project's control.
