import CoreGraphics
import XCTest

@testable import MenuBarFold

final class MenuBarLayoutResolverTests: XCTestCase {
  private let display = MenuBarDisplay(
    identifier: "main",
    appKitFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
    accessibilityFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
  )

  func testResolvesVisibleHiddenAndAlwaysHiddenSections() throws {
    let inventory = [
      MenuBarInventoryItem(bundleIdentifier: "visible.app", frame: frame(atX: 900)),
      MenuBarInventoryItem(bundleIdentifier: "hidden.app", frame: frame(atX: 650)),
      MenuBarInventoryItem(bundleIdentifier: "always.app", frame: frame(atX: 350)),
    ]

    let layout = try XCTUnwrap(
      MenuBarLayoutResolver.resolve(
        inventory: inventory,
        boundaryFrame: frame(atX: 800),
        alwaysHiddenBoundaryFrame: frame(atX: 500),
        displays: [display],
        isLeftToRight: true,
        excludingBundle: "MenuBarFold"
      )
    )

    XCTAssertEqual(layout.sections["visible.app"], .visible)
    XCTAssertEqual(layout.sections["hidden.app"], .hidden)
    XCTAssertEqual(layout.sections["always.app"], .alwaysHidden)
  }

  func testMostVisibleItemWinsWhenOneAppOwnsSeveralItems() throws {
    let inventory = [
      MenuBarInventoryItem(bundleIdentifier: "multi.app", frame: frame(atX: 350)),
      MenuBarInventoryItem(bundleIdentifier: "multi.app", frame: frame(atX: 900)),
    ]

    let layout = try XCTUnwrap(
      MenuBarLayoutResolver.resolve(
        inventory: inventory,
        boundaryFrame: frame(atX: 800),
        alwaysHiddenBoundaryFrame: frame(atX: 500),
        displays: [display],
        isLeftToRight: true,
        excludingBundle: nil
      )
    )

    XCTAssertEqual(layout.sections["multi.app"], .visible)
  }

  func testExcludesOwnAndProtectedSystemBundles() throws {
    let inventory = [
      MenuBarInventoryItem(bundleIdentifier: "MenuBarFold", frame: frame(atX: 300)),
      MenuBarInventoryItem(bundleIdentifier: "com.apple.controlcenter", frame: frame(atX: 300)),
      MenuBarInventoryItem(bundleIdentifier: "third.party", frame: frame(atX: 700)),
    ]

    let layout = try XCTUnwrap(
      MenuBarLayoutResolver.resolve(
        inventory: inventory,
        boundaryFrame: frame(atX: 800),
        alwaysHiddenBoundaryFrame: nil,
        displays: [display],
        isLeftToRight: true,
        excludingBundle: "MenuBarFold"
      )
    )

    XCTAssertEqual(layout.sections, ["third.party": .hidden])
  }

  func testProjectsBoundaryByDistanceFromVisibleEdgeAcrossDisplays() throws {
    let secondDisplay = MenuBarDisplay(
      identifier: "external",
      appKitFrame: CGRect(x: 1_000, y: 0, width: 800, height: 700),
      accessibilityFrame: CGRect(x: 1_000, y: 100, width: 800, height: 700)
    )
    let inventory = [
      MenuBarInventoryItem(bundleIdentifier: "external.visible", frame: frame(atX: 1_750, y: 100)),
      MenuBarInventoryItem(bundleIdentifier: "external.hidden", frame: frame(atX: 1_600, y: 100)),
    ]

    let layout = try XCTUnwrap(
      MenuBarLayoutResolver.resolve(
        inventory: inventory,
        boundaryFrame: frame(atX: 900),
        alwaysHiddenBoundaryFrame: nil,
        displays: [display, secondDisplay],
        isLeftToRight: true,
        excludingBundle: nil
      )
    )

    XCTAssertEqual(layout.sections["external.visible"], .visible)
    XCTAssertEqual(layout.sections["external.hidden"], .hidden)
  }

  func testFailsOpenWhenThirdPartyItemCannotBeMappedToDisplay() {
    let inventory = [
      MenuBarInventoryItem(bundleIdentifier: "unknown.app", frame: frame(atX: 4_000))
    ]

    let layout = MenuBarLayoutResolver.resolve(
      inventory: inventory,
      boundaryFrame: frame(atX: 800),
      alwaysHiddenBoundaryFrame: nil,
      displays: [display],
      isLeftToRight: true,
      excludingBundle: nil
    )

    XCTAssertNil(layout)
  }

  private func frame(atX x: CGFloat, y: CGFloat = 0) -> CGRect {
    CGRect(x: x - 10, y: y, width: 20, height: 24)
  }
}
