import AppKit
import ApplicationServices
import Foundation

enum AccessibilityPermissionService {
  static var isGranted: Bool {
    AXIsProcessTrusted()
  }

  static func request() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  static func openSystemSettings() {
    let candidates = [
      "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
    ]

    for candidate in candidates {
      guard let url = URL(string: candidate) else { continue }
      if NSWorkspace.shared.open(url) {
        return
      }
    }
  }
}
