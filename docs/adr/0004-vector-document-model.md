# 0004. Vector document model

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Children want to write text on their drawings, add stickers and shapes, and
move them around afterwards. They also need a reliable undo. A plain bitmap
cannot offer any of this, and it ties the drawing to one screen resolution.

## Decision

A drawing is an **ordered list of elements**; list order is the z-order.
Bitmaps are only produced for display and export.

```text
Drawing
├── id, title, createdAt, updatedAt, schemaVersion
├── sheet: { width, height, background }     # fixed logical size
└── elements: [Element]                       # order = z-order
    │   (every element has: id, transform { translation, scale, rotation })
    ├── StrokeElement   { tool, color, width, points[x, y, pressure], erasures[] }
    ├── TextElement     { text, font, size, color }
    ├── StickerElement  { packId, elementId }
    ├── ShapeElement    { kind, size, stroke, fill }
    └── FillElement     { mask PNG, color }   # bucket fill, after v1
```

- **Sheet units, not screen pixels.** The sheet has a fixed size taken from the
  screen proportions when it is created, in its orientation at that time.
- **Every element has a transform.** Moving, scaling or rotating changes the
  transform, never the element's own geometry.
- **Direct manipulation:** text, stickers and shapes can be moved, resized,
  rotated and deleted by touching them **when the active tool is Text,
  Stickers, Shapes or Select**. With drawing tools, a touch always draws, even
  on top of an element.
- **Freehand strokes are not touch-selectable**, so that a touch on the sheet
  always means "draw".
- A dedicated **Select tool** (lasso) lets the user select any elements,
  strokes included, and move, resize, rotate or delete them.
- **Erasures are stored on the strokes they affect** (`erasures`), so a
  partially erased stroke keeps its erased parts when it is moved. See the
  eraser ADR.

## Consequences

- Undo/redo works on small, explicit changes.
- Files are small and drawings can be exported at any resolution.
- Rendering many strokes every frame would be slow: the renderer must cache
  committed content as a raster image.
- The document format is versioned (`schemaVersion`) and must be migrated when
  it changes.

## Alternatives considered

- **Bitmap canvas:** simplest to draw on, but text and stickers could not be
  moved after placement and undo would need full image snapshots.
- **Strokes selectable by plain touch:** ambiguous with drawing and frustrating
  for young children.
