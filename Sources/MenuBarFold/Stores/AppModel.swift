import AppKit
import ApplicationServices
import Foundation
import Observation

enum PreferenceChange {
  case launchAtLogin
  case autoCollapse
  case hoverToReveal
  case alwaysHidden
  case captureProtection
  case shortcut
  case language
}

@MainActor
@Observable
final class AppModel {
  private enum Key {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let autoCollapseEnabled = "autoCollapseEnabled"
    static let autoCollapseDelay = "autoCollapseDelay"
    static let hoverToRevealEnabled = "hoverToRevealEnabled"
    static let showSettingsOnLaunch = "showSettingsOnLaunch"
    static let alwaysHiddenEnabled = "alwaysHiddenEnabled"
    static let protectCaptureIndicators = "protectCaptureIndicators"
    static let language = "language"
    static let shortcutPreset = "shortcutPreset"
    static let launchAtLogin = "launchAtLogin"
  }

  private let defaults: UserDefaults
  private var isApplyingExternalValue = false

  var onPreferenceChange: ((PreferenceChange) -> Void)?
  var onToggle: (() -> Void)?
  var onArrange: (() -> Void)?
  var onShowSettings: (() -> Void)?
  var onRequestAccessibility: (() -> Void)?
  var onOpenAccessibilitySettings: (() -> Void)?

  var status: AppStatus = .expanded
  var isAccessibilityGranted: Bool
  var hiddenAppCount = 0
  var alwaysHiddenAppCount = 0
  var lastError: String?

  var hasCompletedOnboarding: Bool {
    didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
  }

  var launchAtLoginEnabled: Bool {
    didSet {
      defaults.set(launchAtLoginEnabled, forKey: Key.launchAtLogin)
      notify(.launchAtLogin)
    }
  }

  var autoCollapseEnabled: Bool {
    didSet {
      defaults.set(autoCollapseEnabled, forKey: Key.autoCollapseEnabled)
      notify(.autoCollapse)
    }
  }

  var autoCollapseDelay: Double {
    didSet {
      defaults.set(autoCollapseDelay, forKey: Key.autoCollapseDelay)
      notify(.autoCollapse)
    }
  }

  var hoverToRevealEnabled: Bool {
    didSet {
      defaults.set(hoverToRevealEnabled, forKey: Key.hoverToRevealEnabled)
      notify(.hoverToReveal)
    }
  }

  var showSettingsOnLaunch: Bool {
    didSet { defaults.set(showSettingsOnLaunch, forKey: Key.showSettingsOnLaunch) }
  }

  var alwaysHiddenEnabled: Bool {
    didSet {
      defaults.set(alwaysHiddenEnabled, forKey: Key.alwaysHiddenEnabled)
      notify(.alwaysHidden)
    }
  }

  var protectCaptureIndicators: Bool {
    didSet {
      defaults.set(protectCaptureIndicators, forKey: Key.protectCaptureIndicators)
      notify(.captureProtection)
    }
  }

  var language: AppLanguage {
    didSet {
      defaults.set(language.rawValue, forKey: Key.language)
      notify(.language)
    }
  }

  var shortcutPreset: ShortcutPreset {
    didSet {
      defaults.set(shortcutPreset.rawValue, forKey: Key.shortcutPreset)
      notify(.shortcut)
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      Key.hasCompletedOnboarding: false,
      Key.autoCollapseEnabled: true,
      Key.autoCollapseDelay: 10.0,
      Key.hoverToRevealEnabled: false,
      Key.showSettingsOnLaunch: true,
      Key.alwaysHiddenEnabled: false,
      Key.protectCaptureIndicators: true,
      Key.language: AppLanguage.english.rawValue,
      Key.shortcutPreset: ShortcutPreset.optionCommandH.rawValue,
      Key.launchAtLogin: false,
    ])

    hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    launchAtLoginEnabled = defaults.bool(forKey: Key.launchAtLogin)
    autoCollapseEnabled = defaults.bool(forKey: Key.autoCollapseEnabled)
    autoCollapseDelay = defaults.double(forKey: Key.autoCollapseDelay)
    hoverToRevealEnabled = defaults.bool(forKey: Key.hoverToRevealEnabled)
    showSettingsOnLaunch = defaults.bool(forKey: Key.showSettingsOnLaunch)
    alwaysHiddenEnabled = defaults.bool(forKey: Key.alwaysHiddenEnabled)
    protectCaptureIndicators = defaults.bool(forKey: Key.protectCaptureIndicators)
    language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .english
    shortcutPreset =
      ShortcutPreset(rawValue: defaults.string(forKey: Key.shortcutPreset) ?? "") ?? .optionCommandH
    isAccessibilityGranted = AXIsProcessTrusted()
  }

  func setLaunchAtLoginFromService(_ value: Bool) {
    isApplyingExternalValue = true
    launchAtLoginEnabled = value
    isApplyingExternalValue = false
  }

  func refreshAccessibilityStatus() {
    isAccessibilityGranted = AXIsProcessTrusted()
    if isAccessibilityGranted, status == .needsAccessibility {
      status = .expanded
    }
  }

  func toggle() {
    onToggle?()
  }

  func beginArranging() {
    onArrange?()
  }

  func showSettings() {
    onShowSettings?()
  }

  func requestAccessibility() {
    onRequestAccessibility?()
  }

  func openAccessibilitySettings() {
    onOpenAccessibilitySettings?()
  }

  func finishOnboarding() {
    hasCompletedOnboarding = true
    beginArranging()
  }

  var languageName: String {
    switch language {
    case .system: L10n.string("language.system", language: language)
    case .english: "English"
    case .polish: "Polski"
    }
  }

  private func notify(_ change: PreferenceChange) {
    guard !isApplyingExternalValue else { return }
    onPreferenceChange?(change)
  }
}
