# Documentation

English documentation for users and contributors.

| Path | Content |
|------|---------|
| [`adr/`](adr/) | Architecture Decision Records: one file per significant technical decision |
| [`design/`](design/) | Design guidelines: colors, typography, icons, accessibility |
| [`file-format.md`](file-format.md) | How drawings, history and thumbnails are stored |
| [`content-packs.md`](content-packs.md) | Sticker packs: structure, `pack.json`, how to add one |
| [`releasing.md`](releasing.md) | Signing, GitHub Releases and Google Play |
| [`privacy-policy.md`](privacy-policy.md) | Privacy policy (English and Italian) |
| [`../fastlane/metadata/android/`](../fastlane/metadata/android/) | Store listing texts and images |

The original analysis notes are kept, in Italian, in
[`../analisi/`](../analisi/).

## Architecture Decision Records

| # | Decision |
|---|---|
| [0001](adr/0001-record-architecture-decisions.md) | Record architecture decisions |
| [0002](adr/0002-flutter-android-tablet-first.md) | Flutter on Android, designed for tablets |
| [0003](adr/0003-offline-only-no-data-collection.md) | Offline only, no data collection |
| [0004](adr/0004-vector-document-model.md) | Vector document model |
| [0005](adr/0005-in-house-drawing-engine.md) | In-house drawing engine with raster cache |
| [0006](adr/0006-stroke-attached-eraser.md) | Pixel eraser attached to strokes |
| [0007](adr/0007-persistent-undo-history.md) | Undo/redo with commands, persisted with the drawing |
| [0008](adr/0008-touch-input-handling.md) | Touch input handling |
| [0009](adr/0009-riverpod-state-management.md) | Riverpod for state management |
| [0010](adr/0010-file-based-storage.md) | File-based storage, trash and backup |
| [0011](adr/0011-export-share-print.md) | Export, share and print |
| [0012](adr/0012-workspace-app-and-engine.md) | Dart workspace with separate app and engine packages |
| [0013](adr/0013-localization-and-keyboard-privacy.md) | Localization and keyboard privacy |
| [0014](adr/0014-dependency-policy.md) | Dependency policy |
| [0015](adr/0015-quality-and-workflow.md) | Quality gates and development workflow |
| [0016](adr/0016-distribution-and-signing.md) | Distribution channels and signing |
| [0017](adr/0017-child-safety.md) | Child safety |
| [0018](adr/0018-content-packs.md) | Content packs and future updatable catalog |
| [0019](adr/0019-google-play-signing-key.md) | Google-generated signing key on Google Play |
| [0020](adr/0020-backup-export-import.md) | Exporting and importing all drawings |
| [0021](adr/0021-paint-bucket-fills.md) | Paint bucket fills |
