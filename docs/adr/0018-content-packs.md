# 0018. Content packs and future updatable catalog

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Stickers, backgrounds, fonts and (later) coloring pages should be easy to
extend, including by the community, and eventually updatable without a new
app release. v1 has no network access (ADR 0003).

## Decision

- Content is organized in **packs**, each described by a manifest:

```text
pack/
├── pack.json        # id, version, title (it/en), author, license, items
├── stickers/*.svg
├── backgrounds/*.svg|png
└── coloring/*.svg
```

- The app reads packs through a `ContentCatalog` interface with pluggable
  sources. v1 ships only a **`BundledSource`** (packs included as assets).
- Drawings reference content as `packId/elementId`, so they stay valid when a
  pack is updated.
- The **Credits** page is generated from the pack manifests' license and
  attribution fields.
- **Missing content:** if a drawing references an element from a pack that is
  not installed, a **placeholder** ("?") is shown with the same position and
  size. The reference is kept, so the element reappears if the pack becomes
  available again.

### After v1

- A **`RemoteSource`** downloads packs from a separate public repository,
  `pegperego/pastello-catalog`. Downloads are started by an adult behind the
  parental gate, never automatically, without accounts or any data beyond the
  file request. Packs are verified (signature or checksum) before install.
- **Importing a pack from a `.zip` file** (no network) ships together with the
  remote catalog, as both share the same install and verification logic.
- There is a single app build. When the remote catalog is implemented, the app
  will request the `INTERNET` permission for catalog downloads only, and
  ADR 0003 will be superseded.
- Downloaded packs stay on the device: the app remains fully usable offline.

## Consequences

- New content can be added without touching the code.
- The pack format becomes a public contract and must be versioned and
  documented.

## Alternatives considered

- **Hard-coded assets:** simpler at first, but every new sticker would need a
  code change and a release, and a future catalog would require a rewrite.
