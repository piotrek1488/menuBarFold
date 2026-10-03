import AppKit
import Foundation
import OSLog

@MainActor
enum ApplicationsInstaller {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "io.github.menubarfold.MenuBarFold",
    category: "Installation"
  )

  static func offerInstallation(language: AppLanguage) -> Bool {
    NSApp.activate()

    let alert = NSAlert()
    alert.messageText = L10n.string("installation.title", language: language)
    alert.informativeText = L10n.string("installation.explanation", language: language)
    alert.addButton(withTitle: L10n.string("installation.install", language: language))
    alert.addButton(withTitle: L10n.string("installation.notNow", language: language))

    guard alert.runModal() == .alertFirstButtonReturn else { return false }
    return installAndRelaunch(language: language)
  }

  @discardableResult
  static func installAndRelaunch(language: AppLanguage) -> Bool {
    let installedURL: URL
    do {
      installedURL = try ApplicationLocation.installCopy(from: Bundle.main.bundleURL)
    } catch {
      logger.error(
        "Installation in /Applications failed: \(error.localizedDescription, privacy: .public)")
      showInstallationError(error, language: language)
      return false
    }

    relaunch(from: installedURL)
    return true
  }

  private static func relaunch(from applicationURL: URL) {
    let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    for application in NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier
    ) where application.processIdentifier != ownProcessIdentifier {
      application.terminate()
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) {
      _, error in
      DispatchQueue.main.async {
        if let error {
          logger.error(
            "Relaunch from /Applications failed: \(error.localizedDescription, privacy: .public)")
          NSWorkspace.shared.activateFileViewerSelecting([applicationURL])
          return
        }
        NSApp.terminate(nil)
      }
    }
  }

  private static func showInstallationError(_ error: Error, language: AppLanguage) {
    NSApp.activate()
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = L10n.string("installation.error.title", language: language)
    alert.informativeText = String(
      format: L10n.string("installation.error.detail", language: language),
      error.localizedDescription
    )
    alert.runModal()
  }
}
