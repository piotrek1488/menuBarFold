import Carbon.HIToolbox
import Foundation

enum ShortcutPreset: String, CaseIterable, Identifiable {
  case disabled
  case optionCommandH
  case controlOptionM
  case function18

  var id: String { rawValue }

  var keyCode: UInt32? {
    switch self {
    case .disabled: nil
    case .optionCommandH: UInt32(kVK_ANSI_H)
    case .controlOptionM: UInt32(kVK_ANSI_M)
    case .function18: UInt32(kVK_F18)
    }
  }

  var carbonModifiers: UInt32 {
    switch self {
    case .disabled, .function18: 0
    case .optionCommandH: UInt32(optionKey | cmdKey)
    case .controlOptionM: UInt32(controlKey | optionKey)
    }
  }

  var displayValue: String {
    switch self {
    case .disabled: "—"
    case .optionCommandH: "⌥⌘H"
    case .controlOptionM: "⌃⌥M"
    case .function18: "F18"
    }
  }
}
