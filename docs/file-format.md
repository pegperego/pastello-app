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
  "schemaVersion": 1,
  "revision": 12,
  "sheet": { "width": 1114, "height": 663 },
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
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `schemaVersion` | Format version. Readers migrate older versions and refuse newer ones. |
| `revision` | Increases at every save; `history.json` must carry the same value. |
| `sheet` | Fixed sheet size in sheet units (not pixels). |
| `elements` | Elements from bottom to top (z-order). |

### Stroke

| Field | Meaning |
|---|---|
| `id` | 32 hex characters, unique in the drawing. |
| `tool` | `pencil`, `marker`, `brush`, `crayon` or `rainbow`. |
| `color` | ARGB as a 32-bit integer (ignored by `rainbow`). |
| `width` | Base width in sheet units. |
| `points` | Flat list of `x, y, pressure, time` quadruples: sheet units, 0–1, milliseconds since the stroke started. Rounded to hundredths. |
| `erasures` | Eraser passes attached to this stroke, in the stroke's coordinates. The same pass (same `id`) is attached to every stroke it touched. |

## `history.json`

```json
{
  "schemaVersion": 1,
  "revision": 12,
  "undo": [ { "type": "add", "stroke": { … } } ],
  "redo": []
}
```

Commands: `add` (`stroke`), `erase` (`erasure`, `strokeIds`) and `clear`
(`removed`: the strokes that were on the sheet). At most 100 undo steps are
kept. If `revision` does not match `drawing.json`, or the file cannot be read,
the history is discarded and the drawing is opened without it
([ADR 0007](adr/0007-persistent-undo-history.md)).

## `meta.json`

```json
{ "createdAt": "2026-10-24T18:02:11.000", "updatedAt": "2026-10-24T18:40:03.000" }
```

Files in the trash also have `deletedAt`; they are purged 30 days later.

## Changing the format

1. Increase `drawingSchemaVersion` in `packages/pastello_engine`.
2. Add a migration step in `migrateDrawingJson` and a test with a file in the
   old format.
3. Update this document.
