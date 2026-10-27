# 0019. Google-generated signing key on Google Play

- **Status:** accepted
- **Date:** 2026-10-27

## Context

ADR 0016 planned one signing key for every channel, uploading our own key to
Play App Signing. When the app was created on Google Play, the maintainer
preferred to let Google generate and keep the app signing key: if our key is
ever lost, Google can reset the upload key and the Play app can still be
updated. Most families are expected to install Pastello from Google Play.

## Decision

- On Google Play, the **app signing key is generated and kept by Google**
  (Play App Signing).
- **Our key** (`pastello-release.jks`) is the Play **upload key**: CI signs
  the AAB with it, as before.
- GitHub Releases (and F-Droid later) keep shipping APKs signed with our key.
- This replaces the "one signing key for all channels" part of ADR 0016; the
  rest of ADR 0016 still holds.

## Consequences

- Pastello installed from Google Play and Pastello installed from a GitHub
  APK have different signatures: one cannot update the other. Moving between
  them needs an uninstall, which deletes the drawings, so users must save the
  drawings they want to keep first.
- Losing our key no longer stops Play updates: the upload key can be reset
  through Play Console support. It would still stop GitHub and F-Droid
  updates, so the offline backups of the key remain necessary.
- Nothing changes in the build: the release workflow and the signing
  configuration stay the same.

## Alternatives considered

- **Our own key on Play (ADR 0016):** builds from every channel update each
  other, but losing the key would end updates everywhere, Play included.
