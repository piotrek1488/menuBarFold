import CoreGraphics

/// Sizes multiple status items below macOS 27's per-item discard threshold.
/// Their combined width moves items left of the boundary into the native `«` menu.
enum NativeOverflowGeometry {
  struct Display: Equatable {
    let width: CGFloat
    let statusAreaWidth: CGFloat

    init(width: CGFloat, statusAreaWidth: CGFloat? = nil) {
      self.width = width
      self.statusAreaWidth = statusAreaWidth ?? width
    }
  }

  static let minimumUnit: CGFloat = 200
  static let cliffMargin: CGFloat = 64
  static let notchedCliffFactor: CGFloat = 0.75
  /// A fixed count keeps stable autosave names. Twelve segments cover wide external
  /// displays while each segment stays below the discard cliff of a notched MacBook.
  static let spacerCount = 12

  static func safeLength(for display: Display) -> CGFloat {
    if display.statusAreaWidth < display.width {
      return display.statusAreaWidth * notchedCliffFactor
    }
    return display.width / 2
  }

  static func unitLength(displays: [Display]) -> CGFloat {
    guard let lowestSafeLength = displays.map(safeLength(for:)).min() else {
      return minimumUnit
    }
    return max(minimumUnit, (lowestSafeLength - cliffMargin).rounded(.down))
  }

  static func activeSpacerCount(unitLength: CGFloat, displays: [Display]) -> Int {
    guard unitLength > 0,
      let widestStatusArea = displays.map(\.statusAreaWidth).max()
    else {
      return 0
    }

    let needed = Int((widestStatusArea / unitLength).rounded(.up)) - 1
    return min(max(needed, 0), spacerCount)
  }

  static func coveredWidth(unitLength: CGFloat, activeSpacerCount: Int) -> CGFloat {
    unitLength * CGFloat(activeSpacerCount + 1)
  }
}
