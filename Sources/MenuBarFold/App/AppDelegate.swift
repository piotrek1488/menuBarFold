import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private var statusBarController: StatusBarController?
  private var preferencesWindowController: PreferencesWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ensureSingleInstance() else { return }

    if let iconURL = Bundle.main.url(forResource: "MenuBarFold", withExtension: "png"),
      let icon = NSImage(contentsOf: iconURL)
    {
      NSApp.applicationIconImage = icon
    }

    let preferencesWindowController = PreferencesWindowController(model: model)
    let statusBarController = StatusBarController(model: model)

    self.preferencesWindowController = preferencesWindowController
    self.statusBarController = statusBarController

    statusBarController.isSettingsWindowVisible = { [weak preferencesWindowController] in
      preferencesWindowController?.isVisible == true
    }
    model.onShowSettings = { [weak preferencesWindowController] in
      preferencesWindowController?.show()
    }

    if model.showSettingsOnLaunch
      || !model.hasCompletedOnboarding
      || !model.isAccessibilityGranted
    {
      preferencesWindowController.show()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    statusBarController?.shutdown()
  }

  private func ensureSingleInstance() -> Bool {
    let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let ownBundleIdentifier = Bundle.main.bundleIdentifier

    guard
      let existing = NSWorkspace.shared.runningApplications.first(where: {
        $0.processIdentifier != ownProcessIdentifier
          && $0.bundleIdentifier == ownBundleIdentifier
      })
    else {
      return true
    }

    existing.activate(options: [.activateAllWindows])
    NSApp.terminate(nil)
    return false
  }
}
