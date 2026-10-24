# Pastello app

The Flutter app. It uses the drawing engine in
[`packages/pastello_engine`](../packages/pastello_engine).

```sh
flutter run            # debug, on a tablet or emulator
flutter run --profile  # to judge performance
flutter test --coverage
```

Code is organized by feature (`lib/src/features/`), with shared code in
`lib/src/core/` and the theme in `lib/src/app/`
([ADR 0012](../docs/adr/0012-workspace-app-and-engine.md)). User-visible
strings live in `lib/src/l10n/*.arb`
([ADR 0013](../docs/adr/0013-localization-and-keyboard-privacy.md)).
