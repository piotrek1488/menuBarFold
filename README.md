# MenuBarFold

MenuBarFold is a native macOS 27 menu bar utility. It lets you decide which third-party menu bar apps stay visible, which appear only when expanded, and which remain hidden.

The app is written from scratch in Swift, SwiftUI, and AppKit. English is the default language, Polish is included, and the language can be changed inside the app or set to follow macOS.

> [Polska wersja README](docs/README.pl.md)

## Why this exists

macOS 27 replaced the menu bar layout internals that older tools used. Inflating a separator no longer moves neighboring items off screen. MenuBarFold therefore uses the macOS 27 visibility service dynamically and reads item positions with the public Accessibility API.

This is a direct-distribution app. The native visibility service is a private framework and does not work from an App Store sandbox. MenuBarFold checks every dependency at runtime and **fails open**: if the service, permission, display layout, or classification is uncertain, it releases its restriction and shows the complete menu bar.

## Features

- One-click fold and expand from a small menu bar arrow.
- Command-drag arrangement: items left of the arrow are hidden; items to the right stay visible.
- Optional always-hidden section with a second boundary.
- Auto fold with configurable delay.
- Optional reveal on menu bar hover.
- Global shortcut presets.
- Launch at login through `SMAppService`.
- Multi-display classification based on distance from each display's visible menu bar edge.
- Automatic safe refresh after display, wake, app launch, and app termination changes.
- Microphone and camera safety: the full bar is restored while capture is active so macOS privacy indicators remain visible.
- Native settings window, Dark Mode, keyboard navigation, VoiceOver labels, English and Polish.
- No analytics, networking, file access, helper daemon, or subprocesses in the app.

## Requirements

- macOS 27.0 or later. The source compiles against macOS 14+ for CI, but the packaged app declares macOS 27 as its minimum runtime.
- Accessibility permission.
- The app must be distributed outside the Mac App Store and remain unsandboxed.
- A stable code-signing identity is required for Accessibility authorization to survive rebuilds. The build script automatically uses the first valid code-signing certificate in your keychain. You can choose one explicitly with `CODE_SIGN_IDENTITY="Apple Development: Name (TEAMID)"`.
- If no certificate is available, the script falls back to ad-hoc signing and prints a warning. In that mode macOS can treat every rebuild as a different app even when the old entry still looks enabled in System Settings.
- For normal use, keep one signed copy in `/Applications`; do not run an additional development copy at the same time.

## Build and run

Xcode 27 and the Swift 6.4 toolchain are the tested setup.

```sh
git clone <your-repository-url>
cd MenuBarFold
./script/build_and_run.sh --verify
```

The script builds a real app bundle at `dist/MenuBarFold.app`, copies localized resources, generates the app icon, applies an ad-hoc development signature, launches the app, and verifies its process.

Other useful commands:

```sh
./script/build_and_run.sh --test
./script/build_and_run.sh --diagnose
./script/build_and_run.sh --logs
```

The first launch opens setup. Grant Accessibility access, then hold Command and drag menu bar icons across the MenuBarFold arrow. Click **Finish Setup**, then click the arrow to fold the hidden section.

## Important macOS 27 limitations

The only macOS 27 service capable of applying an app allow-list belongs to assessment mode. Apple does not expose a public equivalent. While a restriction is active:

- hiding works per app bundle, not per individual icon;
- Apple system controls such as Clock, Control Center, Wi-Fi, Sound, and Battery stay visible;
- Now Playing and Live Activities can disappear;
- clicking the clock may not open Notification Center until the bar is expanded;
- macOS may change or remove the private service in a future update.

MenuBarFold releases the restriction while a microphone or camera is active. There is no public API for detecting another app's screen recording, so the wider screen-recording capsule cannot receive the same protection.

## Repository structure

```text
Sources/MenuBarFold/
  App/          application lifecycle
  Controllers/ status items and settings window
  Models/       menu bar geometry and user-facing state
  Services/     Accessibility, visibility, capture, login and shortcut services
  Stores/       observable preferences and state
  Views/        SwiftUI settings UI
  Support/      localization and diagnostics
Sources/MenuBarPrivateBridge/
  Objective-C runtime bridge to the macOS 27 private framework
Tests/MenuBarFoldTests/
  geometry, persistence, localization and macOS 27 compatibility tests
```

See [Architecture](docs/ARCHITECTURE.md), [Release guide](docs/RELEASING.md), and [Security policy](SECURITY.md).

## Attribution

The macOS 27 assessment-mode visibility technique and several safety observations were informed by the MIT-licensed [Hidden Bar](https://github.com/dwarvesf/hidden) project. MenuBarFold is an independent implementation. The original license notice is preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).
