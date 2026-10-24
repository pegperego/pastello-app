# 0003. Offline only, no data collection

- **Status:** accepted
- **Date:** 2026-10-24

## Context

Pastello is used by children. There is no data to synchronize and no reason
for the app to talk to any server. Every network connection would be a
potential privacy risk and would make the app harder to trust and to publish
on F-Droid.

## Decision

- The release build does **not** request the `INTERNET` permission. (Flutter
  adds it to the debug and profile manifests for hot reload; that is fine.)
- Fonts, stickers and backgrounds are **bundled as assets**. Nothing is
  downloaded at runtime (for example, no `google_fonts` fetching).
- No analytics, advertising or crash reporting SDKs.
- A CI check fails the build if the release manifest declares network
  permissions.
- To still get useful bug reports, an **About** page (behind the parental gate)
  shows the app version, device model and Android version, with a
  **"Copy info for bug report"** button. An adult pastes this into a GitHub
  issue; nothing is ever sent automatically.

## Consequences

- Anyone can verify the privacy promise by reading the manifest.
- Crashes are only known when someone reports them; the About page makes
  those reports complete.
- A future updatable content catalog will be the **only** feature allowed to
  use the network. When it is implemented, this decision will be superseded:
  the app will request `INTERNET` for catalog downloads only, started by an
  adult, and the CI check will verify that no other network permission exists.

## Alternatives considered

- **Open source crash reporting (e.g. self-hosted):** better diagnostics, but
  sends data from a child's device and needs a server to maintain.
