import CoreGraphics
import XCTest

@testable import MenuBarFold

final class NativeOverflowGeometryTests: XCTestCase {
  typealias Display = NativeOverflowGeometry.Display

  func testPresentationStyleUsesNativeOverflowOnlyWhenEveryDisplayHasNotchGeometry() {
    XCTAssertEqual(
      AlwaysHiddenPresentationStyle.resolve(
        displays: [Display(width: 1_710, statusAreaWidth: 751)]
      ),
      .nativeOverflow
    )
    XCTAssertEqual(
      AlwaysHiddenPresentationStyle.resolve(
        displays: [
          Display(width: 1_710, statusAreaWidth: 751),
          Display(width: 2_560),
        ]
      ),
      .customControl
    )
    XCTAssertEqual(
      AlwaysHiddenPresentationStyle.resolve(displays: []),
      .customControl
    )
  }

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

  func testNotchedMacBookCanDriveOverflowOnWideExternalDisplay() {
    let displays = [
      Display(width: 1_512, statusAreaWidth: 663.5),
      Display(width: 3_840),
    ]
    let unitLength = NativeOverflowGeometry.unitLength(displays: displays)
    let spacers = NativeOverflowGeometry.activeSpacerCount(
      unitLength: unitLength,
      displays: displays
    )

    XCTAssertEqual(unitLength, 433)
    XCTAssertEqual(spacers, 8)
    XCTAssertGreaterThanOrEqual(
      NativeOverflowGeometry.coveredWidth(
        unitLength: unitLength,
        activeSpacerCount: spacers
      ),
      3_840
    )
    XCTAssertLessThan(unitLength, 663.5 * NativeOverflowGeometry.notchedCliffFactor)
  }

  func testCurrentThreeDisplayGeometryUsesNotchedScreenForUnitAndExternalForCoverage() {
    let displays = [
      Display(width: 1_710, statusAreaWidth: 751),
      Display(width: 2_560),
      Display(width: 2_560),
    ]
    let unitLength = NativeOverflowGeometry.unitLength(displays: displays)
    let spacers = NativeOverflowGeometry.activeSpacerCount(
      unitLength: unitLength,
      displays: displays
    )

    XCTAssertEqual(unitLength, 499)
    XCTAssertEqual(spacers, 5)
    XCTAssertGreaterThanOrEqual(
      NativeOverflowGeometry.coveredWidth(
        unitLength: unitLength,
        activeSpacerCount: spacers
      ),
      2_560
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
