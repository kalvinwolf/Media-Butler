import SwiftUI
import AppKit

class FireworksWindowController: ObservableObject {
    private var window: NSWindow?
    @Published private var isVisible: Bool
    
    init(isVisible: Bool) {
        self.isVisible = isVisible
    }
    
    func showFireworks() {
        if window == nil {
            let screenSize = NSScreen.main?.frame ?? .zero
            
            window = NSWindow(
                contentRect: screenSize,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window?.backgroundColor = .clear
            window?.isOpaque = false
            window?.level = .floating
            window?.ignoresMouseEvents = true
            
            let fireworksView = FireworksView(isVisible: .constant(true))
            window?.contentView = NSHostingView(rootView: fireworksView)
        }
        
        window?.makeKeyAndOrderFront(nil)
        
        // Position window to cover all screens
        if let screen = NSScreen.main {
            var totalFrame = screen.frame
            NSScreen.screens.forEach { screen in
                totalFrame = totalFrame.union(screen.frame)
            }
            window?.setFrame(totalFrame, display: true)
        }
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideFireworks()
        }
    }
    
    func hideFireworks() {
        window?.orderOut(nil)
        window = nil
    }
} 