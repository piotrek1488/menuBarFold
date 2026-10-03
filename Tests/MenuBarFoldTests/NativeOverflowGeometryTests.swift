import CoreGraphics
import XCTest

@testable import MenuBarFold

final class NativeOverflowGeometryTests: XCTestCase {
  typealias Display = NativeOverflowGeometry.Display

  func testPlainDisplayStaysBelowHalfWidthDiscardCliff() {
    XCTAssertEqual(
      NativeOverflowGeometry.unitLength(displays: [Display(width: 2_056)]),
      964
    )
    XCTAssertEqual(
      NativeOverflowGeometry.unitLength(displays: [Display(width: 3_840)]),
      1_856
    )
  }

  func testNotchedDisplayUsesTrailingStatusArea() {
    let display = Display(width: 1_512, statusAreaWidth: 663.5)
    let length = NativeOverflowGeometry.unitLength(displays: [display])

    XCTAssertEqual(length, 433)
    XCTAssertLessThan(length, 520)
  }

  func testNarrowestSafeLengthWinsAcrossDisplays() {
    let displays = [
      Display(width: 3_840),
      Display(width: 1_512, statusAreaWidth: 663.5),
    ]

    XCTAssertEqual(NativeOverflowGeometry.unitLength(displays: displays), 433)
  }

  func testSpacersCoverWidestStatusArea() {
    XCTAssertEqual(
      NativeOverflowGeometry.activeSpacerCount(
        unitLength: 433,
        displays: [Display(width: 1_512, statusAreaWidth: 663.5)]
      ),
      1
    )
    XCTAssertEqual(
      NativeOverflowGeometry.activeSpacerCount(
        unitLength: 692,
        displays: [Display(width: 1_512), Display(width: 3_840)]
      ),
      5
    )
  }

  func testGeometryUsesSafeFallbacksAndCapsSpacerCount() {
    XCTAssertEqual(NativeOverflowGeometry.unitLength(displays: []), 200)
    XCTAssertEqual(
      NativeOverflowGeometry.activeSpacerCount(
        unitLength: 200,
        displays: [Display(width: 10_000)]
      ),
      NativeOverflowGeometry.spacerCount
    )
    XCTAssertEqual(
      NativeOverflowGeometry.activeSpacerCount(
        unitLength: 0,
        displays: [Display(width: 1_512)]
      ),
      0
    )
  }
}
