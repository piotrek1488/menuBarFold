import ApplicationServices
import Foundation

enum DiagnosticRunner {
  static func run() {
    let version = ProcessInfo.processInfo.operatingSystemVersionString
    let bridgeAvailable = NativeVisibilityClient().isAvailable
    let accessibilityGranted = AXIsProcessTrusted()
    let isBundled = Bundle.main.bundleURL.pathExtension == "app"

    print("MenuBarFold diagnostics")
    print("macOS: \(version)")
    print("Native visibility bridge: \(bridgeAvailable ? "available" : "unavailable")")
    print("Accessibility: \(accessibilityGranted ? "granted" : "not granted")")
    print("Running as app bundle: \(isBundled ? "yes" : "no")")
    print("Bundle path: \(Bundle.main.bundleURL.path)")
    print("Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
  }
}
