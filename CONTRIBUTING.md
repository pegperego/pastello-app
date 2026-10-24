# Contributing

Thanks for your interest in this project! This guide explains how to propose
changes. By participating you agree to follow our
[Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- **Bugs and ideas:** open an issue using one of the templates. Search existing
  issues first to avoid duplicates.
- **Larger changes:** open an issue to discuss the idea before writing code, so
  that effort is not wasted.
- **Small fixes** (typos, docs): feel free to open a pull request directly.

## Project principles

Every contribution must respect these principles. Pull requests that break
them will not be merged.

1. **Kids first.** The UI must be usable by a child who reads little or not at
   all: large touch targets, clear icons, no destructive action without an easy
   way back.
2. **Offline only.** No network access, no `INTERNET` permission, no runtime
   downloads (fonts, images, etc. must be bundled).
3. **Private by design.** No analytics, ads, crash reporting services or any
   other data collection.
4. **Free software only.** Dependencies must be open source and compatible with
   GPL-3.0. No Google Play Services, Firebase or other proprietary SDKs.

## Language

- Code, code comments, commit messages, issues, pull requests and everything in
  `docs/` are written in **English**.
- The `analisi/` folder holds the original analysis notes in **Italian**; you do
  not need to update it when contributing.

## Development setup

> The Flutter project has not been created yet. This section will be completed
> once the analysis phase is over.

## Coding guidelines

- Follow the official [Dart style guide](https://dart.dev/effective-dart) and
  keep `dart format` and `flutter analyze` clean.
- Write doc comments (`///`) for public APIs and explain the *why* in comments,
  not the *what*.
- Add or update tests for every behavior change.

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/), for
example:

```
feat(canvas): add highlighter brush
fix(gallery): keep thumbnails in sync after rename
docs: describe the drawing file format
```

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep the pull request focused on a single change.
3. Make sure formatting, analysis and tests pass.
4. Update `CHANGELOG.md` under **Unreleased** when the change is user-visible.
5. Fill in the pull request template.

## License of contributions

By submitting a contribution you agree that it is licensed under the
[GPL-3.0](LICENSE), the same license as the project.
