# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Removed

- The throwaway drawing prototype, now replaced by the app.
