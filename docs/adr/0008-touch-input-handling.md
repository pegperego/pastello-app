# 0008. Touch input handling

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The first user draws with her finger on a tablet without a stylus. Young
children often rest a second finger or the palm on the screen by accident, and
multi-finger gestures are easy to trigger unintentionally.

## Decision

- Input is read from Flutter `PointerEvent`s, which distinguish `touch` and
  `stylus` and expose pressure.
- **One finger draws** with the active tool. There is no zoom or pan in v1;
  sheet coordinates are already independent from screen coordinates, so zoom
  can be added later.
- **The first pointer wins:** other pointers (a second finger, the palm) are
  ignored while a stroke is in progress.
- A **single tap leaves a dot**.
- **No multi-finger gestures** in v1 (such as two-finger tap to undo). Undo
  and redo are large, always-visible buttons. Gestures may come later as an
  opt-in setting.
- **Width:** the user picks a **base width** from a few presets (shown as dots
  of different sizes). Because a finger has no pressure, **stroke speed**
  modulates the width around that base. Which tools use variable width and
  which use a constant width is defined in the functional analysis.
- **Stylus support** (real pressure, stylus-only mode with palm rejection) is
  postponed after v1. Capacitive styluses behave like a finger and work from
  v1.

## Consequences

- Accidental touches do not create stray marks or trigger actions.
- Adding stylus pressure later only changes how width is computed, not the
  input pipeline.

## Alternatives considered

- **Two-finger undo / three-finger redo:** fast for adults, but too easy to
  trigger by mistake for children.
