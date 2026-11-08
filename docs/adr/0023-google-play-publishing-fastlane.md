# 0023. Publishing to Google Play with fastlane

- **Status:** accepted
- **Date:** 2026-11-08

## Context

Releasing 1.0 and 1.1 on Google Play meant downloading the AAB from the
workflow run, uploading it by hand to internal testing and copying the
release notes, texts and screenshots into Play Console. The store listing
already lives in the repository (`fastlane/metadata/android/`), in the layout
fastlane reads.

## Decision

- **fastlane** (MIT, Ruby) uploads to Google Play through the Google Play
  Developer API. It is release tooling only: pinned in `Gemfile.lock`, never
  shipped in the app. Usage statistics are turned off (`opt_out_usage`).
- **Lanes** (`fastlane/Fastfile`):
  - `internal`: the AAB to internal testing, with its release notes
    (`changelogs/<version code>.txt`) and the store listing; images and
    screenshots are uploaded only when they changed;
  - `production`: promotes a version from internal testing to production;
  - `listing`: only the store texts, images and screenshots;
  - `check`: checks the key, changing nothing.
- **CI:** after the GitHub Release, the Release workflow uploads the AAB to
  internal testing. Production stays a deliberate step after checking the
  internal build on a real device: the **Google Play** workflow, started by
  hand, promotes a version or updates only the listing.
- **Key:** a Google Cloud service account with access to Pastello only, with
  the permissions to release to testing and production and to edit the store
  listing. Its JSON key is the `PASTELLO_PLAY_SERVICE_ACCOUNT` secret of a
  separate `google-play` environment, so the signing key and the Play key are
  never in the same job. Locally, `PASTELLO_PLAY_KEY` points to the key file,
  kept out of the repository.

## Consequences

- A release is: merge the version bump, push the tag, check the internal
  build, start the promotion.
- The store listing follows the repository: changes made only in Play
  Console are overwritten by the next upload.
- A leaked Play key would allow publishing a build signed with our upload
  key only if the signing key leaked too; on its own it allows changing the
  listing and the tracks. The key can be revoked in Google Cloud.

## Alternatives considered

- **Manual uploads in Play Console:** no new tooling, but slow and easy to
  get wrong (notes, screenshots, version).
- **A GitHub Action for the Play API** (for example
  `r0adkll/upload-google-play`): uploads the AAB, but not the listing in
  fastlane's layout, which the repository already uses.
- **Uploading straight to production:** faster, but skips the check on a
  real device that the release checklist asks for.
