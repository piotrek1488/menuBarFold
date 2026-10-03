import Foundation
import XCTest

@testable import MenuBarFold

final class ApplicationLocationTests: XCTestCase {
  private var temporaryRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      "MenuBarFold-ApplicationLocationTests-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: temporaryRoot,
      withIntermediateDirectories: true
    )
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: temporaryRoot)
    try super.tearDownWithError()
  }

  func testOnlySystemApplicationsFolderIsSupported() {
    XCTAssertTrue(
      ApplicationLocation.isSupported(
        URL(fileURLWithPath: "/Applications/MenuBarFold.app")
      )
    )
    XCTAssertTrue(
      ApplicationLocation.isSupported(
        URL(fileURLWithPath: "/Applications/Utilities/MenuBarFold.app")
      )
    )

    let unsupportedPaths = [
      "/Users/example/Applications/MenuBarFold.app",
      "/Users/example/git/MenuBarFold/dist/MenuBarFold.app",
      "/Volumes/MenuBarFold/MenuBarFold.app",
      "/private/var/folders/example/AppTranslocation/MenuBarFold.app",
    ]
    for path in unsupportedPaths {
      XCTAssertFalse(ApplicationLocation.isSupported(URL(fileURLWithPath: path)), path)
    }
  }

  func testInstallCopyReplacesAnExistingApplicationWithoutMovingSource() throws {
    let source = try makeApplication(
      in: temporaryRoot.appendingPathComponent("Build"), marker: "new")
    let applications = temporaryRoot.appendingPathComponent("Applications")
    _ = try makeApplication(in: applications, marker: "old")

    let installed = try ApplicationLocation.installCopy(
      from: source,
      into: applications
    )

    XCTAssertEqual(installed, applications.appendingPathComponent("MenuBarFold.app"))
    XCTAssertEqual(try marker(in: installed), "new")
    XCTAssertEqual(try marker(in: source), "new")
  }

  func testInstalledCopySupersedesOnlyAnExistingUnsupportedCopy() {
    let installed = URL(fileURLWithPath: "/Applications/MenuBarFold.app")
    let development = URL(
      fileURLWithPath: "/Users/example/git/MenuBarFold/dist/MenuBarFold.app")

    XCTAssertTrue(
      ApplicationLocation.shouldSupersede(
        existingBundleURL: development,
        with: installed
      )
    )
    XCTAssertFalse(
      ApplicationLocation.shouldSupersede(
        existingBundleURL: installed,
        with: development
      )
    )
    XCTAssertFalse(
      ApplicationLocation.shouldSupersede(
        existingBundleURL: installed,
        with: installed
      )
    )
    XCTAssertFalse(
      ApplicationLocation.shouldSupersede(
        existingBundleURL: nil,
        with: installed
      )
    )
  }

  private func makeApplication(in folder: URL, marker: String) throws -> URL {
    let bundle = folder.appendingPathComponent("MenuBarFold.app", isDirectory: true)
    let contents = bundle.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    try marker.write(
      to: contents.appendingPathComponent("marker"),
      atomically: true,
      encoding: .utf8
    )
    return bundle
  }

  private func marker(in bundle: URL) throws -> String {
    try String(
      contentsOf: bundle.appendingPathComponent("Contents/marker"),
      encoding: .utf8
    )
  }
}
