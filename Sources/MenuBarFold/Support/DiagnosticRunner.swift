import AppKit
import ApplicationServices
import Foundation

enum DiagnosticRunner {
  static func run() {
    _ = NSApplication.shared
    let version = ProcessInfo.processInfo.operatingSystemVersionString
    let bridgeAvailable = NativeVisibilityClient().isAvailable
    let accessibilityGranted = AXIsProcessTrusted()
    let isBundled = Bundle.main.bundleURL.pathExtension == "app"
    let isInApplications = ApplicationLocation.isSupported(Bundle.main.bundleURL)

    print("MenuBarFold diagnostics")
    print("macOS: \(version)")
    print("Native visibility bridge: \(bridgeAvailable ? "available" : "unavailable")")
    print("Accessibility: \(accessibilityGranted ? "granted" : "not granted")")
    print("Running as app bundle: \(isBundled ? "yes" : "no")")
    print("Bundle path: \(Bundle.main.bundleURL.path)")
    print("Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
    print("Supported application location: \(isInApplications ? "yes" : "no")")

    let screens = NSScreen.screens
    print("Displays: \(screens.count)")
    for (index, screen) in screens.enumerated() {
      let screenNumber =
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
      let identifier = screenNumber.map { String($0.uint32Value) } ?? "screen-\(index)"
      print(
        "Display \(index): id=\(identifier), frame=\(screen.frame), visible=\(screen.visibleFrame), scale=\(screen.backingScaleFactor), safeTop=\(screen.safeAreaInsets.top), auxiliaryRight=\(String(describing: screen.auxiliaryTopRightArea))"
      )
    }
    print("Always-hidden control: stable compact status item")
  }
}
