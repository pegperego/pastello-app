# 0013. Localization and keyboard privacy

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The first user speaks Italian; the open source community mostly works in
English. Children read little, so the UI should rely on icons. When a child
types text on a drawing, the system keyboard may learn and store what she
writes.

## Decision

- Use Flutter's official localization (`flutter_localizations` and ARB files)
  with **Italian and English** from v1. New languages can be contributed by
  adding an ARB file.
- The app **follows the system language**, falling back to **English**. The
  parents' page allows **forcing a language**.
- The UI uses **as little text as possible**; text is mostly found in the
  parents' page.
- **Keyboard privacy:** every text field sets
  `enableIMEPersonalizedLearning: false`, asking the keyboard to work in
  incognito mode (no learning or storing of what the child types).
  Autocorrect and suggestions stay enabled because they help young writers.

## Consequences

- Every user-visible string goes through the localization files, including
  in the first prototype.
- The incognito flag is a request to the keyboard: well-behaved keyboards
  honor it, but the app cannot enforce it.

## Alternatives considered

- **Italian only:** simpler at first, but a barrier for the community.
- **Disabling autocorrect and suggestions:** more private, but makes writing
  harder for a child who is learning to spell.
