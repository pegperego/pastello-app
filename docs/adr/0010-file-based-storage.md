# 0010. File-based storage, trash and backup

- **Status:** accepted
- **Date:** 2026-10-24

## Context

A child must never lose a drawing: not because of a crash, a dead battery, an
accidental delete or a broken tablet. At the same time drawings must stay
private and on the device. The number of drawings is small (tens to hundreds).

## Decision

Drawings are stored as plain files in the app's private storage, without a
database:

```text
<app documents>/
├── trash/               # deleted drawings, same layout, with deletion date
└── drawings/
    └── <uuid>/
        ├── drawing.json     # the document, with schemaVersion
        ├── history.json     # undo/redo history
        ├── thumbnail.png    # gallery thumbnail
        └── fills/           # bucket fill masks (after v1)
```

- **Autosave**, debounced 1–2 seconds after the last change, and always when
  the app goes to the background. There is no "Save" button.
- **Atomic writes:** write to a temporary file, then rename it.
- **Migrations** are driven by `schemaVersion`.
- **Trash:** deleting a drawing moves it to `trash/`. It can be restored for
  **30 days** and is purged automatically on app start afterwards. Emptying the
  trash manually requires the parental gate.
- **Backup:**
  - Android **cloud backup is disabled**, so drawings never reach the device's
    Google account.
  - **Device-to-device transfer is allowed** (via `dataExtractionRules`), so
    drawings follow the child to a new tablet without going through the cloud.
  - Later, the parents' page will offer **"Export all drawings"** as a `.zip`
    file and **"Import"** to restore them, using the same documented layout.
    Done in version 1.1, see ADR 0020.

## Consequences

- Files are easy to inspect, document, test and back up.
- No storage permissions are needed.
- If the gallery ever gets slow, an index file can be added without changing
  the drawing format.

## Alternatives considered

- **SQLite database:** queries and transactions, but an opaque format and
  unnecessary complexity for this amount of data.
- **Android cloud backup:** convenient, but sends a child's drawings to a
  third-party cloud.
