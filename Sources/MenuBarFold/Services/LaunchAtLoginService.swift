import Foundation
import ServiceManagement

protocol LaunchAtLoginServicing {
  var isEnabled: Bool { get }
  func setEnabled(_ enabled: Bool) throws
}

struct LaunchAtLoginService: LaunchAtLoginServicing {
  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      if SMAppService.mainApp.status != .enabled {
        try SMAppService.mainApp.register()
      }
    } else if SMAppService.mainApp.status == .enabled {
      try SMAppService.mainApp.unregister()
    }
  }
}
