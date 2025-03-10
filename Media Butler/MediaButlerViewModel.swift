import Foundation
import SwiftUI

class MediaButlerViewModel: ObservableObject {
    @Published var selectedApp: String?
    private let mediaKeyHandler = MediaKeyHandler.shared()
    
    let supportedApps = [
        "Spotify": "com.spotify.client",
        "Apple Music": "com.apple.Music"
    ]
    
    init() {
        // Restore the saved selection
        if let savedApp = UserDefaults.standard.string(forKey: "selectedMusicPlayer") {
            setTargetApp(savedApp)
        }
    }
    
    func setTargetApp(_ appName: String?) {
        selectedApp = appName
        // Save the selection
        if let appName = appName {
            UserDefaults.standard.set(appName, forKey: "selectedMusicPlayer")
            mediaKeyHandler.setTargetApp(supportedApps[appName])
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedMusicPlayer")
            mediaKeyHandler.setTargetApp(nil)
        }
    }
    
    func isAppSelected(_ appName: String) -> Bool {
        return selectedApp == appName
    }
} 