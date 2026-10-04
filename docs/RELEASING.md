# Release guide

> [Polska wersja instrukcji](RELEASING.pl.md)

MenuBarFold is distributed directly as a notarized DMG. A public release must use a **Developer ID Application** certificate, Hardened Runtime, a secure timestamp, Apple notarization, and a stapled ticket. An Apple Development or ad-hoc signature is sufficient only for local development.

The automated path is `.github/workflows/release.yml`. It runs on GitHub's `xcode-27` macOS runner and publishes a universal `arm64 + x86_64` disk image to GitHub Releases.

## Why DMG instead of PKG

Both formats need Developer ID signing and Apple notarization for a normal Gatekeeper experience. A flat installer package would additionally require a **Developer ID Installer** certificate, while the application inside it would still need its **Developer ID Application** signature.

Apple recommends installer packages when a product has several components, must place files in several fixed locations, or needs custom installation code. MenuBarFold is one self-contained app copied to `/Applications`, so a drag-and-drop DMG has fewer credentials and moving parts, does not need an installer UI, and is easier to remove. If the product later gains a privileged helper or files outside its app bundle, reconsider a PKG at that point.

The GitHub workflow authenticates notarization with a team App Store Connect API key. A regular Apple Account by itself is not enough: the Developer ID certificate is available through Apple Developer Program membership, and the notary credentials must belong to that developer team.

## What the release workflow produces

For a tag such as `v0.2.0`, a successful workflow publishes:

```text
MenuBarFold-0.2.0.dmg
MenuBarFold-0.2.0.dmg.sha256
```

The version without the leading `v` becomes `CFBundleShortVersionString`. The GitHub Actions run number becomes the numeric `CFBundleVersion`. The About screen reads the version directly from the built bundle.

The DMG contains:

- a release build of `MenuBarFold.app`;
- both `arm64` and `x86_64` slices;
- the stable bundle identifier `io.github.menubarfold.MenuBarFold`;
- an `Applications` shortcut for drag-and-drop installation;
- a Developer ID signature with Hardened Runtime and timestamp;
- an Apple notarization ticket stapled to the disk image.

Do not change the bundle identifier after publishing the first release. Accessibility authorization and macOS trust are tied to the application's identity and signature.

## One-time Apple setup

### 1. Create a Developer ID Application certificate

Join the Apple Developer Program and create a [Developer ID Application certificate](https://developer.apple.com/help/account/certificates/create-developer-id-certificates). The certificate must be present in Keychain Access together with its private key.

Export it from **Keychain Access → My Certificates** as a password-protected `.p12` file. Export the certificate and private key together.

This workflow does not need a provisioning profile because MenuBarFold is a directly distributed macOS application with no private entitlements. App Sandbox must remain disabled.

### 2. Create a team App Store Connect API key

In **App Store Connect → Users and Access → Integrations → Team Keys**, create a team API key that can use the notary service. Download the `.p8` file immediately; Apple allows it to be downloaded only once.

Use a **team key**, not an individual key. Apple states that individual App Store Connect keys cannot use `notarytool`.

Record:

- the Key ID;
- the Issuer ID;
- the complete contents of the downloaded `.p8` file.

### 3. Add GitHub Actions secrets

Open the GitHub repository and go to **Settings → Secrets and variables → Actions → New repository secret**.

Create these six secrets:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64 representation of the exported Developer ID `.p12` file |
| `P12_PASSWORD` | Password used while exporting the `.p12` file |
| `KEYCHAIN_PASSWORD` | A new random password used only for the temporary CI keychain |
| `APP_STORE_CONNECT_API_KEY_ID` | Team API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Team API issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | Complete text of the `.p8` private key |

Create the certificate value on macOS with:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Paste the clipboard into `BUILD_CERTIFICATE_BASE64`. Paste the `.p8` file as text into `APP_STORE_CONNECT_API_KEY_P8`; do not Base64-encode that key.

Never commit the certificate, private key, passwords, or generated secret values. GitHub's certificate-import procedure also recommends encrypted Actions secrets and an isolated temporary keychain.

### 4. Check repository Actions permissions

The workflow declares `contents: write` so it can create a GitHub Release. If an organization policy forces read-only tokens, allow read/write workflow permissions under **Settings → Actions → General → Workflow permissions**.

Optionally protect public releases with a GitHub `release` environment and required reviewers. If you do, add `environment: release` to the `release` job and move the six secrets to that environment.

## Publish a release

### 1. Prepare the source

Before tagging:

1. update `CHANGELOG.md`;
2. run the full tests;
3. run the installed application on macOS 27;
4. verify the regular-hidden and always-hidden flows on a notched display and an external display;
5. confirm the working tree is clean.

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --verify
git status --short
```

### 2. Create and push an annotated tag

Release tags must match `vMAJOR.MINOR.PATCH` exactly:

```sh
git tag -a v0.2.0 -m "MenuBarFold 0.2.0"
git push origin v0.2.0
```

Pushing the tag starts **Release DMG**. The workflow refuses branch names, lightweight version strings without `v`, and versions containing non-numeric components.

### 3. Download the result

After the workflow succeeds, open the repository's **Releases** page. The release contains the DMG and checksum. The same files are also retained as a workflow artifact.

If publishing fails after the draft release is created, fix the cause and use **Actions → Release DMG → Run workflow** with the existing tag. The workflow replaces assets of an existing mutable release and publishes the draft when all steps succeed.

## What the workflow verifies

The release job:

1. checks that the requested tag exists and matches `vMAJOR.MINOR.PATCH`;
2. runs the Swift test suite;
3. imports the `.p12` certificate into a temporary keychain;
4. confirms that the imported identity is a Developer ID Application certificate;
5. builds a release application for `arm64` and `x86_64`;
6. validates both architecture slices with `lipo`;
7. verifies the application and DMG signatures with `codesign`;
8. submits the DMG with `xcrun notarytool --wait`;
9. staples and validates the ticket;
10. runs a Gatekeeper assessment with `spctl`;
11. creates the SHA-256 checksum;
12. uploads the assets and removes the temporary signing material.

The job intentionally fails rather than publishing an ad-hoc or Apple Development-signed public artifact.

## Local packaging check

You can test bundle creation and the DMG layout without a Developer ID certificate or notarization:

```sh
REQUIRE_DEVELOPER_ID=0 \
SKIP_NOTARIZATION=1 \
SWIFT_BUILD_ARCHS=arm64 \
./script/package_release.sh 0.2.0
```

This produces `dist/MenuBarFold-0.2.0.dmg`, but it is **not a public release**. The script prints a warning and must not upload that image to GitHub Releases.

To exercise the complete production script locally, install a Developer ID identity and provide a team API key:

```sh
export NOTARYTOOL_KEY="/secure/path/AuthKey_KEYID.p8"
export NOTARYTOOL_KEY_ID="KEYID"
export NOTARYTOOL_ISSUER_ID="ISSUER-UUID"
./script/package_release.sh 0.2.0
```

## Manual validation of a downloaded release

```sh
shasum -a 256 -c MenuBarFold-0.2.0.dmg.sha256
diskutil image info MenuBarFold-0.2.0.dmg
xcrun stapler validate MenuBarFold-0.2.0.dmg
spctl --assess --type open \
  --context context:primary-signature \
  --verbose=4 \
  MenuBarFold-0.2.0.dmg
```

After mounting the image, also inspect the application:

```sh
codesign --verify --deep --strict --verbose=2 \
  "/Volumes/MenuBarFold 0.2.0/MenuBarFold.app"
codesign -dvvv "/Volumes/MenuBarFold 0.2.0/MenuBarFold.app"
lipo -archs "/Volumes/MenuBarFold 0.2.0/MenuBarFold.app/Contents/MacOS/MenuBarFold"
```

Expected architectures are `arm64 x86_64`, and the signing authority must start with `Developer ID Application:`.

## Functional release checklist

Test the downloaded DMG on a clean macOS 27 account:

- DMG opens and the Applications shortcut works;
- Gatekeeper accepts the application without a bypass;
- first-run Accessibility onboarding works;
- a copy outside `/Applications` refuses to hide icons safely;
- the folded state shows one main `<` control;
- the main control reveals regular hidden icons, `|`, and the second `<`;
- the second control reveals and hides always-hidden icons without moving itself;
- moving `|` and ending Arrange mode reclassifies icons correctly;
- repeated folding preserves the Command-dragged order;
- behavior is consistent on a notched MacBook display and non-notched external displays;
- connecting, disconnecting, and vertically arranging displays refreshes safely;
- auto fold, hover reveal, global shortcut, and launch at login work;
- microphone and camera activity releases the restriction;
- English and Polish layouts fit;
- revoking Accessibility fails open and shows the full menu bar.

## Common failures

`A Developer ID Application certificate is required`

: The imported `.p12` contains an Apple Development certificate, lacks the private key, or was exported incorrectly.

`Missing APP_STORE_CONNECT_API_* secret`

: One of the team API key values is absent. An individual API key cannot replace it for `notarytool`.

`Invalid` from `notarytool`

: Open the submission log shown by `notarytool`. Typical causes are the wrong certificate type, missing Hardened Runtime, an invalid timestamp, or accidentally enabled debug entitlements.

`Resource fork, Finder information, or similar detritus not allowed`

: A file in the app bundle contains extended metadata. Recreate the bundle from a clean checkout instead of modifying the packaged app in Finder.

Gatekeeper accepts the DMG but Accessibility resets after every update

: Confirm that the bundle identifier and Developer ID identity did not change between releases. Users should replace the application in `/Applications`, not run it directly from the mounted DMG.

## References

- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [GitHub: Installing an Apple certificate on macOS runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [GitHub: Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
