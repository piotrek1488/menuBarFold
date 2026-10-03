import Foundation

enum ApplicationLocation {
  static let systemApplicationsFolder = URL(
    fileURLWithPath: "/Applications",
    isDirectory: true
  )

  static func isSupported(_ bundleURL: URL) -> Bool {
    let applicationsPath = systemApplicationsFolder.standardizedFileURL.resolvingSymlinksInPath()
      .path
    let bundlePath = bundleURL.standardizedFileURL.resolvingSymlinksInPath().path
    return bundlePath.hasPrefix(applicationsPath + "/")
  }

  static func shouldSupersede(
    existingBundleURL: URL?,
    with currentBundleURL: URL
  ) -> Bool {
    guard let existingBundleURL else { return false }
    return isSupported(currentBundleURL) && !isSupported(existingBundleURL)
  }

  static func installCopy(
    from source: URL,
    into folder: URL = systemApplicationsFolder,
    fileManager: FileManager = .default
  ) throws -> URL {
    let destination = folder.appendingPathComponent("MenuBarFold.app", isDirectory: true)
    if source.standardizedFileURL == destination.standardizedFileURL {
      return destination
    }

    try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    let staging = folder.appendingPathComponent(
      ".MenuBarFold-installing-\(UUID().uuidString).app",
      isDirectory: true
    )

    do {
      try fileManager.copyItem(at: source, to: staging)
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }
      try fileManager.moveItem(at: staging, to: destination)
      return destination
    } catch {
      try? fileManager.removeItem(at: staging)
      throw error
    }
  }
}
