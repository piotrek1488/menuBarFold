import AppKit
import Foundation

@MainActor
final class StatusBarController: NSObject, MenuBarBoundaryProviding {
  private let model: AppModel
  private let engine: NativeMenuBarEngine
  private let launchAtLoginService: LaunchAtLoginServicing
  private let hotKeyManager = GlobalHotKeyManager()

  private let toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let alwaysHiddenItem = NSStatusBar.system.statusItem(withLength: 18)

  private var autoCollapseTimer: Timer?
  private var permissionTimer: Timer?
  private var hoverMonitor: Any?
  private var hoverDwellTimer: Timer?
  private var environmentReapplyWorkItem: DispatchWorkItem?

  var isSettingsWindowVisible: (() -> Bool)?

  init(
    model: AppModel,
    engine: NativeMenuBarEngine? = nil,
    launchAtLoginService: LaunchAtLoginServicing = LaunchAtLoginService()
  ) {
    self.model = model
    self.engine = engine ?? NativeMenuBarEngine()
    self.launchAtLoginService = launchAtLoginService
    super.init()

    configureStatusItems()
    self.engine.boundaryProvider = self
    self.engine.onSnapshot = { [weak self] snapshot in
      self?.apply(snapshot)
    }

    model.onToggle = { [weak self] in self?.toggle() }
    model.onArrange = { [weak self] in self?.beginArranging() }
    model.onRequestAccessibility = {
      AccessibilityPermissionService.request()
    }
    model.onOpenAccessibilitySettings = {
      AccessibilityPermissionService.openSystemSettings()
    }
    model.onPreferenceChange = { [weak self] change in
      self?.preferenceChanged(change)
    }

    self.engine.configure(
      alwaysHiddenEnabled: model.alwaysHiddenEnabled,
      protectCaptureIndicators: model.protectCaptureIndicators
    )
    synchronizeLaunchAtLogin()
    registerShortcut()
    configureHoverMonitor()
    startPermissionMonitoring()
    observeEnvironmentChanges()

    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.performInitialPresentation()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    autoCollapseTimer?.invalidate()
    permissionTimer?.invalidate()
    hoverDwellTimer?.invalidate()
    if let hoverMonitor {
      NSEvent.removeMonitor(hoverMonitor)
    }
  }

  var toggleBoundaryFrame: CGRect? {
    toggleItem.button?.window?.frame
  }

  var alwaysHiddenBoundaryFrame: CGRect? {
    guard alwaysHiddenItem.isVisible else { return nil }
    return alwaysHiddenItem.button?.window?.frame
  }

  func setAlwaysHiddenBoundaryVisible(_ visible: Bool) {
    alwaysHiddenItem.length = visible ? 18 : 0
    alwaysHiddenItem.isVisible = visible
  }

  func shutdown() {
    autoCollapseTimer?.invalidate()
    engine.shutdown()
    setAlwaysHiddenBoundaryVisible(model.alwaysHiddenEnabled)
  }

  private func configureStatusItems() {
    toggleItem.autosaveName = "MenuBarFold.ToggleBoundary"
    toggleItem.isVisible = true

    if let button = toggleItem.button {
      button.target = self
      button.action = #selector(toggleItemPressed(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      button.imagePosition = .imageOnly
    }

    alwaysHiddenItem.autosaveName = "MenuBarFold.AlwaysHiddenBoundary"
    alwaysHiddenItem.isVisible = true
    if let button = alwaysHiddenItem.button {
      button.image = NSImage(
        systemSymbolName: "line.vertical",
        accessibilityDescription: "Always hidden boundary"
      )
      button.image?.isTemplate = true
      button.target = self
      button.action = #selector(alwaysHiddenItemPressed(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      button.toolTip = "MenuBarFold"
    }
    setAlwaysHiddenBoundaryVisible(model.alwaysHiddenEnabled)
    updateStatusItemAppearance()
  }

  private func performInitialPresentation() {
    model.refreshAccessibilityStatus()
    guard model.hasCompletedOnboarding, model.isAccessibilityGranted else {
      engine.arrange()
      return
    }
    collapse()
  }

  private func toggle() {
    switch model.status {
    case .collapsed, .pausedForCapture, .scanning:
      expand()
    case .expanded, .arranging, .needsAccessibility, .unavailable:
      collapse()
    }
  }

  private func collapse() {
    autoCollapseTimer?.invalidate()
    engine.collapse()
  }

  private func expand() {
    engine.expand()
    scheduleAutoCollapseIfNeeded()
  }

  private func beginArranging() {
    autoCollapseTimer?.invalidate()
    engine.arrange()
  }

  @objc
  private func toggleItemPressed(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp {
      showContextMenu(from: sender)
    } else if event?.modifierFlags.contains(.option) == true {
      beginArranging()
    } else {
      toggle()
    }
  }

  @objc
  private func alwaysHiddenItemPressed(_ sender: NSStatusBarButton) {
    showContextMenu(from: sender)
  }

  private func showContextMenu(from button: NSStatusBarButton) {
    let language = model.language
    let menu = NSMenu()

    let toggleTitle =
      model.status.isCollapsedIntent
      ? L10n.string("menu.expand", language: language)
      : L10n.string("menu.collapse", language: language)
    menu.addItem(
      withTitle: toggleTitle,
      action: #selector(toggleFromMenu),
      keyEquivalent: ""
    ).target = self

    let arrangeItem = menu.addItem(
      withTitle: L10n.string("menu.arrange", language: language),
      action: #selector(arrangeFromMenu),
      keyEquivalent: ""
    )
    arrangeItem.target = self

    menu.addItem(.separator())

    let autoItem = menu.addItem(
      withTitle: L10n.string("menu.autoCollapse", language: language),
      action: #selector(toggleAutoCollapseFromMenu),
      keyEquivalent: ""
    )
    autoItem.target = self
    autoItem.state = model.autoCollapseEnabled ? .on : .off

    let settingsItem = menu.addItem(
      withTitle: L10n.string("menu.settings", language: language),
      action: #selector(showSettingsFromMenu),
      keyEquivalent: ","
    )
    settingsItem.target = self

    menu.addItem(.separator())

    let quitItem = menu.addItem(
      withTitle: L10n.string("menu.quit", language: language),
      action: #selector(quitFromMenu),
      keyEquivalent: "q"
    )
    quitItem.target = self

    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button)
  }

  @objc private func toggleFromMenu() { toggle() }
  @objc private func arrangeFromMenu() { beginArranging() }
  @objc private func showSettingsFromMenu() { model.showSettings() }
  @objc private func quitFromMenu() { NSApp.terminate(nil) }

  @objc
  private func toggleAutoCollapseFromMenu() {
    model.autoCollapseEnabled.toggle()
  }

  private func apply(_ snapshot: MenuBarEngineSnapshot) {
    let previousStatus = model.status
    model.status = snapshot.status
    model.hiddenAppCount = snapshot.hiddenAppCount
    model.alwaysHiddenAppCount = snapshot.alwaysHiddenAppCount
    model.lastError = snapshot.error
    updateStatusItemAppearance()

    if snapshot.status == .expanded, previousStatus != .expanded {
      scheduleAutoCollapseIfNeeded()
    }
  }

  private func updateStatusItemAppearance() {
    let language = model.language
    let symbolName: String
    let descriptionKey: String

    switch model.status {
    case .collapsed:
      symbolName = "chevron.right"
      descriptionKey = "status.collapsed"
    case .pausedForCapture:
      symbolName = "shield.lefthalf.filled"
      descriptionKey = "status.pausedForCapture"
    case .scanning:
      symbolName = "ellipsis"
      descriptionKey = "status.scanning"
    case .needsAccessibility:
      symbolName = "exclamationmark.triangle"
      descriptionKey = "status.needsAccessibility"
    case .unavailable:
      symbolName = "exclamationmark.circle"
      descriptionKey = "status.unavailable"
    case .expanded, .arranging:
      symbolName = "chevron.left"
      descriptionKey = model.status == .arranging ? "status.arranging" : "status.expanded"
    }

    let description = L10n.string(descriptionKey, language: language)
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
    image?.isTemplate = true
    toggleItem.button?.image = image
    toggleItem.button?.toolTip = "MenuBarFold — \(description)"
    toggleItem.button?.setAccessibilityLabel(description)
  }

  private func preferenceChanged(_ change: PreferenceChange) {
    switch change {
    case .launchAtLogin:
      updateLaunchAtLogin()
    case .autoCollapse:
      scheduleAutoCollapseIfNeeded()
    case .hoverToReveal:
      configureHoverMonitor()
    case .alwaysHidden, .captureProtection:
      engine.configure(
        alwaysHiddenEnabled: model.alwaysHiddenEnabled,
        protectCaptureIndicators: model.protectCaptureIndicators
      )
    case .shortcut:
      registerShortcut()
    case .language:
      updateStatusItemAppearance()
    }
  }

  private func synchronizeLaunchAtLogin() {
    model.setLaunchAtLoginFromService(launchAtLoginService.isEnabled)
  }

  private func updateLaunchAtLogin() {
    do {
      try launchAtLoginService.setEnabled(model.launchAtLoginEnabled)
      model.lastError = nil
    } catch {
      model.setLaunchAtLoginFromService(launchAtLoginService.isEnabled)
      model.lastError = error.localizedDescription
    }
  }

  private func registerShortcut() {
    do {
      try hotKeyManager.register(model.shortcutPreset) { [weak self] in
        Task { @MainActor in self?.toggle() }
      }
    } catch {
      model.lastError = error.localizedDescription
    }
  }

  private func scheduleAutoCollapseIfNeeded() {
    autoCollapseTimer?.invalidate()
    guard model.autoCollapseEnabled,
      model.status == .expanded,
      model.autoCollapseDelay > 0
    else {
      return
    }

    autoCollapseTimer = Timer.scheduledTimer(
      withTimeInterval: model.autoCollapseDelay,
      repeats: false
    ) { [weak self] _ in
      Task { @MainActor in self?.autoCollapseTimerFired() }
    }
  }

  private func autoCollapseTimerFired() {
    if isMouseInMenuBar || isSettingsWindowVisible?() == true {
      scheduleAutoCollapseIfNeeded()
    } else {
      collapse()
    }
  }

  private var isMouseInMenuBar: Bool {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.contains { screen in
      mouseLocation.x >= screen.frame.minX
        && mouseLocation.x <= screen.frame.maxX
        && mouseLocation.y >= screen.visibleFrame.maxY
        && mouseLocation.y <= screen.frame.maxY
    }
  }

  private func configureHoverMonitor() {
    hoverDwellTimer?.invalidate()
    hoverDwellTimer = nil

    if let hoverMonitor {
      NSEvent.removeMonitor(hoverMonitor)
      self.hoverMonitor = nil
    }

    guard model.hoverToRevealEnabled else { return }
    hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
      Task { @MainActor in self?.mouseMovedForHoverReveal() }
    }
  }

  private func mouseMovedForHoverReveal() {
    guard model.status.isCollapsedIntent, isMouseInMenuBar else {
      hoverDwellTimer?.invalidate()
      hoverDwellTimer = nil
      return
    }

    guard hoverDwellTimer == nil else { return }
    hoverDwellTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) {
      [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        self.hoverDwellTimer = nil
        if self.model.status.isCollapsedIntent, self.isMouseInMenuBar {
          self.expand()
        }
      }
    }
  }

  private func startPermissionMonitoring() {
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        let wasGranted = self.model.isAccessibilityGranted
        self.model.refreshAccessibilityStatus()
        if !wasGranted, self.model.isAccessibilityGranted, self.model.hasCompletedOnboarding {
          self.engine.arrange()
        }
      }
    }
  }

  private func observeEnvironmentChanges() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(environmentChanged),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    workspaceCenter.addObserver(
      self,
      selector: #selector(environmentChanged),
      name: NSWorkspace.didLaunchApplicationNotification,
      object: nil
    )
    workspaceCenter.addObserver(
      self,
      selector: #selector(environmentChanged),
      name: NSWorkspace.didTerminateApplicationNotification,
      object: nil
    )
    workspaceCenter.addObserver(
      self,
      selector: #selector(environmentChanged),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
  }

  @objc
  private func environmentChanged() {
    let shouldReapplyCollapse = engine.wantsCollapsedPresentation
    environmentReapplyWorkItem?.cancel()
    engine.invalidateLayout()

    guard shouldReapplyCollapse else { return }
    let workItem = DispatchWorkItem { [weak self] in
      self?.collapse()
    }
    environmentReapplyWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
  }
}
