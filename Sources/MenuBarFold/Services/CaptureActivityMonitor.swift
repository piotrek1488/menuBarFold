import CoreAudio
import CoreMediaIO
import Foundation

protocol CaptureActivityMonitoring: AnyObject {
  var isActive: Bool { get }
  var onChange: ((Bool) -> Void)? { get set }
  func start()
  func stop()
}

final class CaptureActivityMonitor: CaptureActivityMonitoring {
  var onChange: ((Bool) -> Void)?
  private(set) var isActive = false
  private var timer: Timer?

  func start() {
    guard timer == nil else { return }
    refresh()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.refresh()
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  deinit {
    timer?.invalidate()
  }

  private func refresh() {
    let latest = Self.isMicrophoneActive() || Self.isCameraActive()
    guard latest != isActive else { return }
    isActive = latest
    onChange?(latest)
  }

  private static func isMicrophoneActive() -> Bool {
    guard #available(macOS 14.2, *) else { return false }
    return audioObjects(kAudioHardwarePropertyProcessObjectList).contains {
      audioFlag(kAudioProcessPropertyIsRunningInput, of: $0)
    }
  }

  private static func isCameraActive() -> Bool {
    cameraObjects().contains { cameraIsRunning($0) }
  }

  private static func audioAddress(
    _ selector: AudioObjectPropertySelector
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  private static func audioObjects(
    _ selector: AudioObjectPropertySelector
  ) -> [AudioObjectID] {
    var address = audioAddress(selector)
    let system = AudioObjectID(kAudioObjectSystemObject)
    var size: UInt32 = 0

    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
      size > 0
    else {
      return []
    }

    var objects = [AudioObjectID](
      repeating: 0,
      count: Int(size) / MemoryLayout<AudioObjectID>.size
    )
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else {
      return []
    }

    return Array(objects.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
  }

  private static func audioFlag(
    _ selector: AudioObjectPropertySelector,
    of object: AudioObjectID
  ) -> Bool {
    var address = audioAddress(selector)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)

    return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr
      && value != 0
  }

  private static func cameraAddress(
    _ selector: CMIOObjectPropertySelector
  ) -> CMIOObjectPropertyAddress {
    CMIOObjectPropertyAddress(
      mSelector: selector,
      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
  }

  private static func cameraObjects() -> [CMIOObjectID] {
    var address = cameraAddress(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
    let system = CMIOObjectID(kCMIOObjectSystemObject)
    var size: UInt32 = 0

    guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
      size > 0
    else {
      return []
    }

    var objects = [CMIOObjectID](
      repeating: 0,
      count: Int(size) / MemoryLayout<CMIOObjectID>.size
    )
    var used: UInt32 = 0

    guard
      CMIOObjectGetPropertyData(
        system,
        &address,
        0,
        nil,
        size,
        &used,
        &objects
      ) == noErr
    else {
      return []
    }

    return Array(objects.prefix(Int(used) / MemoryLayout<CMIOObjectID>.size))
  }

  private static func cameraIsRunning(_ camera: CMIOObjectID) -> Bool {
    var address = cameraAddress(
      CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
    )
    var value: UInt32 = 0
    var used: UInt32 = 0

    return CMIOObjectGetPropertyData(
      camera,
      &address,
      0,
      nil,
      UInt32(MemoryLayout<UInt32>.size),
      &used,
      &value
    ) == noErr && value != 0
  }
}
