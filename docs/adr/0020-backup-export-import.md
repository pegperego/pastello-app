# 0020. Exporting and importing all drawings

- **Status:** accepted
- **Date:** 2026-10-30

## Context

Android cloud backup is disabled (ADR 0010), so drawings live only on the
device. Moving from a sideloaded build to the Google Play one needs an
uninstall, because the signatures differ (ADR 0019), and uninstalling deletes
the drawings. Parents also need a way to keep a copy or move to a new tablet.
ADR 0010 already planned "Export all drawings" as a `.zip` in the parents'
page.

## Decision

- The parents' page (behind the parental gate) offers **Export all drawings**
  and **Import drawings** (functional decision F-21).
- **Format:** a `.zip` holding a `pastello-backup.json` manifest
  (`format`, `appVersion`, `createdAt`) and the gallery's folders as stored
  on the device: `drawings/<id>/drawing.json`, `history.json`, `meta.json`,
  `thumbnail.png` (see `docs/file-format.md`). The trash is not exported.
- **Where:** the Android system file picker (Storage Access Framework,
  `ACTION_CREATE_DOCUMENT` and `ACTION_OPEN_DOCUMENT`), through a small
  platform channel in `MainActivity`. The parent chooses the place; the app
  needs no storage permission and no network access.
- **Import adds, never replaces:** a drawing whose id is already in the
  gallery or in the trash is skipped, so importing the same file twice
  creates no duplicates. Each drawing is copied to a staging folder and
  moved into place only when complete.
- **Untrusted input:** only the expected entries are read (ids of 32
  hexadecimal characters, the four file names above), with limits on the
  number of entries and on their sizes; anything else is ignored. A drawing
  that cannot be decoded, for example one written by a newer version, is
  skipped and reported.
- **Library:** `archive` (MIT, 4.5.2), already in the lockfile as a
  transitive dependency, becomes a direct one. File picking uses no plugin.

## Consequences

- Drawings can be moved between installs and devices without any cloud.
- A backup file can be opened by other apps on the device or copied
  anywhere the parent chooses: this is the parent's decision, behind the
  parental gate.
- The backup format follows the storage format: a change to the files in
  `docs/file-format.md` must keep old backups importable.

## Alternatives considered

- **A file picker plugin:** more code and possible extra permissions for
  two simple intents.
- **Android cloud backup:** sends a child's drawings to an account without
  an explicit choice (rejected in ADR 0010).
- **Share sheet for the export:** works, but the import still needs a
  picker, and "Save" makes the destination clearer.
