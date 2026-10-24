# 0006. Pixel eraser attached to strokes

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Children expect the eraser to behave like a real one: it removes ink where it
passes, not whole strokes, and it never removes the sheet's background (lines,
squares, coloring page outlines). Strokes can also be moved later with the
Select tool (ADR 0004), so erased parts must move together with their stroke.

## Decision

- When the finger lifts, the eraser path (with its width) is **attached to
  every stroke it intersects**, stored in that stroke's `erasures` in the
  stroke's local coordinates (the inverse of its transform).
- A stroke with erasures is rendered inside a `saveLayer`: the stroke first,
  then its erasures with `BlendMode.clear`. Strokes without erasures have no
  extra cost, and everything ends up in the raster cache (ADR 0005).
- Strokes drawn **after** an erasure are not affected by it.
- Undo removes an erasure from all the strokes it was attached to, as a single
  command.
- **Text, stickers and shapes are not affected by the eraser.** They are
  removed by dragging them to the trash, with the delete button of a selected
  element, or with the Select tool. A "Clear sheet" action is available and can
  be undone.
- In code, `erasures` is a **generic capability of elements**, currently
  enabled only for strokes. This keeps open a possible future
  "convert to drawing" feature that turns text or stickers into erasable
  graphics.

## Consequences

- The eraser feels natural and the background is always safe.
- Erased parts follow their stroke when it is moved.
- Strokes with many erasures cost more to render; the raster cache keeps this
  cost out of the per-frame budget.

## Alternatives considered

- **Global eraser layer** (`BlendMode.clear` on the whole drawing layer):
  simpler, but erased "holes" would stay in place when a stroke is moved.
- **Whole-stroke eraser:** common in vector apps, but confusing for children.
