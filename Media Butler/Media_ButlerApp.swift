//
//  Media_ButlerApp.swift
//  Media Butler
//
//  Created by Kalvin Wolf on 08.03.25.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup before termination
        MediaKeyHandler.shared().cleanup()
        
        // Force exit if needed
        exit(0)
    }
}

@main
struct Media_ButlerApp: App {
    @StateObject private var viewModel = MediaButlerViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("launchAtLogin") private var launchAtLogin = true {
        didSet {
            LoginItemManager.shared.setLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    @AppStorage("fireworkMode") private var fireworkMode = false
    @State private var showingFireworks = false
    @StateObject private var fireworksController: FireworksWindowController
    
    init() {
        // Initialize fireworks controller first
        let controller = FireworksWindowController(isVisible: false)
        _fireworksController = StateObject(wrappedValue: controller)
        
        // Prevent multiple instances of the app
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).count > 1 {
            NSApp.terminate(nil)
        }
        
        // Set initial launch at login state
        LoginItemManager.shared.setLaunchAtLogin(enabled: launchAtLogin)
    }
    
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                Menu {
                    ForEach(Array(viewModel.supportedApps.keys), id: \.self) { appName in
                        Button(action: {
                            if viewModel.isAppSelected(appName) {
                                viewModel.setTargetApp(nil)
                            } else {
                                viewModel.setTargetApp(appName)
                            }
                        }) {
                            HStack {
                                Text(appName)
                                Spacer()
                                if viewModel.isAppSelected(appName) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("Select Music Player")
                }
                
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(CheckboxToggleStyle())
                
                Divider()
                
                Button("Firework Mode") {
                    showingFireworks = true
                    fireworksController.showFireworks()
                }
                
                Button("Check for Updates...") {
                    if let url = URL(string: "https://github.com/kalvinwolf/Media-Butler") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button(action: {
                    // Cleanup and quit
                    MediaKeyHandler.shared().cleanup()
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Text("Quit")
                        Spacer()
                        Text("⌘Q")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding()
            .frame(width: 220)
        } label: {
            if let selectedApp = viewModel.selectedApp {
                switch selectedApp {
                case "Spotify":
                    Image(systemName: "music.note.list")
                        .foregroundColor(.green)
                case "Apple Music":
                    Image(systemName: "music.note")
                        .foregroundColor(.pink)
                default:
                    Image(systemName: "music.note")
                }
            } else {
                Image(systemName: "music.note")
            }
        }
    }
}
