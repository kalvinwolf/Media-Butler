import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var size: CGFloat
    var opacity: Double
}

struct FireworksView: View {
    @Binding var isVisible: Bool
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    
    let screenSize = NSScreen.main?.frame ?? .zero
    
    func createFirework(at position: CGPoint) {
        let particleCount = 150
        let colors: [Color] = [
            .red, .orange, .yellow, .pink, .purple, .blue,
            .mint, .cyan, .teal, .green,
            Color(red: 1, green: 0.8, blue: 0.2), // Gold
            Color(red: 1, green: 0.4, blue: 0.7)  // Hot pink
        ]
        
        for _ in 0..<particleCount {
            let angle = Double.random(in: 0...2 * .pi)
            let speed = Double.random(in: 10...25)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed * 1.5
            )
            
            let particle = Particle(
                position: position,
                velocity: velocity,
                color: colors.randomElement() ?? .white,
                size: CGFloat.random(in: 4...12),
                opacity: 1.0
            )
            particles.append(particle)
        }
    }
    
    func updateParticles() {
        particles = particles.compactMap { particle in
            var newParticle = particle
            newParticle.position.x += particle.velocity.x
            newParticle.position.y += particle.velocity.y
            newParticle.velocity.y -= 0.08
            newParticle.opacity -= 0.008
            
            return newParticle.opacity > 0 ? newParticle : nil
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .blur(radius: particle.size * 0.2)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Create multiple fireworks from different positions
            let positions = [
                CGPoint(x: screenSize.width * 0.2, y: screenSize.height),  // Left
                CGPoint(x: screenSize.width * 0.4, y: screenSize.height),  // Center-left
                CGPoint(x: screenSize.width * 0.6, y: screenSize.height),  // Center-right
                CGPoint(x: screenSize.width * 0.8, y: screenSize.height)   // Right
            ]
            
            // Launch fireworks with slight delays for more natural effect
            for (index, position) in positions.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    createFirework(at: position)
                }
            }
            
            // Start animation timer
            timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
                updateParticles()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            particles = []
        }
    }
} 