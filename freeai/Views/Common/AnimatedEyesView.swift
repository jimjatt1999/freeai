import SwiftUI

struct AnimatedEyesView: View {
    @EnvironmentObject var appManager: AppManager // Access settings
    @Environment(\.colorScheme) var colorScheme // Needed for adaptive background
    
    // State for animations (blink, iris, jiggle, tap)
    @State private var isBlinking = false
    @State private var blinkTask: Task<Void, Never>? = nil
    @State private var irisOffset: CGFloat = 0 
    @State private var irisTask: Task<Void, Never>? = nil
    @State private var jiggleOffset: CGFloat = 0
    @State private var jiggleTask: Task<Void, Never>? = nil
    @State private var rollAngle: Angle = .degrees(0)
    @State private var irisOffsetY: CGFloat = 0 // Vertical offset
    
    // State for displaying tap message
    @State private var currentMessage: String? = nil
    @State private var messageTask: Task<Void, Never>? = nil
    
    // --- Add Thinking State --- 
    @State private var isThinking = false 
    // --- End Thinking State --- 

    var isGenerating: Bool = false // Input property
    
    // Predefined messages for tap action - Expanded List
    let predefinedMessages = [
        "Hey!", "*blink*", "Boop!", "What's cookin'?",
        "That tickles!", "My eyes!", ";P", "Stop that! ... Just kidding.",
        "Peek-a-boo!", "Watching you...", "0_o", "O_O",
        "Zzz...", "Still here!", "Tap tap tap...", "Loading awesomeness...",
        "Engage hyperdrive!", "Boop boop beep!", "Shiny!", "Just vibin'",
        "Wanna play?", "I see stars!", "<('.')>", "<(^.^<)",
        "(>'.')>", "Lookin' sharp!", "High five! (Mentally)", "Whee!",
        // Added more messages:
        "Resistance is futile.", "I see all.", "Calculating...",
        "Error 404: Joke not found.", "Are you talkin' to me?", "*Giggle*",
        "All your base are belong to us.", "Beep boop?", "Loading sarcasm module...",
        "Do not disturb.", "Thinking cap on.", "Shhh... I'm concentrating.",
        "Can I help you?", "Processing... please wait.", "System overload!",
        "Just chilling.", "Look away!", "Secret message incoming...",
        "Code monkeys at work.", "Powered by caffeine.", "My other eye is on vacation.",
        "What was that?", "Did you see that?", "Spooky!", "Boo!",
        "Target acquired.", "Engaging witty retort...", "Affirmative.",
        "Negative.", "Does not compute.", "Hello, world!", "👁️‍🗨️" 
    ]
    
    // --- Calculated properties based on AppManager settings ---
    private var currentEyeWidth: CGFloat { 
        appManager.eyeShape == .circle ? 20 : 25 // Oval wider
    }
    private var currentEyeHeight: CGFloat {
        20 // Keep height consistent for now
    }
    private var currentIrisSize: CGFloat {
        switch appManager.eyeIrisSize {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
        }
    }
    private var currentStrokeWidth: CGFloat {
        switch appManager.eyeStrokeWidth {
            case .thin: return 1.2
            case .medium: return 1.8
            case .thick: return 2.5
        }
    }
    private var currentEyeOutlineColor: Color {
        appManager.eyeOutlineColor.getColor()
    }
    private var currentEyeBackgroundColor: Color {
        switch appManager.eyeBackgroundColor {
            case .white: return .white
            case .black: return .black
            case .adaptive: return Color(.systemBackground) // Adapts
        }
    }
    private var currentIrisColor: Color {
        // Use primary/black/white for monochrome, otherwise the tint
        appManager.eyeIrisColor == .monochrome ? 
            (currentEyeBackgroundColor == .white ? .black : .primary) : 
            appManager.eyeIrisColor.getColor()
    }
    private var currentIrisMaxOffset: CGFloat {
        // Adjust offset based on size
        currentEyeWidth * 0.15 
    }
    // --- End Calculated properties ---
    
    // Eye shape parameters (removed hardcoded values)
    let eyeSpacing: CGFloat = 12

    // --- Add states for enhanced animation ---
    @State private var crossEyedOffset: CGFloat = 0 // Added for cross-eye effect
    @State private var irisScaleY: CGFloat = 1.0 // Added for squint/wide effect
    // --- End added states ---
    
    var body: some View {
        // Use a ZStack for layering eyes and message independently
        ZStack(alignment: .top) { 
            // Eyes HStack
            HStack(spacing: eyeSpacing) {
                // Left Eye
                ZStack {
                    EyeShape(isClosed: false, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval)
                        .fill(currentEyeBackgroundColor)
                    EyeShape(isClosed: isBlinking, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval)
                        .stroke(currentEyeOutlineColor, lineWidth: currentStrokeWidth)
                    
                    if isThinking {
                        ThinkingIndicator(color: currentIrisColor)
                    } else {
                        IrisView(irisOffset: irisOffset - crossEyedOffset, irisOffsetY: irisOffsetY, isVisible: !isBlinking, irisSize: currentIrisSize, irisColor: currentIrisColor)
                            .scaleEffect(y: irisScaleY)
                    }
                }
                .frame(width: currentEyeWidth, height: currentEyeHeight)
                .clipped()

                // Right Eye
                ZStack {
                    EyeShape(isClosed: false, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval)
                        .fill(currentEyeBackgroundColor)
                    EyeShape(isClosed: isBlinking, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval)
                        .stroke(currentEyeOutlineColor, lineWidth: currentStrokeWidth)
                        
                    if isThinking {
                        ThinkingIndicator(color: currentIrisColor)
                    } else {
                        IrisView(irisOffset: irisOffset + crossEyedOffset, irisOffsetY: irisOffsetY, isVisible: !isBlinking, irisSize: currentIrisSize, irisColor: currentIrisColor)
                            .scaleEffect(y: irisScaleY)
                    }
                }
                .frame(width: currentEyeWidth, height: currentEyeHeight)
                .clipped()
            }
            .offset(y: jiggleOffset) // Apply jiggle offset to eyes HStack
            .rotationEffect(rollAngle) // Apply roll effect to eyes HStack
            // --- Remove Message Overlay from HStack ---
            // .overlay(...) { ... } 

            // --- Message View (directly in ZStack) ---
            if let message = currentMessage {
                // Apply horizontal padding to the container ZStack
                ZStack {
                    Text(message)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8) // Keep vertical padding on text
                        .background(
                            .thinMaterial,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity) // Allow text to use available width
                        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                        .transition(.opacity.combined(with: .offset(y: 5)))
                }
                // Position below the estimated eyes area using padding
                .padding(.top, currentEyeHeight + 15) // Further adjusted padding
            }
        }
        // Apply gestures and lifecycle modifiers to the ZStack
        .onTapGesture { triggerTapAnimation() }
        .onAppear { startAnimations() }
        .onDisappear { cancelAnimations() }
        .onChange(of: isGenerating) { _, newValue in handleGenerationChange(newValue) }
    }

    // --- Animation Setup/Teardown Helpers --- 
    private func startAnimations() {
        startBlinking()
        startIrisMovement()
        if isGenerating { startJiggle() } // Start jiggle if generating on appear
    }
    
    private func cancelAnimations() {
        cancelBlinking()
        cancelIrisMovement()
        cancelJiggle()
    }
    
    private func handleGenerationChange(_ newValue: Bool) {
         if newValue {
             startJiggle()
         } else {
             cancelJiggle()
         }
    }
    
    // --- Animation Tasks ---
    private func startBlinking() {
        cancelBlinking()
        blinkTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 1.5...4.0) * 1_000_000_000))
            while !Task.isCancelled {
                // --- Blink Start ---
                // Pause iris movement during blink
                cancelIrisMovement()
                withAnimation(.easeOut(duration: 0.08)) {
                    isBlinking = true
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                // --- Blink End ---
                // Reset iris to center immediately when opening
                irisOffset = 0
                irisOffsetY = 0
                withAnimation(.easeIn(duration: 0.1)) {
                    isBlinking = false
                }
                // Resume iris movement after eyes open
                startIrisMovement()
                // Make sure cross-eye and scale are reset on blink open
                crossEyedOffset = 0
                irisScaleY = 1.0
                // --- End Blink ---

                let delay = Double.random(in: 2.0...7.0)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    private func startIrisMovement() {
        cancelIrisMovement()
        irisTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.5...1.5) * 1_000_000_000))
            while !Task.isCancelled {
                 // Reset cross-eye and scale before deciding next move
                 var nextCrossEyedOffset: CGFloat = 0
                 var nextIrisScaleY: CGFloat = 1.0
                 
                 // Randomize horizontal offset
                 let possibleOffsetsX: [CGFloat] = [-currentIrisMaxOffset, 0, currentIrisMaxOffset]
                 var newOffsetX = possibleOffsetsX.filter { $0 != irisOffset }.randomElement() ?? 0
                 
                 // Randomize vertical offset
                 var newOffsetY: CGFloat = 0
                 if Double.random(in: 0...1) < 0.25 { // Increased chance
                     newOffsetY = CGFloat.random(in: -2.0...2.0) // Slightly larger range
                 }
                 
                 // --- Chance for Special Moves --- 
                 let randomAction = Double.random(in: 0...1)
                 
                 if randomAction < 0.15 { // 15% chance to go cross-eyed
                     nextCrossEyedOffset = currentIrisMaxOffset * 0.8 // Move inwards
                     newOffsetX = 0 // Center horizontally while cross-eyed
                     newOffsetY = 0 // Center vertically
                 } else if randomAction < 0.3 { // 15% chance to squint/widen (if not cross-eyed)
                     nextIrisScaleY = Double.random(in: 0...1) < 0.5 ? 0.6 : 1.4 // Squint or Widen
                 }
                 // --- End Special Moves ---
                 
                 withAnimation(.interpolatingSpring(stiffness: 150, damping: 15).speed(1.5)) { 
                     irisOffset = newOffsetX
                     irisOffsetY = newOffsetY
                     crossEyedOffset = nextCrossEyedOffset
                     irisScaleY = nextIrisScaleY
                 }
                 
                 // Hold the pose for a duration, shorter if cross-eyed or scaled
                 var delayMultiplier: Double = 1.0
                 if nextCrossEyedOffset != 0 || nextIrisScaleY != 1.0 {
                     delayMultiplier = 0.5 // Shorter hold for special poses
                 }
                 let delay = Double.random(in: 0.6...1.8) * delayMultiplier 
                 try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    // --- Jiggle Animation ---
    private func startJiggle() {
        cancelJiggle()
        jiggleTask = Task {
            while !Task.isCancelled {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 5).speed(2)) {
                    jiggleOffset = CGFloat.random(in: -1.5...1.5)
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { break }
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 10).speed(2)) {
                    jiggleOffset = 0
                }
                try? await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...300_000_000))
            }
        }
    }
    
    private func cancelJiggle() {
        if jiggleTask != nil { // Only reset if task was active
             withAnimation(.spring()) {
                 jiggleOffset = 0
             }
        }
        jiggleTask?.cancel()
        jiggleTask = nil
    }
    // --- End Jiggle ---
    
    private func cancelBlinking() {
        blinkTask?.cancel()
        blinkTask = nil
    }
    
    private func cancelIrisMovement() {
        irisTask?.cancel()
        irisTask = nil
    }

    // --- Tap Animation / Action ---
    private func triggerTapAnimation() {
        switch appManager.eyeTapAction {
        case .none:
            break // Do nothing
            
        case .blink:
            performBlinkAnimation() // Just a blink
            
        case .predefined:
            let message = predefinedMessages.randomElement() ?? "..."
            displayMessage(message)
            
            // Choose a random tap animation
            let randomAnimation = Int.random(in: 0...3) // Increased range for more variety
            switch randomAnimation {
            case 0:
                performBlinkAnimation()
            case 1:
                performSquintOrWidenAnimation()
            case 2:
                performCrossEyedAnimation()
            case 3: // Combination
                performBlinkAnimation()
                // Add a small delay then trigger another random one (excluding blink)
                Task { 
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    let secondAnimation = Int.random(in: 1...2)
                    if secondAnimation == 1 {
                        performSquintOrWidenAnimation()
                    } else {
                        performCrossEyedAnimation()
                    }
                }
            default:
                performBlinkAnimation() // Fallback
            }

        // Removed .shortLLM case entirely
        // case .shortLLM:
        //    ... (old code removed) ...
        default: // Add default case to satisfy exhaustiveness 
            performBlinkAnimation() // Default to a simple blink
        }
    }
    
    // Display message temporarily
    private func displayMessage(_ message: String) {
        messageTask?.cancel() // Cancel previous timer if any
        withAnimation(.spring()) {
             currentMessage = message
        }
        messageTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // Show message for 3 seconds
             withAnimation(.easeOut(duration: 0.5)) {
                 currentMessage = nil
             }
             messageTask = nil
        }
    }

    // Extracted blink animation logic for reuse
    private func performBlinkAnimation() {
        guard !isBlinking else { return } 
         cancelBlinking()
         cancelIrisMovement()
         withAnimation(.easeOut(duration: 0.08)) { isBlinking = true }
         Task {
             try? await Task.sleep(nanoseconds: 150_000_000)
             if isBlinking { // Check ensures this task doesn't override a natural blink
                 withAnimation(.easeIn(duration: 0.1)) { isBlinking = false }
                 startBlinking() // Restart natural blinking
                 startIrisMovement()
             }
         }
    }

    // --- New Tap Animation Helpers ---
    private func performSquintOrWidenAnimation() {
        guard !isBlinking else { return } // Don't interrupt blink
        cancelIrisMovement() // Pause natural movement briefly
        let originalScale = irisScaleY // Store original scale
        let targetScale: CGFloat = Double.random(in: 0...1) < 0.5 ? 0.6 : 1.4 // Squint or Widen
        
        withAnimation(.easeOut(duration: 0.1)) {
            irisScaleY = targetScale
        }
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // Hold squint/widen
            // Check if state hasn't changed drastically (e.g., by a natural blink)
            if !isBlinking && irisScaleY == targetScale { 
                withAnimation(.easeIn(duration: 0.15)) {
                    irisScaleY = originalScale // Return to original (usually 1.0)
                }
                startIrisMovement() // Resume natural movement
            } else if !isBlinking {
                 // If state changed but not blinking, just reset scale and restart movement
                 irisScaleY = 1.0 
                 startIrisMovement()
            }
            // If blinking, the blink logic will handle resetting scale
        }
    }

    private func performCrossEyedAnimation() {
        guard !isBlinking else { return } // Don't interrupt blink
        cancelIrisMovement() // Pause natural movement briefly
        let originalOffset = crossEyedOffset // Store original offset
        let targetOffset = currentIrisMaxOffset * 0.8 // Go cross-eyed
        
        withAnimation(.easeOut(duration: 0.1)) {
            crossEyedOffset = targetOffset
            irisOffset = 0 // Center horizontally
            irisOffsetY = 0 // Center vertically
        }
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000) // Hold cross-eyed
             // Check if state hasn't changed drastically
            if !isBlinking && crossEyedOffset == targetOffset {
                 withAnimation(.easeIn(duration: 0.15)) {
                     crossEyedOffset = originalOffset // Return to original (usually 0)
                 }
                 startIrisMovement() // Resume natural movement
            } else if !isBlinking {
                 // If state changed but not blinking, just reset offset and restart movement
                 crossEyedOffset = 0 
                 startIrisMovement()
            }
             // If blinking, the blink logic will handle resetting offset
        }
    }
    // --- End New Tap Animation Helpers ---
}

// Shape for a single eye that can be open or closed
struct EyeShape: Shape {
    var isClosed: Bool
    var strokeWidth: CGFloat
    var isOval: Bool // Added property

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let insetAmount = strokeWidth / 2
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)

        if isClosed {
            path.move(to: CGPoint(x: insetRect.minX, y: insetRect.midY))
            path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.midY))
        } else {
            // Draw ellipse (circle if width==height, oval otherwise)
            path.addEllipse(in: insetRect)
        }
        return path
    }
}

// Simple view for the Iris
struct IrisView: View {
    let irisOffset: CGFloat
    let irisOffsetY: CGFloat // Added Y offset
    let isVisible: Bool
    let irisSize: CGFloat
    let irisColor: Color 
    
    var body: some View {
        Circle()
            .fill(irisColor)
            .frame(width: irisSize, height: irisSize)
            .offset(x: irisOffset, y: irisOffsetY) // Apply both offsets
            .opacity(isVisible ? 1 : 0)
    }
}

// --- Add Thinking Indicator View --- 
struct ThinkingIndicator: View {
    let color: Color
    @State private var trimEnd: CGFloat = 0.1
    
    var body: some View {
        Circle()
            .trim(from: 0, to: trimEnd)
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: 10, height: 10) // Size similar to iris
            .rotationEffect(.degrees(-90)) // Start trim from top
            .rotationEffect(.degrees(Double(trimEnd) * 360.0 * 2.0)) 
            .onAppear { 
                // Animate trim and rotation
                 withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                     trimEnd = 0.9
                 }
            }
    }
}
// --- End Thinking Indicator --- 

#Preview {
    // Need to provide AppManager in preview
    AnimatedEyesView()
        .environmentObject(AppManager()) // Add AppManager to environment
        .padding()
        .preferredColorScheme(.dark)
} 