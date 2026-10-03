import Foundation
import XCTest

@testable import MenuBarFold

final class MacOS27CompatibilityTests: XCTestCase {
  func testNativeBridgeExistsOnMacOS27() throws {
    guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else {
      throw XCTSkip("Private macOS 27 bridge is checked only on macOS 27.")
    }

    XCTAssertTrue(
      NativeVisibilityClient().isAvailable,
      "MenuBarClientCore changed or is unavailable on this macOS 27 build."
    )
  }
}
