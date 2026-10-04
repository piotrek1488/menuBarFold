import AppKit
import Foundation
import OSLog

@MainActor
protocol MenuBarBoundaryProviding: AnyObject {
  var toggleBoundaryFrame: CGRect? { get }
  var alwaysHiddenBoundaryFrame: CGRect? { get }
  func setAlwaysHiddenBoundaryMode(_ mode: AlwaysHiddenBoundaryMode)
  func afterMenuBarLayoutSettles(_ action: @escaping @MainActor () -> Void)
}

enum AlwaysHiddenBoundaryMode: Equatable {
  case disabled
  case boundary
  case nativeOverflow
  case customControl(isExpanded: Bool)

  var showsSeparator: Bool {
    switch self {
    case .boundary, .customControl:
      return true
    case .disabled, .nativeOverflow:
      return false
    }
  }
}

struct MenuBarEngineSnapshot: Equatable {
  let status: AppStatus
  let hiddenAppCount: Int
  let alwaysHiddenAppCount: Int
  let isHiddenSectionExpanded: Bool
  let isAlwaysHiddenSectionExpanded: Bool
  let error: String?
}

@MainActor
final class NativeMenuBarEngine {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "io.github.menubarfold.MenuBarFold",
    category: "MenuBar"
  )

  private enum Presentation {
    case collapsed
    case expanded
    case fullyExpanded
    case arranging
  }

  private static let systemItemsToKeep = Array(0..<64)

  weak var boundaryProvider: MenuBarBoundaryProviding?
  var onSnapshot: ((MenuBarEngineSnapshot) -> Void)?

  private let inventory: MenuBarInventoryProviding
  private let visibility: NativeVisibilityProviding
  private let captureActivity: CaptureActivityMonitoring
  private let ownBundleIdentifier: String?
  private let displays: () -> [MenuBarDisplay]
  private let isLeftToRight: () -> Bool
  private let alwaysHiddenPresentationStyle: () -> AlwaysHiddenPresentationStyle
  private let isSupportedOperatingSystem: () -> Bool
  private let isSupportedApplicationLocation: () -> Bool

  private var presentation: Presentation = .expanded
  private var cachedLayout: MenuBarLayout?
  private var assertion: NativeVisibilityAssertion?
  private var generation = 0
  private var alwaysHiddenEnabled = false
  private var protectCaptureIndicators = true
  private var latestSnapshot = MenuBarEngineSnapshot(
    status: .expanded,
    hiddenAppCount: 0,
    alwaysHiddenAppCount: 0,
    isHiddenSectionExpanded: false,
    isAlwaysHiddenSectionExpanded: false,
    error: nil
  )

  init(
    inventory: MenuBarInventoryProviding = AccessibilityMenuBarInventory(),
    visibility: NativeVisibilityProviding = NativeVisibilityClient(),
    captureActivity: CaptureActivityMonitoring = CaptureActivityMonitor(),
    ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
    displays: @escaping () -> [MenuBarDisplay] = MenuBarDisplayInventory.current,
    isLeftToRight: (() -> Bool)? = nil,
    alwaysHiddenPresentationStyle: @escaping () -> AlwaysHiddenPresentationStyle = {
      let displays = NSScreen.screens.map { screen in
        NativeOverflowGeometry.Display(
          width: screen.frame.width,
          statusAreaWidth: screen.auxiliaryTopRightArea?.width
        )
      }
      return AlwaysHiddenPresentationStyle.resolve(displays: displays)
    },
    isSupportedOperatingSystem: @escaping () -> Bool = {
      ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    },
    isSupportedApplicationLocation: @escaping () -> Bool = {
      ApplicationLocation.isSupported(Bundle.main.bundleURL)
    }
  ) {
    self.inventory = inventory
    self.visibility = visibility
    self.captureActivity = captureActivity
    self.ownBundleIdentifier = ownBundleIdentifier
    self.displays = displays
    self.isLeftToRight =
      isLeftToRight ?? {
        NSApplication.shared.userInterfaceLayoutDirection == .leftToRight
      }
    self.alwaysHiddenPresentationStyle = alwaysHiddenPresentationStyle
    self.isSupportedOperatingSystem = isSupportedOperatingSystem
    self.isSupportedApplicationLocation = isSupportedApplicationLocation

    captureActivity.onChange = { [weak self] isActive in
      Task { @MainActor in
        self?.captureActivityChanged(isActive: isActive)
      }
    }
    captureActivity.start()
  }

  var requiresVisibilityAssertion: Bool {
    switch presentation {
    case .collapsed:
      return true
    case .expanded:
      return alwaysHiddenEnabled && alwaysHiddenPresentationStyle() == .customControl
    case .fullyExpanded, .arranging:
      return false
    }
  }

  var requiresEnvironmentReapply: Bool {
    switch presentation {
    case .arranging:
      return false
    case .collapsed:
      return true
    case .expanded, .fullyExpanded:
      return alwaysHiddenEnabled
    }
  }

  var isNativeMechanismAvailable: Bool {
    isSupportedOperatingSystem() && visibility.isAvailable
  }

  func configure(alwaysHiddenEnabled: Bool, protectCaptureIndicators: Bool) {
    let alwaysHiddenChanged = self.alwaysHiddenEnabled != alwaysHiddenEnabled
    self.alwaysHiddenEnabled = alwaysHiddenEnabled
    self.protectCaptureIndicators = protectCaptureIndicators

    if alwaysHiddenChanged {
      cachedLayout = nil
      arrange()
    } else if !protectCaptureIndicators, latestSnapshot.status == .pausedForCapture {
      reapplyCurrentPresentation()
    } else if protectCaptureIndicators, captureActivity.isActive, assertion != nil {
      captureActivityChanged(isActive: true)
    }
  }

  func collapse() {
    presentation = .collapsed
    showArrangementBoundaryIfNeeded()

    guard validateAvailabilityAndPermission() else { return }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(status: .pausedForCapture)
      return
    }

    if let cachedLayout {
      apply(cachedLayout, for: .collapsed)
    } else {
      scanAndApply(.collapsed)
    }
  }

  func expand() {
    presentation = .expanded
    showArrangementBoundaryIfNeeded()

    guard alwaysHiddenEnabled else {
      releaseAssertion()
      boundaryProvider?.setAlwaysHiddenBoundaryMode(.disabled)
      publish(status: .expanded, error: nil)
      return
    }

    guard validateAvailabilityAndPermission() else {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      return
    }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(status: .pausedForCapture)
      return
    }

    if let cachedLayout {
      apply(cachedLayout, for: .expanded)
    } else {
      releaseAssertion()
      scanAndApply(.expanded)
    }
  }

  func toggleAlwaysHiddenSection() {
    guard alwaysHiddenEnabled,
      alwaysHiddenPresentationStyle() == .customControl,
      presentation != .collapsed
    else {
      return
    }

    switch presentation {
    case .expanded:
      expandAlwaysHiddenSection()
    case .fullyExpanded:
      collapseAlwaysHiddenSection()
    case .collapsed, .arranging:
      break
    }
  }

  private func expandAlwaysHiddenSection() {
    presentation = .fullyExpanded
    boundaryProvider?.setAlwaysHiddenBoundaryMode(.customControl(isExpanded: true))

    guard validateAvailabilityAndPermission() else { return }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(status: .pausedForCapture)
      return
    }

    if let cachedLayout {
      apply(cachedLayout, for: .fullyExpanded)
    } else {
      scanAndApply(.fullyExpanded)
    }
  }

  private func collapseAlwaysHiddenSection() {
    presentation = .expanded
    boundaryProvider?.setAlwaysHiddenBoundaryMode(.customControl(isExpanded: false))

    guard validateAvailabilityAndPermission() else { return }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(status: .pausedForCapture)
      return
    }

    if let cachedLayout {
      apply(cachedLayout, for: .expanded)
    } else {
      scanAndApply(.expanded)
    }
  }

  func arrange() {
    presentation = .arranging
    cachedLayout = nil
    releaseAssertion()
    showArrangementBoundaryIfNeeded()
    publish(status: .arranging, hiddenCount: 0, alwaysHiddenCount: 0, error: nil)
  }

  func invalidateLayout() {
    cachedLayout = nil
    releaseAssertion()
    showArrangementBoundaryIfNeeded()
    publish(status: requiresVisibilityAssertion ? .scanning : .expanded, error: nil)
  }

  func reapplyCurrentPresentation() {
    switch presentation {
    case .collapsed: collapse()
    case .expanded: expand()
    case .fullyExpanded:
      if alwaysHiddenPresentationStyle() == .nativeOverflow {
        presentation = .expanded
        expand()
      } else {
        expandAlwaysHiddenSection()
      }
    case .arranging: arrange()
    }
  }

  func shutdown() {
    captureActivity.stop()
    presentation = .expanded
    releaseAssertion()
    boundaryProvider?.setAlwaysHiddenBoundaryMode(.disabled)
  }

  private func validateAvailabilityAndPermission() -> Bool {
    guard isSupportedApplicationLocation() else {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      Self.logger.error("Refusing to hide: MenuBarFold is not running from /Applications")
      let message = "Install MenuBarFold in /Applications before hiding menu bar icons."
      publish(status: .unavailable(message), error: message)
      return false
    }

    guard isSupportedOperatingSystem() else {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(
        status: .unavailable("MenuBarFold requires macOS 27 or newer."),
        error: "MenuBarFold requires macOS 27 or newer."
      )
      return false
    }

    guard visibility.isAvailable else {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(
        status: .unavailable("The macOS 27 menu bar visibility service is unavailable."),
        error: "The macOS 27 menu bar visibility service is unavailable."
      )
      return false
    }

    guard inventory.isAuthorized else {
      releaseAssertion()
      inventory.requestAuthorization()
      publish(status: .needsAccessibility, error: nil)
      return false
    }

    return true
  }

  private func scanAndApply(_ target: Presentation) {
    releaseAssertion()
    showArrangementBoundaryIfNeeded()

    generation += 1
    let requestGeneration = generation
    publish(status: .scanning, error: nil)

    guard let boundaryProvider else {
      publish(
        status: .unavailable("The menu bar boundary is not ready yet."),
        error: "The menu bar boundary is not ready yet."
      )
      return
    }

    boundaryProvider.afterMenuBarLayoutSettles { [weak self] in
      guard let self, requestGeneration == self.generation else { return }
      self.readLayoutAndApply(target, requestGeneration: requestGeneration)
    }
  }

  private func readLayoutAndApply(_ target: Presentation, requestGeneration: Int) {
    guard let boundaryFrame = boundaryProvider?.toggleBoundaryFrame else {
      releaseAssertion()
      publish(
        status: .unavailable("The menu bar boundary is not ready yet."),
        error: "The menu bar boundary is not ready yet."
      )
      return
    }

    let alwaysHiddenBoundaryFrame =
      alwaysHiddenEnabled
      ? boundaryProvider?.alwaysHiddenBoundaryFrame
      : nil

    if alwaysHiddenEnabled, alwaysHiddenBoundaryFrame == nil {
      releaseAssertion()
      publish(
        status: .unavailable("The always-hidden boundary is not ready yet."),
        error: "The always-hidden boundary is not ready yet."
      )
      return
    }

    let displaySnapshot = displays()
    Self.logger.info(
      "Reading menu bar layout: \(displaySnapshot.count, privacy: .public) display(s), toggle=\(String(describing: boundaryFrame), privacy: .public), alwaysHidden=\(String(describing: alwaysHiddenBoundaryFrame), privacy: .public)"
    )
    for display in displaySnapshot {
      Self.logger.info(
        "Display \(display.identifier, privacy: .public): AppKit=\(String(describing: display.appKitFrame), privacy: .public), AX=\(String(describing: display.accessibilityFrame), privacy: .public)"
      )
    }

    inventory.snapshot { [weak self] inventoryItems in
      guard let self, requestGeneration == self.generation else { return }

      guard
        let layout = MenuBarLayoutResolver.resolve(
          inventory: inventoryItems,
          boundaryFrame: boundaryFrame,
          alwaysHiddenBoundaryFrame: alwaysHiddenBoundaryFrame,
          displays: displaySnapshot,
          isLeftToRight: self.isLeftToRight(),
          excludingBundle: self.ownBundleIdentifier
        )
      else {
        Self.logger.error(
          "Menu bar layout is incomplete for \(displaySnapshot.count, privacy: .public) display(s) and \(inventoryItems.count, privacy: .public) status item(s); failing open"
        )
        self.releaseAssertion()
        self.showArrangementBoundaryIfNeeded()
        self.publish(
          status: .unavailable("The complete menu bar layout could not be read safely."),
          error: "The complete menu bar layout could not be read safely."
        )
        return
      }

      self.cachedLayout = layout
      Self.logger.info(
        "Resolved menu bar layout: visible=\(layout.bundles(in: [.visible]).count, privacy: .public), hidden=\(layout.bundles(in: [.hidden]).count, privacy: .public), alwaysHidden=\(layout.bundles(in: [.alwaysHidden]).count, privacy: .public)"
      )
      self.apply(layout, for: target)
    }
  }

  private func apply(_ layout: MenuBarLayout, for target: Presentation) {
    let hiddenCount = layout.bundles(in: [.hidden]).count
    let alwaysHiddenCount = layout.bundles(in: [.alwaysHidden]).count

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(
        status: .pausedForCapture,
        hiddenCount: hiddenCount,
        alwaysHiddenCount: alwaysHiddenCount,
        error: nil
      )
      return
    }

    let presentationStyle = alwaysHiddenPresentationStyle()
    let allowedSections: Set<MenuBarSection>
    let resultingStatus: AppStatus

    switch target {
    case .collapsed:
      allowedSections =
        alwaysHiddenEnabled && presentationStyle == .nativeOverflow
        ? [.visible, .alwaysHidden]
        : [.visible]
      resultingStatus = .collapsed
    case .expanded:
      if presentationStyle == .nativeOverflow || !alwaysHiddenEnabled || alwaysHiddenCount == 0 {
        releaseAssertion()
        showAlwaysHiddenPresentationIfNeeded(
          alwaysHiddenCount: alwaysHiddenCount,
          style: presentationStyle,
          isExpanded: false
        )
        publish(
          status: .expanded,
          hiddenCount: hiddenCount,
          alwaysHiddenCount: alwaysHiddenCount,
          error: nil
        )
        return
      }
      allowedSections = [.visible, .hidden]
      resultingStatus = .expanded
    case .fullyExpanded:
      releaseAssertion()
      showAlwaysHiddenPresentationIfNeeded(
        alwaysHiddenCount: alwaysHiddenCount,
        style: presentationStyle,
        isExpanded: true
      )
      publish(
        status: .expanded,
        hiddenCount: hiddenCount,
        alwaysHiddenCount: alwaysHiddenCount,
        error: nil
      )
      return
    case .arranging:
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(
        status: .arranging,
        hiddenCount: hiddenCount,
        alwaysHiddenCount: alwaysHiddenCount,
        error: nil
      )
      return
    }

    let allowedBundles = layout.bundles(in: allowedSections)
    let allowedWithSelf = Array(Set(allowedBundles + [ownBundleIdentifier].compactMap { $0 }))
      .sorted()

    generation += 1
    let activationGeneration = generation
    visibility.activate(
      allowedSystemItems: Self.systemItemsToKeep,
      allowedBundleIdentifiers: allowedWithSelf
    ) { [weak self] result in
      guard let self else {
        if case .success(let staleAssertion) = result {
          staleAssertion.invalidate()
        }
        return
      }

      guard activationGeneration == self.generation else {
        if case .success(let staleAssertion) = result {
          staleAssertion.invalidate()
        }
        return
      }

      switch result {
      case .success(let newAssertion):
        if self.protectCaptureIndicators, self.captureActivity.isActive {
          newAssertion.invalidate()
          self.releaseAssertion()
          self.showArrangementBoundaryIfNeeded()
          self.publish(
            status: .pausedForCapture,
            hiddenCount: hiddenCount,
            alwaysHiddenCount: alwaysHiddenCount,
            error: nil
          )
          return
        }

        let previousAssertion = self.assertion
        self.assertion = newAssertion
        previousAssertion?.invalidate()
        let restrictedBundleCount = max(layout.sections.count - allowedBundles.count, 0)
        Self.logger.info(
          "Visibility restriction active: allowedBundles=\(allowedWithSelf.count, privacy: .public), restrictedBundles=\(restrictedBundleCount, privacy: .public)"
        )
        self.showAlwaysHiddenPresentationIfNeeded(
          alwaysHiddenCount: alwaysHiddenCount,
          style: presentationStyle,
          isExpanded: false
        )
        self.publish(
          status: resultingStatus,
          hiddenCount: hiddenCount,
          alwaysHiddenCount: alwaysHiddenCount,
          error: nil
        )
      case .failure(let error):
        Self.logger.error(
          "Visibility activation failed: \(error.localizedDescription, privacy: .public)"
        )
        self.releaseAssertion()
        self.showArrangementBoundaryIfNeeded()
        self.publish(
          status: .unavailable(error.localizedDescription),
          hiddenCount: hiddenCount,
          alwaysHiddenCount: alwaysHiddenCount,
          error: error.localizedDescription
        )
      }
    }
  }

  private func captureActivityChanged(isActive: Bool) {
    guard protectCaptureIndicators else { return }

    if isActive {
      guard presentation != .arranging else { return }
      releaseAssertion()
      showArrangementBoundaryIfNeeded()
      publish(status: .pausedForCapture, error: nil)
    } else if presentation != .arranging {
      cachedLayout = nil
      reapplyCurrentPresentation()
    }
  }

  private func releaseAssertion() {
    generation += 1
    assertion?.invalidate()
    assertion = nil
  }

  private func showArrangementBoundaryIfNeeded() {
    boundaryProvider?.setAlwaysHiddenBoundaryMode(alwaysHiddenEnabled ? .boundary : .disabled)
  }

  private func showAlwaysHiddenPresentationIfNeeded(
    alwaysHiddenCount: Int,
    style: AlwaysHiddenPresentationStyle,
    isExpanded: Bool
  ) {
    Self.logger.info(
      "Always-hidden presentation: style=\(String(describing: style), privacy: .public), count=\(alwaysHiddenCount, privacy: .public), expanded=\(isExpanded, privacy: .public)"
    )
    let mode: AlwaysHiddenBoundaryMode
    if !alwaysHiddenEnabled || alwaysHiddenCount == 0 {
      mode = .disabled
    } else {
      switch style {
      case .nativeOverflow:
        mode = .nativeOverflow
      case .customControl:
        switch presentation {
        case .collapsed:
          mode = .disabled
        case .expanded, .fullyExpanded:
          mode = .customControl(isExpanded: isExpanded)
        case .arranging:
          mode = .boundary
        }
      }
    }
    boundaryProvider?.setAlwaysHiddenBoundaryMode(mode)
  }

  private func publish(
    status: AppStatus,
    hiddenCount: Int? = nil,
    alwaysHiddenCount: Int? = nil,
    error: String? = nil
  ) {
    latestSnapshot = MenuBarEngineSnapshot(
      status: status,
      hiddenAppCount: hiddenCount ?? latestSnapshot.hiddenAppCount,
      alwaysHiddenAppCount: alwaysHiddenCount ?? latestSnapshot.alwaysHiddenAppCount,
      isHiddenSectionExpanded: presentation != .collapsed,
      isAlwaysHiddenSectionExpanded: presentation == .fullyExpanded,
      error: error
    )
    onSnapshot?(latestSnapshot)
  }
}
