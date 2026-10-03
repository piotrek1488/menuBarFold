import AppKit
import ApplicationServices
import Foundation

protocol MenuBarInventoryProviding: AnyObject {
  var isAuthorized: Bool { get }
  func requestAuthorization()
  func snapshot(completion: @escaping ([MenuBarInventoryItem]) -> Void)
}

enum MenuBarDisplayInventory {
  static func current() -> [MenuBarDisplay] {
    let screens = NSScreen.screens
    guard let desktopTop = screens.map(\.frame.maxY).max() else { return [] }

    return screens.enumerated().map { index, screen in
      let screenNumber =
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
      let identifier = screenNumber.map { String($0.uint32Value) } ?? "screen-\(index)"
      let frame = screen.frame
      let accessibilityFrame = CGRect(
        x: frame.minX,
        y: desktopTop - frame.maxY,
        width: frame.width,
        height: frame.height
      )

      return MenuBarDisplay(
        identifier: identifier,
        appKitFrame: frame,
        accessibilityFrame: accessibilityFrame
      )
    }
  }
}

final class AccessibilityMenuBarInventory: MenuBarInventoryProviding {
  private static let messagingTimeout: Float = 0.12
  private var hasRequestedAuthorization = false

  var isAuthorized: Bool {
    AXIsProcessTrusted()
  }

  func requestAuthorization() {
    guard !hasRequestedAuthorization else { return }
    hasRequestedAuthorization = true

    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  func snapshot(completion: @escaping ([MenuBarInventoryItem]) -> Void) {
    let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let applications = NSWorkspace.shared.runningApplications
      .filter {
        $0.processIdentifier != ownProcessIdentifier
          && $0.bundleURL?.pathExtension.lowercased() == "app"
      }
      .map {
        (processIdentifier: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier)
      }

    DispatchQueue.global(qos: .userInitiated).async {
      let items = Self.statusItems(of: applications)
      DispatchQueue.main.async {
        completion(items)
      }
    }
  }

  private static func statusItems(
    of applications: [(processIdentifier: pid_t, bundleIdentifier: String?)]
  ) -> [MenuBarInventoryItem] {
    var items: [MenuBarInventoryItem] = []

    for application in applications {
      let element = AXUIElementCreateApplication(application.processIdentifier)
      AXUIElementSetMessagingTimeout(element, messagingTimeout)

      var menuBarValue: CFTypeRef?
      guard
        AXUIElementCopyAttributeValue(
          element,
          "AXExtrasMenuBar" as CFString,
          &menuBarValue
        ) == .success,
        let menuBarValue
      else {
        continue
      }

      let menuBar = unsafeBitCast(menuBarValue, to: AXUIElement.self)
      var childrenValue: CFTypeRef?
      guard
        AXUIElementCopyAttributeValue(
          menuBar,
          kAXChildrenAttribute as CFString,
          &childrenValue
        ) == .success,
        let children = childrenValue as? [AXUIElement]
      else {
        continue
      }

      for child in children {
        guard let frame = frame(of: child) else { continue }
        items.append(
          MenuBarInventoryItem(
            bundleIdentifier: application.bundleIdentifier,
            frame: frame
          )
        )
      }
    }

    return items
  }

  private static func frame(of element: AXUIElement) -> CGRect? {
    var positionValue: CFTypeRef?
    var sizeValue: CFTypeRef?

    guard
      AXUIElementCopyAttributeValue(
        element,
        kAXPositionAttribute as CFString,
        &positionValue
      ) == .success,
      AXUIElementCopyAttributeValue(
        element,
        kAXSizeAttribute as CFString,
        &sizeValue
      ) == .success,
      let positionValue,
      let sizeValue
    else {
      return nil
    }

    let positionAXValue = unsafeBitCast(positionValue, to: AXValue.self)
    let sizeAXValue = unsafeBitCast(sizeValue, to: AXValue.self)
    var position = CGPoint.zero
    var size = CGSize.zero

    guard AXValueGetValue(positionAXValue, .cgPoint, &position),
      AXValueGetValue(sizeAXValue, .cgSize, &size)
    else {
      return nil
    }

    return CGRect(origin: position, size: size)
  }
}
