import AppKit

enum MenuBarSection: Int, Comparable, Sendable {
  case visible
  case hidden
  case alwaysHidden

  static func < (lhs: MenuBarSection, rhs: MenuBarSection) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

struct MenuBarInventoryItem: Equatable, Sendable {
  let bundleIdentifier: String?
  let frame: CGRect
}

struct MenuBarDisplay: Equatable, Sendable {
  let identifier: String
  let appKitFrame: CGRect
  let accessibilityFrame: CGRect
}

struct MenuBarLayout: Equatable, Sendable {
  var sections: [String: MenuBarSection]

  func bundles(in wantedSections: Set<MenuBarSection>) -> [String] {
    sections
      .filter { wantedSections.contains($0.value) }
      .map(\.key)
      .sorted()
  }
}

enum MenuBarLayoutResolver {
  static let systemItemOwners: Set<String> = [
    "com.apple.MenuBarAgent",
    "com.apple.controlcenter",
  ]

  static func resolve(
    inventory: [MenuBarInventoryItem],
    boundaryFrame: CGRect,
    alwaysHiddenBoundaryFrame: CGRect?,
    displays: [MenuBarDisplay],
    isLeftToRight: Bool,
    excludingBundle ownBundleIdentifier: String?
  ) -> MenuBarLayout? {
    guard
      let boundaryDisplay = display(
        containingAppKitPoint: midpoint(of: boundaryFrame),
        in: displays
      )
    else {
      return nil
    }

    if let alwaysHiddenBoundaryFrame,
      display(containingAppKitPoint: midpoint(of: alwaysHiddenBoundaryFrame), in: displays)
        != boundaryDisplay
    {
      return nil
    }

    var sections: [String: MenuBarSection] = [:]

    for item in inventory {
      guard let bundleIdentifier = item.bundleIdentifier,
        bundleIdentifier != ownBundleIdentifier,
        !systemItemOwners.contains(bundleIdentifier),
        let itemDisplay = display(
          containingAccessibilityPoint: midpoint(of: item.frame),
          in: displays
        )
      else {
        if item.bundleIdentifier != nil,
          item.bundleIdentifier != ownBundleIdentifier,
          !systemItemOwners.contains(item.bundleIdentifier ?? "")
        {
          return nil
        }
        continue
      }

      let projectedBoundary = projected(
        boundaryFrame,
        from: boundaryDisplay,
        to: itemDisplay,
        isLeftToRight: isLeftToRight
      )
      let projectedAlwaysHidden = alwaysHiddenBoundaryFrame.map {
        projected(
          $0,
          from: boundaryDisplay,
          to: itemDisplay,
          isLeftToRight: isLeftToRight
        )
      }
      let section = section(
        of: item.frame,
        boundaryFrame: projectedBoundary,
        alwaysHiddenBoundaryFrame: projectedAlwaysHidden,
        isLeftToRight: isLeftToRight
      )

      sections[bundleIdentifier] = min(sections[bundleIdentifier] ?? section, section)
    }

    return MenuBarLayout(sections: sections)
  }

  static func section(
    of frame: CGRect,
    boundaryFrame: CGRect,
    alwaysHiddenBoundaryFrame: CGRect?,
    isLeftToRight: Bool
  ) -> MenuBarSection {
    func distanceTowardVisibleSide(_ x: CGFloat, from boundary: CGRect) -> CGFloat {
      isLeftToRight ? x - boundary.midX : boundary.midX - x
    }

    if distanceTowardVisibleSide(frame.midX, from: boundaryFrame) > 0 {
      return .visible
    }

    if let alwaysHiddenBoundaryFrame,
      distanceTowardVisibleSide(frame.midX, from: alwaysHiddenBoundaryFrame) < 0
    {
      return .alwaysHidden
    }

    return .hidden
  }

  private static func projected(
    _ frame: CGRect,
    from source: MenuBarDisplay,
    to target: MenuBarDisplay,
    isLeftToRight: Bool
  ) -> CGRect {
    let distanceFromVisibleEdge =
      isLeftToRight
      ? source.appKitFrame.maxX - frame.midX
      : frame.midX - source.appKitFrame.minX
    let projectedMidX =
      isLeftToRight
      ? target.accessibilityFrame.maxX - distanceFromVisibleEdge
      : target.accessibilityFrame.minX + distanceFromVisibleEdge

    return CGRect(
      x: projectedMidX - frame.width / 2,
      y: 0,
      width: frame.width,
      height: frame.height
    )
  }

  private static func display(
    containingAppKitPoint point: CGPoint,
    in displays: [MenuBarDisplay]
  ) -> MenuBarDisplay? {
    displays.first { $0.appKitFrame.insetBy(dx: -1, dy: -1).contains(point) }
  }

  private static func display(
    containingAccessibilityPoint point: CGPoint,
    in displays: [MenuBarDisplay]
  ) -> MenuBarDisplay? {
    displays.first { $0.accessibilityFrame.insetBy(dx: -1, dy: -1).contains(point) }
  }

  private static func midpoint(of frame: CGRect) -> CGPoint {
    CGPoint(x: frame.midX, y: frame.midY)
  }
}
