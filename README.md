# MenuBarFold

MenuBarFold is a native macOS 27 utility for keeping a busy menu bar under control. You decide which third-party icons remain visible, which appear when the main section is expanded, and which stay behind a separate always-hidden control.

The app is written in Swift, SwiftUI, and AppKit. English is the default language and Polish is included.

> [Polska wersja README](docs/README.pl.md)

## Download and install

1. Download the latest `MenuBarFold-<version>.dmg` from [GitHub Releases](../../releases/latest).
2. Open the DMG and drag **MenuBarFold** to the **Applications** shortcut.
3. Launch `/Applications/MenuBarFold.app`.
4. Grant access in **System Settings → Privacy & Security → Accessibility**.
5. Choose **Arrange Icons** and set up the three menu bar zones.

The release DMG is signed with Developer ID, notarized by Apple, and accompanied by a SHA-256 checksum. MenuBarFold must remain in the system `/Applications` folder; icon filtering is intentionally disabled for copies launched elsewhere.

A DMG is used instead of a PKG because MenuBarFold is one self-contained application. Both formats require notarization, while a PKG would add a separate Developer ID Installer certificate without improving this installation flow. See the [release guide](docs/RELEASING.md) for the rationale and credentials.

## Current menu bar behavior

Arrange the menu bar while holding Command:

```text
always-hidden icons   |   regular hidden icons   <   always-visible icons
```

The controls then behave as follows:

| State | Visible controls and icons |
| --- | --- |
| Folded | Only the main `<` button and always-visible icons |
| Regular section open | Regular hidden icons, `|`, the second `<` button, and the main `>` button |
| Always-hidden section open | Both hidden sections are visible; the second button becomes `>` |
| Main `>` pressed | Both hidden sections fold and only the main `<` remains |

The second button deliberately stays in one position when the always-hidden section opens. Moving it to the end of the expanded icons would require macOS to rearrange status items after every click.

MenuBarFold no longer forces macOS's native `«` overflow control and does not create width-inflating spacer items. The main button, separator, and second button keep stable status-item identities for the lifetime of the app. This greatly reduces app-induced reordering and works consistently on a notched MacBook display, external non-notched displays, and mixed multi-display layouts.

After upgrading from an older build that used overflow spacers, enter **Arrange Icons** once and restore the preferred order. Subsequent folding does not recreate the controls.

## Features

- Separate regular-hidden and always-hidden sections.
- A main arrow that always remains available while the bar is folded.
- A second fixed arrow that appears only after the regular section opens.
- Command-drag arrangement with a visible `|` section boundary.
- Auto fold with a configurable delay.
- Optional reveal on menu bar hover.
- Global shortcut presets.
- Launch at login through `SMAppService`.
- Per-display position projection for multiple monitors, with and without a notch.
- Safe refresh after display, wake, app launch, and app termination changes.
- Microphone and camera protection: the complete menu bar is restored while capture is active.
- Native settings, Dark Mode, keyboard navigation, VoiceOver labels, English and Polish.
- No analytics, networking, account, helper daemon, or subprocesses in the app.

## Why macOS 27 needs a new implementation

macOS 27 replaced the menu bar layout internals used by older utilities. Inflating a separator no longer provides reliable hiding, and MenuBarAgent no longer exposes the old per-icon window arrangement. MenuBarFold reads item ownership and geometry through Accessibility, then dynamically uses the macOS 27 visibility service to allow only the required application bundles.

The visibility service is private and is unavailable to App Store sandboxed apps. MenuBarFold resolves it at runtime and follows a fail-open rule: if permission, framework availability, display geometry, or classification is uncertain, the restriction is released and the complete menu bar is shown.

## Requirements

- macOS 27.0 or later.
- Accessibility permission.
- Installation in the system `/Applications` folder.
- Direct distribution outside the Mac App Store, without App Sandbox.
- A stable signature. Public releases use Developer ID; local builds prefer an installed development certificate and otherwise fall back to an ad-hoc signature.

The source remains buildable against macOS 14+ for ordinary CI checks, while release builds are produced on the GitHub `xcode-27` runner and declare macOS 27 as their minimum runtime.

## Build and run locally

The tested local setup is macOS 27, Xcode 27, and Swift 6.4.

```sh
git clone <your-repository-url>
cd MenuBarFold
./script/build_and_run.sh --verify
```

This builds `dist/MenuBarFold.app`, signs it with the first available local code-signing identity, installs that exact bundle as `/Applications/MenuBarFold.app`, launches it, and verifies the process.

Useful commands:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --diagnose
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

The About screen reads its version from `CFBundleShortVersionString`, so the displayed version matches the local build or release tag.

## Publish a DMG release

The repository contains [a release workflow](.github/workflows/release.yml) that:

1. checks out an existing `vMAJOR.MINOR.PATCH` tag;
2. runs all tests on the `xcode-27` runner;
3. imports a Developer ID Application certificate from GitHub Actions secrets;
4. builds a universal `arm64 + x86_64` application with Hardened Runtime;
5. creates, signs, notarizes, and staples a DMG;
6. generates its SHA-256 checksum;
7. creates a GitHub Release and attaches both files.

After completing the one-time certificate and secret setup from the [release guide](docs/RELEASING.md), publish a version with:

```sh
git tag -a v0.2.0 -m "MenuBarFold 0.2.0"
git push origin v0.2.0
```

The workflow can also be rerun manually from **Actions → Release DMG** for an existing tag.

## Important macOS 27 limitations

- Hiding works per application bundle, not per individual icon. If one app owns several menu bar items, the most visible placement wins.
- Apple controls such as Clock, Control Center, Wi-Fi, Sound, and Battery remain visible.
- Now Playing and Live Activities can disappear while a restriction is active.
- Clicking the clock may not open Notification Center until the bar is expanded.
- macOS still owns the final menu bar order. MenuBarFold does not re-register its controls while folding, but it cannot prevent the system or another app from recreating or moving an item after a restart or display change.
- The system `«` may still appear naturally when macOS runs out of space; MenuBarFold neither positions nor controls it.
- A future macOS update can change or remove the private visibility service.

MenuBarFold releases its restriction while a microphone or camera is active so the system privacy capsule remains visible. macOS does not provide a public API for detecting another application's screen recording, so the wider screen-recording capsule cannot receive the same protection.

## Repository structure

```text
.github/workflows/      continuous integration and DMG releases
script/                 local build, bundle, and release packaging scripts
Sources/MenuBarFold/    SwiftUI, AppKit, state, and services
Sources/MenuBarPrivateBridge/
                        runtime bridge to the macOS 27 private framework
Tests/MenuBarFoldTests/ layout, state, localization, and compatibility tests
docs/                   architecture and release documentation
```

See [Architecture](docs/ARCHITECTURE.md), [Release guide](docs/RELEASING.md), [Contributing](CONTRIBUTING.md), and [Security policy](SECURITY.md).

## Attribution

The macOS 27 visibility research and safety observations were informed by the MIT-licensed [Hidden Bar](https://github.com/dwarvesf/hidden), [MenuBarHider](https://github.com/happy666End/MenuBarHider), and [MenubarHide](https://github.com/junior-rj/menubar-hide) projects. MenuBarFold is an independent implementation. Original license notices are preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).
