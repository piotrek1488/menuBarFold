import Foundation

enum AppStatus: Equatable {
  case expanded
  case arranging
  case scanning
  case collapsed
  case pausedForCapture
  case needsAccessibility
  case unavailable(String)
}

enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case english
  case polish

  var id: String { rawValue }

  var localizationCode: String? {
    switch self {
    case .system: nil
    case .english: "en"
    case .polish: "pl"
    }
  }
}

enum SettingsSection: String, CaseIterable, Identifiable {
  case overview
  case behavior
  case shortcuts
  case about

  var id: String { rawValue }

  var systemImage: String {
    switch self {
    case .overview: "rectangle.topthird.inset.filled"
    case .behavior: "switch.2"
    case .shortcuts: "keyboard"
    case .about: "info.circle"
    }
  }
}
