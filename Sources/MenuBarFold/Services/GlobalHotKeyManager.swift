import Carbon.HIToolbox
import Foundation

final class GlobalHotKeyManager {
  private var hotKeyReference: EventHotKeyRef?
  private var eventHandlerReference: EventHandlerRef?
  private var handler: (() -> Void)?

  private let hotKeyIdentifier = EventHotKeyID(
    signature: OSType(0x4D42_464B),  // MBFK
    id: 1
  )

  func register(_ preset: ShortcutPreset, handler: @escaping () -> Void) throws {
    unregister()
    guard let keyCode = preset.keyCode else { return }

    self.handler = handler
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let callback: EventHandlerUPP = { _, event, userData in
      guard let userData, let event else { return OSStatus(eventNotHandledErr) }
      let manager = Unmanaged<GlobalHotKeyManager>
        .fromOpaque(userData)
        .takeUnretainedValue()

      var identifier = EventHotKeyID()
      let result = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
      )

      guard result == noErr,
        identifier.signature == manager.hotKeyIdentifier.signature,
        identifier.id == manager.hotKeyIdentifier.id
      else {
        return OSStatus(eventNotHandledErr)
      }

      manager.handler?()
      return noErr
    }

    let installResult = InstallEventHandler(
      GetApplicationEventTarget(),
      callback,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandlerReference
    )
    guard installResult == noErr else {
      throw HotKeyError.installFailed(installResult)
    }

    let registerResult = RegisterEventHotKey(
      keyCode,
      preset.carbonModifiers,
      hotKeyIdentifier,
      GetApplicationEventTarget(),
      0,
      &hotKeyReference
    )
    guard registerResult == noErr else {
      unregister()
      throw HotKeyError.registrationFailed(registerResult)
    }
  }

  func unregister() {
    if let hotKeyReference {
      UnregisterEventHotKey(hotKeyReference)
    }
    if let eventHandlerReference {
      RemoveEventHandler(eventHandlerReference)
    }

    hotKeyReference = nil
    eventHandlerReference = nil
    handler = nil
  }

  deinit {
    unregister()
  }
}

enum HotKeyError: LocalizedError {
  case installFailed(OSStatus)
  case registrationFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .installFailed(let status):
      "Unable to install the global shortcut handler (\(status))."
    case .registrationFailed(let status):
      "The selected shortcut is unavailable (\(status))."
    }
  }
}
