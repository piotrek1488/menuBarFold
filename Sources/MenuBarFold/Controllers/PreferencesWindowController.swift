import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
  private let model: AppModel

  init(model: AppModel) {
    self.model = model

    let rootView = SettingsRootView(model: model)
    let hostingController = NSHostingController(rootView: rootView)
    let window = NSWindow(contentViewController: hostingController)
    window.title = "MenuBarFold"
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    window.titlebarAppearsTransparent = true
    window.toolbarStyle = .unified
    window.setContentSize(NSSize(width: 780, height: 560))
    window.minSize = NSSize(width: 700, height: 500)
    window.isReleasedWhenClosed = false
    window.setFrameAutosaveName("MenuBarFold.SettingsWindow")
    window.center()

    super.init(window: window)
    window.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  func show() {
    guard let window else { return }
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window.makeKeyAndOrderFront(nil)
  }
}
