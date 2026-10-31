# 0021. Paint bucket fills

- **Status:** accepted
- **Date:** 2026-10-31

## Context

The paint bucket (functional decision F-18) fills the closed area under the
finger. The drawing is a list of vector elements (ADR 0004), but a fill is a
raster operation: what is "closed" depends on how strokes look once painted,
including their width, erasures and small gaps a child leaves in an outline.
Risk R-03 suggested storing fills as PNG masks.

## Decision

- **Borders:** strokes of solid tools (pencil, marker, brush, crayon,
  rainbow, neon) and shapes. See-through strokes (highlighter, watercolor)
  and strokes made of loose pieces (glitter, stars, spray) do not stop the
  color, nor do fills, texts, stickers and the paper's lines.
- **Algorithm:** the borders are painted without grain at one pixel per
  sheet unit; pixels at least half opaque are walls. A distance transform
  grows the walls by 5 units, closing gaps up to the "medium" width (10).
  The free area around the tap is flooded, then grown back by 6.5 units so
  the color reaches under the lines and leaves no white edge. A tap close to
  a line starts from the nearest free pixel; an area too narrow to have free
  pixels is flooded without closing gaps. The computation runs in another
  isolate (`compute`).
- **A tap on a border recolors it** instead of filling, except for the
  rainbow, which has no color of its own.
- **Model:** a `FillElement` with a color, a mask, eraser passes and a
  transform, like a stroke. The mask is stored as **runs**: for each row,
  `start, length` pairs relative to the mask's `left` and `top`. It is drawn
  as a path of rectangles, merging runs repeated on consecutive rows.
- **Z-order:** fills are painted under every other element, newer fills
  above older ones (`Drawing.paintOrder`); the list order stays the order of
  creation. Hit testing follows the painting order.
- **Cache:** adding a fill repaints, from the paper up, only the fill's
  bounds in the raster cache (ADR 0005). The result is the same as a full
  rebuild.
- **Eraser, lasso, undo:** the eraser attaches its pass to the fills it
  touches, as for strokes (ADR 0006). The lasso catches a fill when most of
  its area is inside. A new fill that fully covers older ones (same
  coordinates) removes them in the same undoable step, so coloring an area
  again and again does not make the drawing grow.

## Consequences

- Filling is predictable for a child: lines always stay sharp above the
  color, and recoloring an area just works.
- Files stay plain JSON, decoded synchronously: no image decoding when a
  drawing is opened. A complex fill of the whole sheet takes a few tens of
  kilobytes.
- Masks are one unit per pixel: where a fill's edge is not under a line (a
  closed gap, the sheet border) it shows small steps when zoomed in. The
  sheet is never zoomed today (D-07).
- A fill moved with the lasso is painted above the other elements while the
  finger moves, and goes back under them when released.
- The coloring pages (F-19) will add their outline as a border.

## Alternatives considered

- **PNG masks (R-03):** compact, but decoding is asynchronous and needs an
  extra step when a drawing is opened, and checking which fills a new one
  covers needs the pixels anyway.
- **Vector outlines of the area (paths traced from the mask):** smooth
  edges, but tracing is complex and fragile; the edges are mostly hidden
  under the lines anyway.
- **Fills above the strokes:** the strokes under a fill would disappear, and
  the lines of a coloring outline would be covered.
- **Flooding without closing gaps:** a small gap in an outline would make
  the color spill over the whole sheet, a common frustration in children's
  drawing apps.
