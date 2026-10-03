import AppKit
import Foundation

@MainActor
protocol MenuBarBoundaryProviding: AnyObject {
  var toggleBoundaryFrame: CGRect? { get }
  var alwaysHiddenBoundaryFrame: CGRect? { get }
  func setAlwaysHiddenControlsVisible(_ visible: Bool)
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
  private let isSupportedOperatingSystem: () -> Bool

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
    isSupportedOperatingSystem: @escaping () -> Bool = {
      ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
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
    self.isSupportedOperatingSystem = isSupportedOperatingSystem

    captureActivity.onChange = { [weak self] isActive in
      Task { @MainActor in
        self?.captureActivityChanged(isActive: isActive)
      }
    }
    captureActivity.start()
  }

  var requiresVisibilityAssertion: Bool {
    presentation == .collapsed || (presentation == .expanded && alwaysHiddenEnabled)
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
    updateAlwaysHiddenControlsVisibility()

    guard validateAvailabilityAndPermission() else { return }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      updateAlwaysHiddenControlsVisibility()
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
    updateAlwaysHiddenControlsVisibility()

    guard alwaysHiddenEnabled else {
      releaseAssertion()
      publish(status: .expanded, error: nil)
      return
    }

    guard validateAvailabilityAndPermission() else {
      releaseAssertion()
      updateAlwaysHiddenControlsVisibility()
      return
    }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      updateAlwaysHiddenControlsVisibility()
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
    guard alwaysHiddenEnabled, presentation != .collapsed else { return }

    switch presentation {
    case .expanded:
      expandAlwaysHiddenSection()
    case .fullyExpanded, .arranging:
      collapseAlwaysHiddenSection()
    case .collapsed:
      break
    }
  }

  private func expandAlwaysHiddenSection() {
    presentation = .fullyExpanded
    updateAlwaysHiddenControlsVisibility()

    guard validateAvailabilityAndPermission() else { return }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      updateAlwaysHiddenControlsVisibility()
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
    updateAlwaysHiddenControlsVisibility()

    guard validateAvailabilityAndPermission() else { return }

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      updateAlwaysHiddenControlsVisibility()
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
    updateAlwaysHiddenControlsVisibility()
    publish(status: .arranging, hiddenCount: 0, alwaysHiddenCount: 0, error: nil)
  }

  func invalidateLayout() {
    cachedLayout = nil
    releaseAssertion()
    updateAlwaysHiddenControlsVisibility()
    publish(status: requiresVisibilityAssertion ? .scanning : .expanded, error: nil)
  }

  func reapplyCurrentPresentation() {
    switch presentation {
    case .collapsed: collapse()
    case .expanded: expand()
    case .fullyExpanded: expandAlwaysHiddenSection()
    case .arranging: arrange()
    }
  }

  func shutdown() {
    captureActivity.stop()
    presentation = .expanded
    releaseAssertion()
    updateAlwaysHiddenControlsVisibility()
  }

  private func validateAvailabilityAndPermission() -> Bool {
    guard isSupportedOperatingSystem() else {
      releaseAssertion()
      publish(
        status: .unavailable("MenuBarFold requires macOS 27 or newer."),
        error: "MenuBarFold requires macOS 27 or newer."
      )
      return false
    }

    guard visibility.isAvailable else {
      releaseAssertion()
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

    generation += 1
    let requestGeneration = generation
    publish(status: .scanning, error: nil)

    inventory.snapshot { [weak self] inventoryItems in
      guard let self, requestGeneration == self.generation else { return }

      guard
        let layout = MenuBarLayoutResolver.resolve(
          inventory: inventoryItems,
          boundaryFrame: boundaryFrame,
          alwaysHiddenBoundaryFrame: alwaysHiddenBoundaryFrame,
          displays: self.displays(),
          isLeftToRight: self.isLeftToRight(),
          excludingBundle: self.ownBundleIdentifier
        )
      else {
        self.releaseAssertion()
        self.updateAlwaysHiddenControlsVisibility()
        self.publish(
          status: .unavailable("The complete menu bar layout could not be read safely."),
          error: "The complete menu bar layout could not be read safely."
        )
        return
      }

      self.cachedLayout = layout
      self.apply(layout, for: target)
    }
  }

  private func apply(_ layout: MenuBarLayout, for target: Presentation) {
    let hiddenCount = layout.bundles(in: [.hidden]).count
    let alwaysHiddenCount = layout.bundles(in: [.alwaysHidden]).count

    if protectCaptureIndicators, captureActivity.isActive {
      releaseAssertion()
      updateAlwaysHiddenControlsVisibility()
      publish(
        status: .pausedForCapture,
        hiddenCount: hiddenCount,
        alwaysHiddenCount: alwaysHiddenCount,
        error: nil
      )
      return
    }

    let allowedSections: Set<MenuBarSection>
    let resultingStatus: AppStatus

    switch target {
    case .collapsed:
      allowedSections = [.visible]
      resultingStatus = .collapsed
    case .expanded:
      if !alwaysHiddenEnabled || alwaysHiddenCount == 0 {
        releaseAssertion()
        updateAlwaysHiddenControlsVisibility()
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
      updateAlwaysHiddenControlsVisibility()
      publish(
        status: .expanded,
        hiddenCount: hiddenCount,
        alwaysHiddenCount: alwaysHiddenCount,
        error: nil
      )
      return
    case .arranging:
      releaseAssertion()
      updateAlwaysHiddenControlsVisibility()
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
        self.updateAlwaysHiddenControlsVisibility()
        self.publish(
          status: resultingStatus,
          hiddenCount: hiddenCount,
          alwaysHiddenCount: alwaysHiddenCount,
          error: nil
        )
      case .failure(let error):
        self.releaseAssertion()
        self.updateAlwaysHiddenControlsVisibility()
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
      updateAlwaysHiddenControlsVisibility()
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

  private func updateAlwaysHiddenControlsVisibility() {
    let shouldShow = alwaysHiddenEnabled && presentation != .collapsed
    boundaryProvider?.setAlwaysHiddenControlsVisible(shouldShow)
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
      isAlwaysHiddenSectionExpanded: presentation == .fullyExpanded || presentation == .arranging,
      error: error
    )
    onSnapshot?(latestSnapshot)
  }
}
