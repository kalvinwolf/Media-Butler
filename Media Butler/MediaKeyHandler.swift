import Foundation
import CoreGraphics
import AppKit
import ApplicationServices

extension NSEvent {
    fileprivate static func data(with event: NSEvent) -> Int {
        let data = event.data1
        let intData = Int(data)
        return intData
    }
}

class MediaKeyHandler {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private static var sharedInstance: MediaKeyHandler?
    private var targetBundleIdentifier: String?
    private var isCleanedUp = false
    
    // Media key constants
    private let NX_KEYTYPE_PLAY = 16
    private let NX_KEYTYPE_NEXT = 17
    private let NX_KEYTYPE_PREVIOUS = 18
    private let NX_KEYTYPE_FAST = 19
    private let NX_KEYTYPE_REWIND = 20
    
    static func shared() -> MediaKeyHandler {
        if sharedInstance == nil {
            sharedInstance = MediaKeyHandler()
        }
        return sharedInstance!
    }
    
    private init() {
        print("Initializing MediaKeyHandler")
        setupEventTap()
        
        // Register for app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        cleanup()
    }
    
    func cleanup() {
        // Prevent multiple cleanups
        guard !isCleanedUp else { return }
        isCleanedUp = true
        
        print("Starting MediaKeyHandler cleanup")
        
        // Disable and remove event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        
        // Remove run loop source
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        
        // Clear other resources
        targetBundleIdentifier = nil
        
        // Remove observer
        NotificationCenter.default.removeObserver(self)
        
        // Clear shared instance only if this is the shared instance
        if MediaKeyHandler.sharedInstance === self {
            MediaKeyHandler.sharedInstance = nil
        }
        
        print("MediaKeyHandler cleanup completed")
    }
    
    func setTargetApp(_ bundleIdentifier: String?) {
        print("Setting target app to: \(bundleIdentifier ?? "none")")
        
        // Allow both Spotify and Apple Music
        if bundleIdentifier == "com.spotify.client" || bundleIdentifier == "com.apple.Music" {
            self.targetBundleIdentifier = bundleIdentifier
            print("Target app set to \(bundleIdentifier == "com.spotify.client" ? "Spotify" : "Apple Music")")
            // Only check accessibility permission, don't launch the app
            checkAccessibilityPermission()
        } else {
            print("Clearing target app (unsupported app)")
            self.targetBundleIdentifier = nil
        }
    }
    
    private func getCurrentBundleId() -> String? {
        // Safely access the bundle identifier
        return self.targetBundleIdentifier
    }
    
    private func checkAccessibilityPermission() {
        print("Checking accessibility permissions...")
        
        // First check if we already have permission
        if AXIsProcessTrusted() {
            print("Accessibility permission already granted")
            return
        }
        
        print("Accessibility permission not granted, requesting...")
        
        // Create the dictionary with the prompt option
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        
        // Request permission with prompt
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility permission request result: \(accessibilityEnabled)")
        
        // If still not granted, open System Settings
        if !AXIsProcessTrusted() {
            print("Opening System Settings for Accessibility...")
            DispatchQueue.main.async {
                // Try both URLs as the format might vary by macOS version
                let urls = [
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                    "x-apple.systempreferences:Security_Privacy?Privacy_Accessibility"
                ]
                
                for urlString in urls {
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    private func setupEventTap() {
        print("Setting up event tap")
        let eventMask = CGEventMask(1 << NX_SYSDEFINED)
        
        // Create a reference that will persist for the lifetime of the tap
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let handler = Unmanaged<MediaKeyHandler>.fromOpaque(refcon).takeUnretainedValue()
                return handler.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap")
            Unmanaged<MediaKeyHandler>.fromOpaque(selfPtr).release()
            return
        }
        
        eventTap = tap
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap!, enable: true)
        print("Event tap setup completed")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        print("Received media key event")
        print("Event type: \(type.rawValue)")
        
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let nsEvent = NSEvent(cgEvent: event)
        if let nsEvent = nsEvent {
            print("NSEvent type: \(nsEvent.type.rawValue)")
            print("NSEvent subtype: \(nsEvent.subtype.rawValue)")
            
            // Extract media key info regardless of event type
            let data = NSEvent.data(with: nsEvent)
            let keyCode = (data & 0xFFFF0000) >> 16
            let keyFlags = data & 0xFFFF
            let keyState = ((keyFlags & 0xFF00) >> 8) == 0xA
            
            print("Key event - code: \(keyCode), flags: \(keyFlags), state: \(keyState)")
            
            // Check if this is a media key event by checking the keyCode
            if [NX_KEYTYPE_PLAY, NX_KEYTYPE_NEXT, NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_FAST, NX_KEYTYPE_REWIND].contains(keyCode) {
                print("Detected media key press")
                
                // Only handle key down events
                guard keyState else {
                    print("Ignoring key up event")
                    return Unmanaged.passRetained(event)
                }
                
                // Safely get the current bundle ID
                guard let bundleId = getCurrentBundleId(),
                      (bundleId == "com.spotify.client" || bundleId == "com.apple.Music") else {
                    print("No target app or unsupported app")
                    return Unmanaged.passRetained(event)
                }
                
                print("Handling media key event for \(bundleId == "com.spotify.client" ? "Spotify" : "Apple Music")")
                
                // Handle the media key command
                switch keyCode {
                case NX_KEYTYPE_PLAY:
                    print("Sending play/pause command")
                    sendPlayPauseCommand(to: bundleId)
                case NX_KEYTYPE_NEXT:
                    print("Sending next track command")
                    sendNextTrackCommand(to: bundleId)
                case NX_KEYTYPE_PREVIOUS:
                    print("Sending previous track command")
                    sendPreviousTrackCommand(to: bundleId)
                default:
                    print("Unhandled media key code: \(keyCode)")
                    return Unmanaged.passRetained(event)
                }
                
                print("Command sent, consuming event")
                return nil
            }
        }
        
        print("Not a media key event, passing through")
        return Unmanaged.passRetained(event)
    }
    
    private func sendPlayPauseCommand(to bundleId: String) {
        print("Executing play/pause command for \(bundleId)")
        
        switch bundleId {
        case "com.spotify.client":
            let script = """
                tell application "Spotify"
                    if running then
                        playpause
                    else
                        activate
                        delay 1
                        play
                    end if
                end tell
            """
            print("Running Spotify AppleScript: \(script)")
            runAppleScript(script)
            
        case "com.apple.Music":
            let script = """
                tell application "Music"
                    if running then
                        -- App is already running, don't activate
                        try
                            if player state is stopped or player state is paused then
                                play playlist "Library"
                            else
                                playpause
                            end if
                        on error
                            -- If there's an error, try to play the library
                            play playlist "Library"
                        end try
                    else
                        -- First launch needs longer delay but don't activate
                        launch
                        delay 2
                        try
                            play playlist "Library"
                        on error
                            -- If there's an error, try to play the library again
                            delay 0.5
                            play playlist "Library"
                        end try
                    end if
                end tell
            """
            print("Running Apple Music script: \(script)")
            runAppleScript(script)
            
        default:
            print("Unsupported bundle ID for play/pause command")
        }
    }
    
    private func sendNextTrackCommand(to bundleId: String) {
        print("Executing next track command for \(bundleId)")
        
        switch bundleId {
        case "com.spotify.client":
            let script = """
                tell application "Spotify"
                    if running then
                        next track
                    else
                        activate
                        delay 1
                        next track
                    end if
                end tell
            """
            print("Running Spotify AppleScript: \(script)")
            runAppleScript(script)
            
        case "com.apple.Music":
            let script = """
                tell application "Music"
                    -- Don't activate, just control playback
                    try
                        next track
                        if player state is stopped then
                            play
                        end if
                    on error
                        play playlist "Library"
                    end try
                end tell
            """
            print("Running Apple Music AppleScript: \(script)")
            runAppleScript(script)
            
        default:
            print("Unsupported bundle ID for next track command")
        }
    }
    
    private func sendPreviousTrackCommand(to bundleId: String) {
        print("Executing previous track command for \(bundleId)")
        
        switch bundleId {
        case "com.spotify.client":
            let script = """
                tell application "Spotify"
                    if running then
                        previous track
                    else
                        activate
                        delay 1
                        previous track
                    end if
                end tell
            """
            print("Running Spotify AppleScript: \(script)")
            runAppleScript(script)
            
        case "com.apple.Music":
            let script = """
                tell application "Music"
                    -- Don't activate, just control playback
                    try
                        previous track
                        if player state is stopped then
                            play
                        end if
                    on error
                        play playlist "Library"
                    end try
                end tell
            """
            print("Running Apple Music AppleScript: \(script)")
            runAppleScript(script)
            
        default:
            print("Unsupported bundle ID for previous track command")
        }
    }
    
    private func runAppleScript(_ script: String) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            print("Executing AppleScript: \(script)")
            
            // Try to compile the script first to trigger permission prompt
            scriptObject.compileAndReturnError(&error)
            if let error = error {
                print("Script compilation error: \(error)")
                return
            }
            
            let result = scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Error executing AppleScript: \(error)")
                // Handle specific error codes
                if let errorNumber = error[NSAppleScript.errorNumber] as? Int {
                    switch errorNumber {
                    case -1743: // Permission error
                        print("Automation permission needed. Please grant permission in System Settings > Privacy & Security > Automation")
                        // Open both the Security preferences and the target app
                        DispatchQueue.main.async {
                            // Open Security preferences
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                                NSWorkspace.shared.open(url)
                            }
                            
                            // Also try to open the target app directly
                            if let bundleId = self.targetBundleIdentifier,
                               let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                                let configuration = NSWorkspace.OpenConfiguration()
                                configuration.activates = true
                                
                                Task {
                                    try? await NSWorkspace.shared.openApplication(
                                        at: appUrl,
                                        configuration: configuration
                                    )
                                }
                            }
                        }
                    case -1728: // App not running
                        print("Target app is not running, attempting to launch it")
                        if let bundleId = targetBundleIdentifier,
                           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                            let configuration = NSWorkspace.OpenConfiguration()
                            configuration.activates = true
                            
                            DispatchQueue.main.async {
                                Task {
                                    try? await NSWorkspace.shared.openApplication(
                                        at: appUrl,
                                        configuration: configuration
                                    )
                                }
                            }
                        }
                    default:
                        print("AppleScript error number: \(errorNumber)")
                    }
                }
            } else {
                print("AppleScript executed successfully: \(result.stringValue ?? "no result")")
            }
        }
    }
    
    deinit {
        print("MediaKeyHandler deinit called")
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
} 
