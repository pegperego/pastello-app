# Releasing Pastello

How a version goes from `main` to GitHub Releases and Google Play
(ADR 0016). Only maintainers can do this.

## One-time setup

### The signing key

One key signs every channel. It was created with:

```sh
keytool -genkeypair -storetype PKCS12 -keystore pastello-release.jks \
  -alias pastello -keyalg RSA -keysize 4096 -validity 10950 \
  -dname "CN=Pastello, O=Pastello project"
```

- Keep **at least two offline backups** of the keystore and its password
  (for example an encrypted USB drive and a password manager). Losing them
  means Pastello can no longer be updated, on any channel.
- Never commit it: `*.jks`, `*.keystore` and `key.properties` are ignored.
- To build a signed release locally, put a `key.properties` in
  `app/android/` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`).

### GitHub

1. **Environment:** Settings → Environments → New environment `release`.
   Under "Deployment branches and tags" choose "Selected branches and tags"
   and add the tag rule `v*.*.*`.
2. **Secrets** of the `release` environment:

   | Secret | Value |
   |---|---|
   | `PASTELLO_KEYSTORE_BASE64` | `base64 -w0 pastello-release.jks` |
   | `PASTELLO_KEYSTORE_PASSWORD` | the keystore password |
   | `PASTELLO_KEY_ALIAS` | `pastello` |
   | `PASTELLO_KEY_PASSWORD` | the key password (same as the keystore's) |

3. **Pages:** Settings → Pages → Deploy from a branch → `main`, `/docs`. The
   privacy policy is then at
   <https://pegperego.github.io/pastello-app/privacy-policy.html>.

### Google Play

1. Create the app: default language Italian, app, free.
2. **App signing:** when uploading the first bundle, choose to use your own
   key instead of a Google-generated one, and follow the console's
   instructions (it asks to encrypt the key with Google's PEPK tool). The
   same key is also the upload key.
3. Fill in the **App content** section:
   - Privacy policy: the GitHub Pages URL above.
   - Ads: no ads.
   - App access: everything is available without restrictions (the parents'
     page only asks for an addition, whose answer is shown on screen).
   - Content rating (IARC): category "All other app types"; no violence, no
     user interaction, no sharing of location, no purchases. Sharing images
     goes through Android's share sheet behind a parental check.
   - Target audience: ages 5 and under, 6–8, 9–12. The app is not designed to
     appeal to other ages, so it joins the **Families** program.
   - Data safety: no data collected, no data shared. The app has no internet
     permission.
   - Government app, financial features, health: no.
4. **Store listing:** texts and images are in `fastlane/metadata/android/`
   (`it-IT` and `en-US`): title, short and full description, icon, feature
   graphic, phone and 10-inch tablet screenshots. The category is "Art &
   Design"; contact email `pastello.app@proton.me`.

## Every release

1. Update `version:` in `app/pubspec.yaml`: `X.Y.Z+N`, where `N` grows by one
   every release (it is the Android version code).
2. Move the `[Unreleased]` notes of `CHANGELOG.md` under a new
   `## [X.Y.Z] - YYYY-MM-DD` section and update the links at the bottom.
3. Add `fastlane/metadata/android/<locale>/changelogs/N.txt` (at most 500
   characters) in both languages.
4. Merge to `main` through a pull request, then tag the merge commit:

   ```sh
   git tag -a vX.Y.Z -m "Pastello X.Y.Z"
   git push origin vX.Y.Z
   ```

5. The **Release** workflow checks that the tag matches the version, builds
   and signs the APK and the AAB, checks the permissions and the signature,
   and publishes a GitHub Release with the APK and its SHA-256.
6. Download the AAB from the workflow run's artifacts and upload it to Google
   Play: **internal testing** first, then, once checked on a real device,
   promote it to **production**.

## Checks on a real device before production

- Install from the internal testing track and open an existing drawing.
- The icon is right in the launcher and in Google Kids Space (a sideloaded
  build showed a generic icon there; it should come from Play).
- Save to gallery, print and share work.
