import AppKit
import XCTest

@testable import MenuBarFold

@MainActor
final class NativeMenuBarEngineTests: XCTestCase {
  func testMissingAccessibilityFailsOpenWithoutActivation() {
    let inventory = InventoryMock(isAuthorized: false, items: [])
    let visibility = VisibilityMock()
    let capture = CaptureMock(isActive: false)
    let boundary = BoundaryMock()
    let engine = makeEngine(
      inventory: inventory,
      visibility: visibility,
      capture: capture,
      boundary: boundary
    )
    var latest: MenuBarEngineSnapshot?
    engine.onSnapshot = { latest = $0 }

    engine.collapse()

    XCTAssertTrue(inventory.didRequestAuthorization)
    XCTAssertTrue(visibility.activations.isEmpty)
    XCTAssertEqual(latest?.status, .needsAccessibility)
    XCTAssertFalse(boundary.isAlwaysHiddenBoundaryVisible)
  }

  func testCollapseAllowsOnlyVisibleBundlesAndOwnBundle() {
    let inventory = InventoryMock(
      isAuthorized: true,
      items: [
        MenuBarInventoryItem(
          bundleIdentifier: "visible.app",
          frame: CGRect(x: 890, y: 0, width: 20, height: 24)
        ),
        MenuBarInventoryItem(
          bundleIdentifier: "hidden.app",
          frame: CGRect(x: 690, y: 0, width: 20, height: 24)
        ),
      ]
    )
    let visibility = VisibilityMock()
    let capture = CaptureMock(isActive: false)
    let boundary = BoundaryMock()
    let engine = makeEngine(
      inventory: inventory,
      visibility: visibility,
      capture: capture,
      boundary: boundary
    )
    var latest: MenuBarEngineSnapshot?
    engine.onSnapshot = { latest = $0 }

    engine.collapse()

    XCTAssertEqual(visibility.activations.count, 1)
    XCTAssertEqual(
      visibility.activations[0].bundles,
      ["own.app", "visible.app"]
    )
    XCTAssertEqual(visibility.activations[0].systemItems, Array(0..<64))
    XCTAssertEqual(latest?.status, .collapsed)
    XCTAssertEqual(latest?.hiddenAppCount, 1)
    XCTAssertFalse(boundary.isAlwaysHiddenBoundaryVisible)
  }

  func testCaptureProtectionDoesNotActivateRestriction() {
    let inventory = InventoryMock(isAuthorized: true, items: [])
    let visibility = VisibilityMock()
    let capture = CaptureMock(isActive: true)
    let boundary = BoundaryMock()
    let engine = makeEngine(
      inventory: inventory,
      visibility: visibility,
      capture: capture,
      boundary: boundary
    )
    var latest: MenuBarEngineSnapshot?
    engine.onSnapshot = { latest = $0 }

    engine.collapse()

    XCTAssertTrue(visibility.activations.isEmpty)
    XCTAssertEqual(latest?.status, .pausedForCapture)
    XCTAssertFalse(boundary.isAlwaysHiddenBoundaryVisible)
  }

  func testExpandingInvalidatesActiveRestriction() throws {
    let inventory = InventoryMock(
      isAuthorized: true,
      items: [
        MenuBarInventoryItem(
          bundleIdentifier: "hidden.app",
          frame: CGRect(x: 690, y: 0, width: 20, height: 24)
        )
      ]
    )
    let visibility = VisibilityMock()
    let capture = CaptureMock(isActive: false)
    let boundary = BoundaryMock()
    let engine = makeEngine(
      inventory: inventory,
      visibility: visibility,
      capture: capture,
      boundary: boundary
    )

    engine.collapse()
    let assertion = try XCTUnwrap(visibility.lastAssertion)
    XCTAssertFalse(assertion.didInvalidate)

    engine.expand()

    XCTAssertTrue(assertion.didInvalidate)
  }

  private func makeEngine(
    inventory: InventoryMock,
    visibility: VisibilityMock,
    capture: CaptureMock,
    boundary: BoundaryMock
  ) -> NativeMenuBarEngine {
    let display = MenuBarDisplay(
      identifier: "main",
      appKitFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
      accessibilityFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )
    let engine = NativeMenuBarEngine(
      inventory: inventory,
      visibility: visibility,
      captureActivity: capture,
      ownBundleIdentifier: "own.app",
      displays: { [display] },
      isLeftToRight: { true },
      isSupportedOperatingSystem: { true }
    )
    engine.boundaryProvider = boundary
    return engine
  }
}

private final class InventoryMock: MenuBarInventoryProviding {
  let isAuthorized: Bool
  let items: [MenuBarInventoryItem]
  private(set) var didRequestAuthorization = false

  init(isAuthorized: Bool, items: [MenuBarInventoryItem]) {
    self.isAuthorized = isAuthorized
    self.items = items
  }

  func requestAuthorization() {
    didRequestAuthorization = true
  }

  func snapshot(completion: @escaping ([MenuBarInventoryItem]) -> Void) {
    completion(items)
  }
}

private final class AssertionMock: NativeVisibilityAssertion {
  private(set) var didInvalidate = false

  func invalidate() {
    didInvalidate = true
  }
}

private final class VisibilityMock: NativeVisibilityProviding {
  struct Activation: Equatable {
    let systemItems: [Int]
    let bundles: [String]
  }

  var isAvailable = true
  private(set) var activations: [Activation] = []
  private(set) var lastAssertion: AssertionMock?

  func activate(
    allowedSystemItems: [Int],
    allowedBundleIdentifiers: [String],
    completion: @escaping (Result<NativeVisibilityAssertion, Error>) -> Void
  ) {
    activations.append(
      Activation(
        systemItems: allowedSystemItems,
        bundles: allowedBundleIdentifiers
      )
    )
    let assertion = AssertionMock()
    lastAssertion = assertion
    completion(.success(assertion))
  }
}

private final class CaptureMock: CaptureActivityMonitoring {
  var isActive: Bool
  var onChange: ((Bool) -> Void)?

  init(isActive: Bool) {
    self.isActive = isActive
  }

  func start() {}
  func stop() {}
}

@MainActor
private final class BoundaryMock: MenuBarBoundaryProviding {
  var toggleBoundaryFrame: CGRect? = CGRect(x: 790, y: 0, width: 20, height: 24)
  var alwaysHiddenBoundaryFrame: CGRect? = CGRect(x: 490, y: 0, width: 20, height: 24)
  private(set) var isAlwaysHiddenBoundaryVisible = true

  func setAlwaysHiddenBoundaryVisible(_ visible: Bool) {
    isAlwaysHiddenBoundaryVisible = visible
  }
}
