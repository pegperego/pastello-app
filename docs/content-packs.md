# Content packs

Stickers, coloring pages (and later backgrounds) are delivered as content
packs ([ADR 0018](adr/0018-content-packs.md)). In v1 the packs are bundled in
`app/assets/packs/`; a downloadable catalog may come later with the same
format.

```text
app/assets/packs/
├── index.json                 # {"packs": ["fluent-animals", ...]}, in tab order
├── LICENSE-fluent-emoji.txt
└── fluent-animals/
    ├── pack.json
    └── stickers/
        ├── dog_face.svg
        └── ...
```

## `pack.json`

```json
{
  "id": "fluent-animals",
  "version": 1,
  "kind": "stickers",
  "title": { "it": "Animali", "en": "Animals" },
  "icon": "dog_face",
  "author": "Microsoft Fluent Emoji",
  "license": "MIT",
  "licenseFile": "../LICENSE-fluent-emoji.txt",
  "source": "https://github.com/microsoft/fluentui-emoji",
  "items": [
    { "id": "dog_face", "file": "stickers/dog_face.svg", "name": "Dog face" }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | Stored in drawings with the item id: never rename it. |
| `version` | Increases when the pack changes. |
| `kind` | `stickers` (the default when omitted) or `coloring`. Packs of a kind the app does not know are skipped. |
| `title` | Category name by language; English is the fallback. |
| `icon` | Item shown on the category tab. |
| `license`, `licenseFile`, `author`, `source` | Shown in the credits. Only licenses compatible with GPL-3.0 ([ADR 0014](adr/0014-dependency-policy.md)). |
| `items` | `id` (stored in drawings, never rename it), `file` (SVG, relative to the pack), `name` (English, for screen readers). |

## Coloring pages

A pack with `"kind": "coloring"` holds coloring pages in `coloring/*.svg`
([ADR 0022](adr/0022-coloring-pages.md)). Each page is fitted to the sheet
with a margin, so it works in portrait and landscape; square or slightly
wide pages fit both best.

- **Outlines only:** black lines, no filled shapes in color, no text, no
  embedded images or filters. Dark pixels stop the paint bucket; white
  areas do not.
- **Thick, closed lines:** at least 16 units on an 800 × 800 page. Gaps up
  to about 10 sheet units are closed by the paint bucket; wider ones let
  the color out.
- **Licenses:** pages drawn by the project are released under CC0
  (`"license": "CC0-1.0"`).

```text
app/assets/packs/pastello-first/
├── pack.json        # "kind": "coloring"
└── coloring/
    ├── star.svg
    └── ...
```

## Adding a sticker pack

1. Create a folder with `pack.json` and the SVGs. Keep SVGs simple (no
   filters or embedded images) and square.
2. Add its id to `index.json` and both folders to the `assets` list in
   `app/pubspec.yaml`.
3. Check that the license allows redistribution under GPL-3.0 and that
   attribution is in `pack.json`.
4. Run the tests: they check that every file listed in a pack exists, and
   that coloring pages contain no images, filters or texts.

The bundled packs contain 220 Fluent Emoji (Flat style), © Microsoft, MIT
license.
