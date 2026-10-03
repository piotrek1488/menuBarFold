# Architecture

## Runtime shape

MenuBarFold is a single-process menu bar app. It has no helper, daemon, network client, database, file watcher, or shell execution. AppKit owns the status items and settings window; SwiftUI renders the settings content.

```text
AppDelegate
  ├─ AppModel (observable state and UserDefaults)
  ├─ StatusBarController
  │    ├─ persistent primary NSStatusItem toggle boundary
  │    ├─ native-overflow boundary and bounded spacer items
  │    ├─ `|` arrangement boundary between regular and always-hidden sections
  │    ├─ timers, hover monitor and global shortcut
  │    └─ NativeMenuBarEngine
  │         ├─ AccessibilityMenuBarInventory
  │         ├─ MenuBarLayoutResolver
  │         ├─ NativeVisibilityClient
  │         └─ CaptureActivityMonitor
  └─ PreferencesWindowController
       └─ SwiftUI settings hierarchy
```

## macOS 27 hiding flow

1. The user Command-drags third-party items into three zones: always hidden left of `|`, regular hidden between `|` and the main arrow, and visible right of the main arrow.
2. On collapse, `AccessibilityMenuBarInventory` asks each running app for `AXExtrasMenuBar` children and their frames.
3. `MenuBarLayoutResolver` classifies the owning bundle as visible, hidden, or always hidden relative to MenuBarFold's status item boundaries.
4. For apps with several items, the most visible section wins. This prevents one hidden sibling icon from hiding an icon the user placed on the visible side.
5. `NativeVisibilityClient` dynamically loads `MenuBarClientCore` and creates an assessment-mode assertion with an allow-list of visible app bundle identifiers and protected system item identifiers.
6. On collapse, the allow-list keeps visible and always-hidden bundles but removes regular hidden bundles. Bounded spacer items move the always-hidden icons left of `|` into macOS 27's native `«` overflow menu.
7. On expansion, MenuBarFold releases the assertion so regular hidden icons return, while the bounded spacers keep always-hidden icons in the system overflow. Process exit releases the assertion and removes the overflow geometry.

The Objective-C bridge uses runtime class and selector lookup. There is no link-time dependency on a private framework, so a changed or missing framework becomes a normal unavailable state instead of a launch crash.

## Safety invariants

- **Fail open:** every error invalidates the active assertion before it reports a problem.
- **Supported location:** filtering is never activated unless the running bundle is below the system `/Applications` folder. This preserves MenuBarFold's own allow-listed controls on macOS 27.
- **Generation tokens:** stale Accessibility scans and late private-framework callbacks cannot overwrite a newer user action.
- **No uncertain geometry:** an item outside known display coordinates invalidates the whole snapshot.
- **Per-display projection:** boundary positions are projected by their distance from each display's visible menu bar edge.
- **Bounded native overflow:** no spacer reaches macOS 27's per-display status-item discard threshold; several bounded items provide the required width across notched and external displays.
- **Environment refresh:** display, wake, app launch, and app termination changes release stale state before a fresh scan.
- **Capture protection:** a microphone or camera in use releases the assertion so macOS's wide privacy capsule remains available.
- **System controls:** MenuBarAgent and Control Center are excluded from third-party section classification and their known system identifiers are allow-listed.

## Accessibility boundary

Accessibility is used only to obtain the owner bundle identifier and frame of `AXExtrasMenuBar` children. The app does not inspect titles, menu contents, other windows, keyboard events, text fields, or screen pixels. Inventory data remains in memory and is replaced on the next scan.

## Distribution constraints

The application must be unsandboxed because Accessibility access to other apps and the native macOS 27 visibility service do not work in an App Store sandbox. It must also run from the system `/Applications` folder because MenuBarAgent does not preserve the controlling app's own status items for copies launched elsewhere. Release artifacts should use Hardened Runtime, Developer ID signing, notarization, and stapling. No private entitlements are required.
