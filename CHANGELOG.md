# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Parents' page: export all the drawings to a `.zip` file, saved where the
  parent chooses, and import them back, for example to move to a new tablet
  or to the Google Play version. Importing never replaces or duplicates a
  drawing.
- Magic brushes, next to the rainbow: the highlighter (wide and
  see-through, it does not get darker going over it again), the neon
  (a light line with a glow of the chosen color, best on dark paper),
  glitter, stars, spray and watercolor. The sparkles, stars and dots stay
  exactly where they were when the drawing is opened again. Drawings that
  use them need this version to open.
- Paint bucket: a tap fills the area closed by lines and shapes with the
  chosen color, under the lines, and small gaps in the outline are closed
  so the color does not spill out. A tap on a line changes its color.
  Fills can be erased, moved with the lasso and undone.
- Coloring pages: a "Coloring pages" button next to the "+" opens a grid
  of drawings to color; a tap starts a new sheet with that outline. The
  outline stays above the colors, cannot be erased or moved, and stops the
  paint bucket. A first set of three pages (star, house, fish), drawn by
  the project and released under CC0.

### Changed

- The tools are grouped into categories in one column (one row in
  portrait): each button shows the last tool used in it, and the Draw
  category opens a small flyout with its tools, which closes by itself.
  In portrait the widths fold into one button.

## [1.0.0] - 2026-10-25

First release.

### Added

- Repository structure, community guidelines and analysis workspace.
- Drawing engine (`packages/pastello_engine`) validated by a prototype.
- App scaffold: gallery with the "+" button, empty editor, Italian and
  English, design theme and bundled fonts.
- Editor: pencil, marker, brush, crayon, rainbow and eraser; 12 colors plus
  40 more; 4 widths remembered per tool; undo, redo and clear sheet;
  rotation lock and left-handed layout, remembered between sessions.
- Drawings are saved automatically (also when leaving the editor or when the
  app goes to the background), with their undo history; empty sheets are not
  saved.
- Gallery with thumbnails and relative dates; duplicate and delete; trash
  that keeps drawings for 30 days and can be emptied behind the parental
  gate.
- Drawings are excluded from cloud backups but follow the child to a new
  device with a direct transfer.
- Texts on the sheet: tap with the Text tool to write (the field stays above
  the keyboard), then move, resize, rotate, recolor, change font
  (Andika, Playwrite IT Moderna, Fredoka, Comic Neue), edit or delete.
  The eraser never erases texts.
- Stickers: 220 Fluent Emoji (MIT) in 8 categories, delivered as content
  packs; choose one in the panel, tap the sheet to place it, then move,
  resize, rotate, duplicate or delete it. Missing stickers show a "?".
- Shapes: circle, square, triangle, star, heart, line and arrow, outlined or
  filled, drawn by dragging with the selected color and width; they snap to
  perfect circles, squares and 0°/45°/90° lines with a light haptic tick.
- Select tool: draw a lasso around part of the drawing, strokes included,
  then move, resize, rotate, duplicate or delete it in one undo step; a tap
  on a stroke's line selects that stroke alone. Erased parts follow the
  strokes they belong to. Tools now sit on two columns in landscape.
- Paper: plain, lines, big squares, small squares or dots, on white, pastel
  or dark paper, from the "Paper" button; undoable. The eraser brings the
  lines and squares back.
- Parents' page behind the parental gate: language, left-handed, sounds and
  vibration settings; empty the trash; a guide to Android screen pinning;
  version and device info to copy into a bug report; links to the source
  code, issues and the privacy policy; credits and licenses.
- Privacy policy (English and Italian) in docs/privacy-policy.md.
- Save to the tablet's gallery, print (fitted on an A4 page) and share,
  from the gallery options and from the editor; sharing needs the parental
  gate. Images use the screen's native resolution.
- Short sounds (a "pop" for stickers, a "whoosh" for deleting, a "ding"
  for saving and printing), synthesized by the project and released as CC0;
  never while drawing. Light vibration on tool changes and shape snapping.
  Both can be turned off in the parents' page. The chosen tool jumps a
  little; animations follow Android's "remove animations".
- App icon: the smiling crayon as an Android adaptive icon (with a themed
  monochrome layer), the mascot in the gallery and drawn action icons.
- Signed releases from version tags (APK on GitHub Releases, AAB for
  Google Play) and the store listing in Italian and English.
- On a phone held upright the editor's top bar packs its buttons closer and
  scrolls, so none of them is cut off.

### Removed

- The throwaway drawing prototype, now replaced by the app.

[Unreleased]: https://github.com/pegperego/pastello-app/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/pegperego/pastello-app/releases/tag/v1.0.0
