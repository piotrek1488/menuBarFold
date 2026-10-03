# Architecture

## Runtime shape

MenuBarFold is a single-process menu bar app. It has no helper, daemon, network client, database, file watcher, or shell execution. AppKit owns the status items and settings window; SwiftUI renders the settings content.

```text
AppDelegate
  ├─ AppModel (observable state and UserDefaults)
  ├─ StatusBarController
  │    ├─ NSStatusItem toggle boundary
  │    ├─ optional always-hidden boundary
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

1. The user Command-drags third-party items around the MenuBarFold arrow.
2. On collapse, `AccessibilityMenuBarInventory` asks each running app for `AXExtrasMenuBar` children and their frames.
3. `MenuBarLayoutResolver` classifies the owning bundle as visible, hidden, or always hidden relative to MenuBarFold's status item boundaries.
4. For apps with several items, the most visible section wins. This prevents one hidden sibling icon from hiding an icon the user placed on the visible side.
5. `NativeVisibilityClient` dynamically loads `MenuBarClientCore` and creates an assessment-mode assertion with an allow-list of visible app bundle identifiers and protected system item identifiers.
6. Expanding replaces or invalidates the assertion. Process exit also releases it automatically.

The Objective-C bridge uses runtime class and selector lookup. There is no link-time dependency on a private framework, so a changed or missing framework becomes a normal unavailable state instead of a launch crash.

## Safety invariants

- **Fail open:** every error invalidates the active assertion before it reports a problem.
- **Generation tokens:** stale Accessibility scans and late private-framework callbacks cannot overwrite a newer user action.
- **No uncertain geometry:** an item outside known display coordinates invalidates the whole snapshot.
- **Per-display projection:** boundary positions are projected by their distance from each display's visible menu bar edge.
- **Environment refresh:** display, wake, app launch, and app termination changes release stale state before a fresh scan.
- **Capture protection:** a microphone or camera in use releases the assertion so macOS's wide privacy capsule remains available.
- **System controls:** MenuBarAgent and Control Center are excluded from third-party section classification and their known system identifiers are allow-listed.

## Accessibility boundary

Accessibility is used only to obtain the owner bundle identifier and frame of `AXExtrasMenuBar` children. The app does not inspect titles, menu contents, other windows, keyboard events, text fields, or screen pixels. Inventory data remains in memory and is replaced on the next scan.

## Distribution constraints

The application must be unsandboxed because Accessibility access to other apps and the native macOS 27 visibility service do not work in an App Store sandbox. Release artifacts should use Hardened Runtime, Developer ID signing, notarization, and stapling. No private entitlements are required.
