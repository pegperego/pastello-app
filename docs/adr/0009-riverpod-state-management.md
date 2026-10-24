# 0009. Riverpod for state management

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The editor holds non-trivial state (active tool, color, width, selection,
undo/redo history) and the app needs a way to swap implementations in tests
(for example a fake drawing repository). The choice should be familiar to
Flutter contributors.

## Decision

- Use **Riverpod without code generation**, to keep the entry barrier low for
  contributors.
- **Performance exception:** the stroke in progress does **not** go through
  Riverpod. The live stroke painter listens to a local `ChangeNotifier`, so no
  widgets are rebuilt on every pointer move. Riverpod manages everything else
  (tool, color, width, history, gallery).

## Consequences

- Dependencies are injected through providers and easy to override in tests.
- Contributors need basic Riverpod knowledge; the docs will link to it.

## Alternatives considered

- **`ChangeNotifier` / `provider`:** built in and simple, but tends to get
  messy with the editor's state.
- **Bloc:** very structured, but a lot of boilerplate for an app of this size.
- **Riverpod with code generation:** less boilerplate, but adds `build_runner`
  to the contributor workflow.
