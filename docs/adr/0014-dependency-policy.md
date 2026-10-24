# 0014. Dependency policy

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Pastello is GPL-3.0 licensed, aims at F-Droid and must stay maintainable by a
small community. Every dependency is code we do not control.

## Decision

### Rules

1. Only licenses compatible with GPL-3.0: MIT, BSD, Apache-2.0 for code;
   SIL OFL for fonts; CC BY / CC BY-SA for images, with attribution.
2. No Google Play Services, Firebase or other proprietary SDKs.
3. Prefer maintained packages with few transitive dependencies. Every new
   dependency must be justified in its pull request.
4. The app has a "Credits & licenses" page (`showLicensePage` plus asset
   attributions).
5. **`pastello_engine` has no third-party dependencies** (Dart/Flutter SDK
   only).

### Approved dependencies (checked on pub.dev on 2026-10-24)

| Purpose | Package | Version | License |
|---|---|---|---|
| State management | `flutter_riverpod` | 3.4.3 | MIT |
| App directories | `path_provider` | 2.1.6 | BSD-3-Clause |
| Save to gallery | `gal` | 2.3.3 | BSD-3-Clause |
| Share | `share_plus` | 13.3.1 | BSD-3-Clause |
| Print | `printing` | 5.15.1 | Apache-2.0 |
| Printable page | `pdf` (added 2026-10-25, same author as `printing`) | 3.13.1 | Apache-2.0 |
| Vector stickers | `flutter_svg` | 2.3.0 | MIT |
| Interface sounds | `audioplayers` (added 2026-10-25) | 6.8.1 | MIT |
| About page | `package_info_plus`, `device_info_plus` | 10.2.2 / 13.3.0 | BSD-3-Clause |
| Links in the parents' page | `url_launcher` (added 2026-10-25) | 6.3.3 | BSD-3-Clause |
| Lints (dev only) | `flutter_lints` | 6.0.0 | BSD-3-Clause |

### Deliberately not used

- `uuid`: random IDs are generated with `Random.secure()`.
- `shared_preferences`: settings are stored in `settings.json` with the same
  atomic writes used for drawings.
- `perfect_freehand`: the stroke outline algorithm is **implemented in the
  engine**, inspired by perfect_freehand (MIT, credited in the code and in the
  app), so it can be tuned for children and integrated with erasures and point
  simplification.

## Consequences

- The engine is fully owned by the project.
- Plugins must not add unexpected permissions; the CI manifest check catches
  this.
- Versions are pinned in `pubspec.lock` and updated deliberately.

## Alternatives considered

- **Using perfect_freehand directly:** less code, but the core of the stroke
  look would depend on an external package.
