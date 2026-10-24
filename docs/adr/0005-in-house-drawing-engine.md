# 0005. In-house drawing engine with raster cache

- **Status:** accepted (performance to be measured on the reference device)
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

## Consequences

- Full control over look, performance and file format.
- More code to write and test: rendering is covered by golden tests.
- A throwaway prototype measures performance on the reference device before
  the real implementation starts.

## Alternatives considered

- **Ready-made drawing board package:** faster to start, but incompatible with
  our data model and outside the project's control.
