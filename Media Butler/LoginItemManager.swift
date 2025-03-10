import Foundation
import ServiceManagement

class LoginItemManager {
    static let shared = LoginItemManager()
    
    private init() {}
    
    func setLaunchAtLogin(enabled: Bool) {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            do {
                if enabled {
                    if #available(macOS 13.0, *) {
                        try SMAppService.mainApp.register()
                    } else {
                        let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
                        if !success {
                            print("Failed to enable launch at login")
                        }
                    }
                } else {
                    if #available(macOS 13.0, *) {
                        try SMAppService.mainApp.unregister()
                    } else {
                        let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
                        if !success {
                            print("Failed to disable launch at login")
                        }
                    }
                }
            } catch {
                print("Failed to set launch at login: \(error)")
            }
        }
    }
    
    func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For older versions, we'll rely on the stored preference
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }
} 