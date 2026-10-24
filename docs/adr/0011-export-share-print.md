# 0011. Export, share and print

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Children want to keep their drawings, show them to relatives and print them.
Anything that sends a drawing off the device should involve an adult.

## Decision

- **Export to gallery:** PNG saved to the device gallery through MediaStore
  (no storage permission needed on Android 10+). Resolution is the screen's
  **native resolution** in the sheet's orientation (about 2560×1600 on the
  reference Redmi Pad 2). The vector model allows a future "high quality"
  option. Exporting is **free**: the child can do it alone.
- **Share:** uses Android's system share sheet and is protected by the
  **parental gate** (a random two-digit addition solved with a numeric keypad),
  implemented as a reusable `ParentalGate` component.
- **Print (v1):** a "Print" button opens Android's print system (home printer
  or "Save as PDF") through the `printing` package. The sheet is scaled to fit
  the page, keeping its proportions. Printing is **free**, without the parental
  gate, because it stays at home. Printing goes through Android's print
  service, so the app does not need the `INTERNET` permission; the CI manifest
  check enforces this.

## Consequences

- The child can save and print her work on her own.
- Nothing leaves the device without an adult solving the gate.
- One more dependency (`printing`), to be checked against the dependency
  policy.

## Alternatives considered

- **Gate on every export:** safer, but saving to the gallery keeps the drawing
  on the device, so the gate would only add friction.
- **Printing after v1:** smaller first release, but printing drawings is a key
  use case for a child.
