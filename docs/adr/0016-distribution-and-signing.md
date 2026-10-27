# 0016. Distribution channels and signing

- **Status:** accepted; the Google Play signing key is superseded by
  [0019](0019-google-play-signing-key.md)
- **Date:** 2026-10-24

## Context

Pastello should reach families easily (Google Play) while staying true to
free software distribution (GitHub Releases, F-Droid). Users should be able to
move between channels without reinstalling the app and losing their drawings.

## Decision

### Channels

1. **GitHub Releases** from v1: a signed APK for every version.
2. **Google Play** from v1 (AAB format), in the **Families** program.
3. **F-Droid** after the first stable version, using a reproducible build.

### Signing

- CI signs the APK and the AAB when a version tag (`vX.Y.Z`) is pushed, using
  a keystore stored encrypted in GitHub Secrets.
- **One signing key for all channels.** On Google Play we use Play App Signing
  with **our own uploaded key** instead of a Google-generated one, so APKs
  from GitHub, Google Play and F-Droid (reproducible build with our signature)
  can update each other.
- The maintainer keeps an **offline backup** of the key. Losing it means the
  app can no longer be updated.
- The key is never committed to the repository.

### Google Play requirements for v1

To be re-checked at publishing time, as Play policies change often:

- the maintainer's existing developer account is used;
- release track: **internal testing → production** (the account already
  publishes other apps this way, so the closed testing requirement for new
  personal accounts does not apply);
- **Families** policy compliance: children as target audience, no ads, no
  uncertified SDKs;
- a public **privacy policy** (`docs/privacy-policy.md`, published with GitHub
  Pages) stating that no data is collected;
- **Data safety** form: no data collected or shared;
- **content rating** questionnaire (IARC);
- target API level kept up to date with Play's yearly requirements.

## Consequences

- Families can install Pastello from the store they already use.
- A leaked CI secret would allow signing malicious updates: the secret is
  limited to the release workflow, which only runs on version tags.

## Alternatives considered

- **Google-generated Play signing key:** simpler, but Play builds could not
  update GitHub or F-Droid builds and vice versa.
- **Manual signing on the maintainer's machine:** safer key custody, but slower
  and error-prone releases.
