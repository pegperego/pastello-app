# 0017. Child safety

- **Status:** accepted
- **Date:** 2026-10-24

## Context

The app is used by young children, often without an adult watching. They
must not be able to leave the app by accident, reach external content or
trigger actions meant for adults.

## Decision

- No ads and no in-app purchases.
- No accidental exits: the child's area contains no external links and no
  buttons that open the browser, a store or the system settings.
- Everything meant for adults lives in the **parents' page**, behind the
  parental gate: sharing, about, credits, language, trash, backup.
- **External links only in the parents' page** (source code on GitHub, bug
  reporting, privacy policy), as allowed by Google Play's Families policy.
- No home-made kiosk mode. The parents' page includes a **short guide to
  Android's screen pinning**, which keeps the device on Pastello until an
  adult unlocks it.

## Consequences

- The child's experience is self-contained and safe to leave unattended.
- Screen pinning depends on the parent enabling it; the app only explains how.

## Alternatives considered

- **Custom kiosk mode:** would require device-owner privileges or fragile
  workarounds, and Android's screen pinning already solves the problem.
