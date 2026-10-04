# Release guide

> [Polska wersja instrukcji](RELEASING.pl.md)

MenuBarFold uses a no-cost GitHub release flow. It builds an ad-hoc-signed DMG and does not require an Apple account, Apple Developer Program membership, signing secrets, or notarization credentials.

This trade-off must stay explicit: Apple does not verify the developer identity or scan this artifact through the notary service. Gatekeeper blocks its first launch until the user creates a per-app **Open Anyway** exception. Never tell users that this free artifact is notarized or Apple-verified.

## Why DMG instead of PKG

A PKG does not avoid the paid Apple requirement. A trusted DMG needs a **Developer ID Application** certificate; a trusted PKG additionally needs **Developer ID Installer**, while its contained app still needs **Developer ID Application**.

Apple recommends an installer package when software has several components, writes to several fixed locations, or runs custom installation code. MenuBarFold is one self-contained app copied to `/Applications`, so a drag-and-drop DMG is simpler to install and remove.

## What the free workflow produces

For a tag such as `v0.2.0`, `.github/workflows/release.yml` publishes:

```text
MenuBarFold-0.2.0.dmg
MenuBarFold-0.2.0.dmg.sha256
```

The tag without `v` becomes `CFBundleShortVersionString`; the GitHub Actions run number becomes `CFBundleVersion`. The DMG contains:

- `MenuBarFold.app` and an `/Applications` shortcut;
- a native `arm64` executable for Apple silicon;
- the stable bundle identifier `io.github.menubarfold.MenuBarFold`;
- Hardened Runtime and an ad-hoc code signature;
- no Developer ID certificate and no notarization ticket.

The checksum detects an incomplete or changed download when compared with the release checksum. It is not an independent proof of publisher identity because both files come from the same GitHub Release.

## Cost and permission trade-offs

An ad-hoc signature identifies exactly one build. A new version changes its code-directory hash, so macOS can treat it as a new application for security decisions. Users should expect that an update may require:

1. **Open Anyway** again;
2. removing the previous MenuBarFold entry from Accessibility;
3. adding or enabling the new `/Applications/MenuBarFold.app` entry.

For the maintainer's own Mac, `./script/build_and_run.sh --verify` is preferable. It uses the first installed local code-signing identity, such as an Apple Development certificate, and keeps using that identity while it remains available. This is not a trusted public distribution signature.

Do not work around these limitations by disabling Gatekeeper globally. The documented path creates an exception only for MenuBarFold.

## Repository setup

The free workflow needs no Apple-related GitHub secrets. It only needs the default `GITHUB_TOKEN` with permission to create releases. The workflow declares:

```yaml
permissions:
  contents: write
```

If organization policy forces read-only workflow tokens, enable read/write workflow permissions under **Settings → Actions → General → Workflow permissions**.

## Publish a release

### 1. Validate the source

Before tagging:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --verify
git status --short
```

Also test both hidden sections on macOS 27, including a notched display and an external display. Update `CHANGELOG.md` and make sure the working tree is clean.

### 2. Create and push an annotated tag

The tag must match `vMAJOR.MINOR.PATCH` exactly:

```sh
git tag -a v0.2.0 -m "MenuBarFold 0.2.0"
git push origin v0.2.0
```

Pushing the tag starts **Release DMG**. The workflow can also be rerun from **Actions → Release DMG → Run workflow** with an existing tag.

### 3. Download the result

After the job succeeds, GitHub Releases contains the DMG and `.sha256` file. The same files are retained as a workflow artifact named `MenuBarFold-<version>-unnotarized`.

The release notes include a warning explaining that the build is ad-hoc signed and requires manual approval.

## What the workflow verifies

The release job:

1. validates the tag and checks that it exists;
2. runs the Swift tests;
3. builds a Release app for `arm64`;
4. enables Hardened Runtime;
5. creates an ad-hoc signature with `codesign -s -`;
6. validates the `arm64` architecture with `lipo`;
7. verifies the application and DMG signature integrity with `codesign`;
8. creates the DMG and SHA-256 checksum;
9. publishes both files with the unnotarized-build warning.

This checks build integrity. It does not replace Apple notarization or make Gatekeeper trust the publisher.

## Local packaging

The default command follows the free release path:

```sh
SWIFT_BUILD_ARCHS="arm64" \
CODE_SIGN_IDENTITY="-" \
./script/package_release.sh 0.2.0
```

The result appears in `dist/`. The script prints a warning that manual Gatekeeper approval is required.

macOS 27 runs on Apple silicon Macs. Xcode 27 deprecates `x86_64` when the minimum deployment target is macOS 27, so the release does not include an unused Intel slice.

## Installation of a downloaded release

1. Optionally verify the checksum in the folder containing both downloads:

   ```sh
   shasum -a 256 -c MenuBarFold-0.2.0.dmg.sha256
   ```

2. Open the DMG and drag MenuBarFold to Applications.
3. Try to open `/Applications/MenuBarFold.app`; macOS blocks it.
4. Close the warning rather than moving the app to Trash.
5. Open **System Settings → Privacy & Security**, scroll to **Security**, and click **Open Anyway** for MenuBarFold.
6. Confirm **Open**, then grant Accessibility access.

Do not use `spctl --master-disable`, and do not advise users to disable Gatekeeper for the whole Mac.

## Functional release checklist

- checksum verification succeeds;
- the DMG contains MenuBarFold and an Applications shortcut;
- the release notes clearly say the build is unnotarized;
- **Open Anyway** launches the installed copy;
- first-run Accessibility onboarding works;
- the folded state shows one main `<` control;
- the main control reveals regular hidden icons, `|`, and the second `<`;
- the second control reveals and hides always-hidden icons without moving;
- repeated folding preserves the Command-dragged order;
- notched and non-notched displays behave consistently;
- auto fold, hover reveal, shortcut, and launch at login work;
- English and Polish layouts fit;
- revoking Accessibility fails open and shows the full menu bar.

## Optional trusted release in the future

The packaging script retains a strict Developer ID mode. It requires paid Apple Developer Program access, a **Developer ID Application** identity, and team notarization credentials:

```sh
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export REQUIRE_DEVELOPER_ID=1
export SKIP_NOTARIZATION=0
export NOTARYTOOL_KEY="/secure/path/AuthKey_KEYID.p8"
export NOTARYTOOL_KEY_ID="KEYID"
export NOTARYTOOL_ISSUER_ID="ISSUER-UUID"
./script/package_release.sh 0.2.0
```

That mode submits the DMG, waits for Apple, staples the ticket, and runs a Gatekeeper assessment. It is intentionally not used by the default GitHub workflow.

## References

- [Apple: Safely open apps on your Mac](https://support.apple.com/en-us/102445)
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
- [Apple: Code Signing Requirement Language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html)
- [GitHub: Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
