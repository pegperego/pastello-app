# 0015. Quality gates and development workflow

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The project starts with a single maintainer and hopes to grow a community.
Quality must be enforced by automation rather than by memory, especially for
the drawing engine, where regressions are visual and easy to miss.

## Decision

- **Static analysis:** `flutter_lints` plus a few stricter rules; `dart format`
  is mandatory.
- **Tests:**
  - unit tests for the engine, commands, serialization and storage;
  - widget tests for toolbars and gallery;
  - **golden tests** for rendering, run in CI on Linux (the reference platform
    for golden images).
- **Coverage gates:** at least **90%** for `pastello_engine` and **70%** for app
  logic (widgets excluded). CI fails below these thresholds.
- **CI (GitHub Actions)** on every pull request: format, analyze, test,
  coverage, APK build, manifest permission check.
- **Protected `main`:** every change goes through a pull request with green CI,
  including the maintainer's own changes. The maintainer may approve and merge
  alone; a review will be required once there are more maintainers.
- **Dependabot** for pub and GitHub Actions updates.
- **Conventional Commits**, **SemVer** and a **Keep a Changelog** changelog.
- An **ADR** for every accepted architecture decision.

## Consequences

- Contributors get fast, objective feedback from CI.
- Golden images must be regenerated deliberately when the rendering changes on
  purpose.
- Small overhead for the maintainer, who cannot push directly to `main`.

## Alternatives considered

- **No coverage gate:** less friction, but coverage would erode silently.
- **Direct pushes to `main` for the maintainer:** faster, but bypasses CI.
