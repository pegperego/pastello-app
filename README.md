# Pastello

*Pastello* is Italian for "crayon".

A simple, offline drawing app for kids on Android tablets: draw freehand, write
text, add stickers and shapes, and keep every creation in a personal gallery.

**Project status:** 🛠️ v1 in progress — see the [v1.0 milestone](https://github.com/pegperego/pastello-app/milestone/1).

## Goals

- **Made for kids (≈ 6–10 years old):** big buttons, icons before words, no
  hidden menus, nothing that can be "broken".
- **Offline first, offline only:** the app works without an internet connection
  and does not request network access at all.
- **Private by design:** no accounts, no ads, no analytics, no tracking. Drawings
  stay on the device.
- **Free and open source:** licensed under GPL-3.0, built only with open source
  dependencies so it can be distributed on F-Droid.

## Planned features

- Freehand drawing (brushes, colors, sizes, eraser, undo/redo)
- Text on the sheet (movable text boxes, kid-friendly fonts and colors)
- Gallery to save, reopen and continue drawings; export as image
- Backgrounds (lined, squared, blank), stickers and shapes

The detailed scope is being defined during the analysis phase.

## Tech stack

- [Flutter](https://flutter.dev) (Dart), targeting Android tablets

## Repository layout

| Path | Language | Content |
|------|----------|---------|
| `app/` | English | The Flutter app |
| `packages/pastello_engine/` | English | The drawing engine: document model, commands, rendering |
| `docs/` | English | Developer and user documentation, architecture decision records |
| `analisi/` | Italian | Analysis notes and the resources used during the analysis |

The `analisi/` folder is written in Italian because it captures the working
notes of the original authors. Everything that contributors need to build, use
and extend the app lives in `docs/` and is written in English.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and
our [Code of Conduct](CODE_OF_CONDUCT.md) before opening an issue or a pull
request.

## License

This project is licensed under the
[GNU General Public License v3.0](LICENSE).
