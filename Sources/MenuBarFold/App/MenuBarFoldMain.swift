import AppKit
import Foundation

@main
enum MenuBarFoldMain {
  @MainActor
  static func main() {
    if CommandLine.arguments.contains("--diagnose") {
      DiagnosticRunner.run()
      return
    }

    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
  }
}
