# Drawing file format

Drawings are stored in the app's private storage, one folder per drawing
([ADR 0010](adr/0010-file-based-storage.md)):

```text
<app support directory>/
├── settings.json            # app preferences
├── drawings/
│   └── <id>/
│       ├── drawing.json     # the drawing (this document)
│       ├── history.json     # undo/redo history (optional)
│       ├── meta.json        # dates used by the gallery
│       └── thumbnail.png    # gallery thumbnail
└── trash/
    └── <id>/                # same layout, plus "deletedAt" in meta.json
```

Every file is written atomically: to `<name>.tmp` first, then renamed.

## `drawing.json`

```json
{
  "schemaVersion": 5,
  "revision": 12,
  "sheet": { "width": 1114, "height": 663 },
  "background": { "color": 4294967295, "pattern": "lines" },
  "elements": [
    {
      "type": "stroke",
      "id": "9f2c…",
      "tool": "crayon",
      "color": 4293212486,
      "width": 10,
      "points": [120.5, 88, 0.5, 0, 131.25, 90.5, 0.5, 16],
      "erasures": [
        { "id": "41ab…", "width": 20, "points": [125, 60, 0.5, 0, 126, 120, 0.5, 40] }
      ]
    },
    {
      "type": "text",
      "id": "77d0…",
      "text": "Ciao nonna!",
      "color": 4287513773,
      "font": "playwrite",
      "fontSize": 48,
      "transform": { "x": 540, "y": 120, "scale": 1.4, "rotation": -0.2 }
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `schemaVersion` | Format version. Readers migrate older versions and refuse newer ones. |
| `revision` | Increases at every save; `history.json` must carry the same value. |
| `sheet` | Fixed sheet size in sheet units (not pixels). |
| `background` | Paper `color` (ARGB) and `pattern`: `none`, `lines`, `bigSquares`, `smallSquares` or `dots`. Omitted for plain white paper. One printed centimeter is the sheet's long side divided by 29.7 (an A4 page). |
| `elements` | Elements from bottom to top (z-order). |

### Transform

Any element may have a `transform` (omitted when it changes nothing): the
element is described in local coordinates, scaled by `scale`, rotated by
`rotation` (radians, clockwise on screen) and moved by `x`, `y`.

### Text

| Field | Meaning |
|---|---|
| `text` | The text; lines are separated by `\n`. |
| `color` | ARGB as a 32-bit integer. |
| `font` | `andika`, `playwrite`, `fredoka` or `comicNeue`. |
| `fontSize` | Size in sheet units, before the transform's scale. |

The local origin of a text is the center of its box.

### Sticker

```json
{ "type": "sticker", "id": "c1f0…", "pack": "fluent-animals", "item": "dog_face", "size": 160 }
```

| Field | Meaning |
|---|---|
| `pack`, `item` | Which sticker, in which content pack ([ADR 0018](adr/0018-content-packs.md)). The artwork is not copied into the drawing. |
| `size` | Side of the sticker's square, in sheet units, before the transform's scale. |

A sticker whose pack is not installed is drawn as a "?" placeholder; the
reference is kept, so it reappears when the pack is installed.

### Shape

```json
{ "type": "shape", "id": "5e2a…", "kind": "star", "extent": [120, 110], "color": 4280110296, "strokeWidth": 10, "filled": true }
```

| Field | Meaning |
|---|---|
| `kind` | `ellipse`, `rectangle`, `triangle`, `star`, `heart`, `line` or `arrow`. |
| `extent` | Figures: width and height of the box they are inscribed in. Lines and arrows: vector from start to end (it can be negative). The local origin is the center. |
| `color`, `strokeWidth` | Outline (and fill) color, outline width in sheet units. |
| `filled` | Present and `true` for filled figures; lines are never filled. |

### Stroke

| Field | Meaning |
|---|---|
| `id` | 32 hex characters, unique in the drawing. |
| `tool` | `pencil`, `marker`, `brush`, `crayon` or `rainbow`. |
| `color` | ARGB as a 32-bit integer (ignored by `rainbow`). |
| `width` | Base width in sheet units. |
| `points` | Flat list of `x, y, pressure, time` quadruples: sheet units, 0–1, milliseconds since the stroke started. Rounded to hundredths. |
| `erasures` | Eraser passes attached to this stroke, in the stroke's local coordinates. The same pass (same `id`) is attached to every stroke it touched. Texts are never erased. |

## `history.json`

```json
{
  "schemaVersion": 5,
  "revision": 12,
  "undo": [ { "type": "add", "stroke": { … } } ],
  "redo": []
}
```

Commands: `add` (`element`), `update` (`before`, `after`: the same element
moved, resized, rotated or edited), `delete` (`element`, `index` in the
z-order), `erase` (`sheetErasure` as drawn, and `erasures`: the pass in each
touched stroke's coordinates, by stroke id) and `clear` (`removed`: the
elements that were on the sheet), `batch` (`commands`: several commands
applied as one undo step, for lasso selections), `background` (`before`,
`after`). Version 1 forms (`add` with `stroke`,
`erase` with `erasure` and `strokeIds`) are still read. At most 100 undo steps are
kept. If `revision` does not match `drawing.json`, or the file cannot be read,
the history is discarded and the drawing is opened without it
([ADR 0007](adr/0007-persistent-undo-history.md)).

## `meta.json`

```json
{ "createdAt": "2026-10-24T18:02:11.000", "updatedAt": "2026-10-24T18:40:03.000" }
```

Files in the trash also have `deletedAt`; they are purged 30 days later.

## Versions

| Version | Changes |
|---|---|
| 1 | Strokes and erasures. |
| 2 | Texts, element transforms, `update` and `delete` commands. Version 1 files are read as they are. |
| 3 | Stickers. Older files are read as they are. |
| 4 | Shapes. Older files are read as they are. |
| 5 | Paper color and pattern. Older files are read as they are (white paper). |

## Changing the format

1. Increase `drawingSchemaVersion` in `packages/pastello_engine`.
2. Add a migration step in `migrateDrawingJson` and a test with a file in the
   old format.
3. Update this document.
