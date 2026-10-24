# 0002. Flutter on Android, designed for tablets

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Pastello is a drawing app for children. Its first user draws with her finger
on an Android tablet (Xiaomi Redmi Pad 2 11", the reference device). The app
needs smooth, low-latency custom rendering and a codebase that is easy for
open source contributors to pick up.

## Decision

- Build the app with **Flutter** (stable channel). The exact Flutter version is
  pinned in the project and in CI.
- Target **Android only**, with **Android 10 (API 29)** as the minimum version.
- Design the UI **for tablets**, but keep the app **installable on phones**
  (it works there, without phone-specific optimizations).
- Support **both orientations**. A sheet keeps its shape when the device is
  rotated; only the toolbars move.
- Provide a **quick "lock rotation" button** in the editor that locks the
  current orientation. It is implemented in Dart with
  `SystemChrome.setPreferredOrientations` and the choice is persisted.
- Avoid platform-specific (Kotlin/Java) code unless strictly necessary.

## Consequences

- Flutter's GPU renderer (Impeller) gives full control over the drawing canvas.
- Android 10+ lets the app save images to the shared gallery through MediaStore
  without storage permissions.
- Keeping native code to a minimum makes future ports (iPad, desktop, Linux)
  cheaper.
- Phone layouts are not a goal: contributions that improve them are welcome as
  long as they do not degrade the tablet experience.

## Alternatives considered

- **Native Android (Kotlin + Jetpack Compose):** excellent performance, but
  Android-only forever and a smaller pool of contributors for this kind of app.
- **Blocking installation on phones:** would reduce the potential audience and
  make it harder for contributors to try the app.
- **Landscape only:** simpler layouts, but children often hold the tablet in
  portrait.
