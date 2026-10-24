# 0012. Dart workspace with separate app and engine packages

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The drawing engine is developed in-house (ADR 0005) and must stay independent
from the UI, storage and state management. A convention alone ("do not import
the UI from the engine") is easy to break as contributors come and go.

## Decision

The repository is a **Dart pub workspace** with two packages:

```text
pastello/
├── pubspec.yaml                  # workspace root
├── app/                          # the Flutter app
│   └── lib/src/
│       ├── app/                  # MaterialApp, theme, routing
│       ├── core/                 # shared utilities
│       ├── l10n/                 # ARB translations
│       └── features/
│           ├── editor/
│           ├── gallery/          # gallery and trash
│           ├── stickers/         # content catalog and packs
│           ├── export/           # gallery export, share, print
│           └── parents/          # parental gate, about, backup
└── packages/
    └── pastello_engine/          # the drawing engine
        ├── lib/src/
        │   ├── document/         # Drawing, Element, serialization, migrations
        │   ├── commands/         # undo/redo commands
        │   ├── geometry/         # strokes, eraser, hit testing, lasso
        │   └── rendering/        # painters, raster cache
        ├── test/                 # unit and golden tests
        └── benchmark/            # performance harness
```

- `pastello_engine` depends only on Dart and Flutter's rendering APIs. It must
  not depend on the app, Riverpod, the file system or platform plugins.
- Inside the app, code is organized **by feature**; shared code goes to
  `core/`.

## Consequences

- The compiler enforces the boundary between engine and app.
- The engine can be tested and benchmarked in isolation, and possibly reused.
- Contributors need a recent Dart SDK with workspace support (already
  satisfied by the pinned Flutter version).

## Alternatives considered

- **Single package with folders:** simpler, but the engine/UI boundary would
  rely on discipline only.
- **Layer-first folders** (`models/`, `views/`, `controllers/`): common, but
  spreads one feature across the whole tree.
