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
    XCTAssertEqual(boundary.mode, .disabled)
  }

  func testOutsideApplicationsFailsOpenWithoutHidingOwnControls() {
    let inventory = InventoryMock(isAuthorized: true, items: [])
    let visibility = VisibilityMock()
    let capture = CaptureMock(isActive: false)
    let boundary = BoundaryMock()
    let engine = makeEngine(
      inventory: inventory,
      visibility: visibility,
      capture: capture,
      boundary: boundary,
      isSupportedApplicationLocation: false
    )
    var latest: MenuBarEngineSnapshot?
    engine.onSnapshot = { latest = $0 }

    engine.collapse()

    XCTAssertTrue(visibility.activations.isEmpty)
    XCTAssertEqual(boundary.mode, .disabled)
    guard let latest, case .unavailable(let message) = latest.status else {
      return XCTFail("Expected an unavailable state outside /Applications")
    }
    XCTAssertTrue(message.contains("/Applications"))
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
    XCTAssertEqual(boundary.mode, .disabled)
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
    XCTAssertEqual(boundary.mode, .disabled)
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

  func testPrimaryControlAndSystemOverflowExposeSectionsIndependently() throws {
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
        MenuBarInventoryItem(
          bundleIdentifier: "always.app",
          frame: CGRect(x: 390, y: 0, width: 20, height: 24)
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
    engine.configure(alwaysHiddenEnabled: true, protectCaptureIndicators: false)

    engine.collapse()

    XCTAssertEqual(
      visibility.activations.last?.bundles,
      ["always.app", "own.app", "visible.app"]
    )
    XCTAssertEqual(latest?.status, .collapsed)
    XCTAssertEqual(latest?.isHiddenSectionExpanded, false)
    XCTAssertEqual(boundary.mode, .nativeOverflow)

    let collapsedAssertion = try XCTUnwrap(visibility.lastAssertion)
    engine.expand()

    XCTAssertTrue(collapsedAssertion.didInvalidate)
    XCTAssertEqual(latest?.status, .expanded)
    XCTAssertEqual(latest?.isHiddenSectionExpanded, true)
    XCTAssertEqual(boundary.mode, .nativeOverflow)

    engine.arrange()

    XCTAssertEqual(latest?.status, .arranging)
    XCTAssertEqual(latest?.isHiddenSectionExpanded, true)
    XCTAssertEqual(boundary.mode, .boundary)
  }

  func testCollapsedAndExpandedControlsUseRequestedChevronDirections() {
    XCTAssertEqual(
      MenuBarControlAppearance.chevronSymbol(isExpanded: false),
      "chevron.left"
    )
    XCTAssertEqual(
      MenuBarControlAppearance.chevronSymbol(isExpanded: true),
      "chevron.right"
    )
    let separator = MenuBarControlAppearance.separatorImage()
    XCTAssertEqual(separator.size, NSSize(width: 3, height: 16))
    XCTAssertTrue(separator.isTemplate)
  }

  private func makeEngine(
    inventory: InventoryMock,
    visibility: VisibilityMock,
    capture: CaptureMock,
    boundary: BoundaryMock,
    isSupportedApplicationLocation: Bool = true
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
      isSupportedOperatingSystem: { true },
      isSupportedApplicationLocation: { isSupportedApplicationLocation }
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
  private(set) var mode = AlwaysHiddenBoundaryMode.disabled

  func setAlwaysHiddenBoundaryMode(_ mode: AlwaysHiddenBoundaryMode) {
    self.mode = mode
  }

  func afterMenuBarLayoutSettles(_ action: @escaping @MainActor () -> Void) {
    action()
  }
}
