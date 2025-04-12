import SwiftUI

struct NeuraEyesView: View {
    @EnvironmentObject var appManager: AppManager // Access settings
    @Environment(\.colorScheme) var colorScheme // Needed for adaptive background
    
    // State for animations (blink, iris, jiggle, tap)
    @State private var isBlinking = false
    @State private var blinkTask: Task<Void, Never>? = nil
    @State private var irisOffset: CGFloat = 0 
    @State private var irisTask: Task<Void, Never>? = nil
    @State private var rollAngle: Angle = .degrees(0)
    @State private var irisOffsetY: CGFloat = 0 // Vertical offset
    
    // State for displaying tap message
    @State private var currentMessage: String? = nil
    @State private var messageTask: Task<Void, Never>? = nil
    
    // --- Input properties --- 
    var isGenerating: Bool = false // For Jiggle effect
    var isThinking: Bool = false   // For pupil movement/squint effect
    var isListening: Bool = false  // For listening effect
    var persistentBackgroundColor: Color? = nil // NEW: To override background color
    // --- End Input properties ---
    
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
        switch appManager.eyeShape {
            case .circle: return 20
            case .oval: return 25
            case .square: return 20 // Same size as circle for now
        }
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
    // --- NEW: Computed property for effective background ---
    private var effectiveBackgroundColor: Color {
        // Priority: Pulse -> Persistent Override -> Default
        return pulseColor ?? persistentBackgroundColor ?? currentEyeBackgroundColor
    }
    // --- END NEW ---
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
    
    // --- NEW: State for Color Pulse Animation ---
    @State private var pulseColor: Color? = nil
    @State private var pulseTask: Task<Void, Never>? = nil
    // --- End Color Pulse State ---
    
    // --- NEW: States for Generating Animation ---
    @State private var generatingGlowOpacity: Double = 0.0
    @State private var generatingAnimationTask: Task<Void, Never>? = nil
    @State private var showGlowForGeneration = true // Randomly chosen on generation start
    @State private var showThinkingIndicatorForGeneration = false // NEW: State for thinking indicator
    // --- END NEW ---
    
    var body: some View {
        // Use a ZStack for layering eyes and message independently
        ZStack(alignment: .top) { 
            // Eyes HStack
            HStack(spacing: eyeSpacing) {
                // Left Eye
                ZStack {
                    EyeShape(isClosed: false, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval, isSquare: appManager.eyeShape == .square)
                        // Apply pulse color to background temporarily
                        .fill(effectiveBackgroundColor)
                    EyeShape(isClosed: isBlinking, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval, isSquare: appManager.eyeShape == .square)
                        .stroke(currentEyeOutlineColor, lineWidth: currentStrokeWidth)
                    
                    // --- Conditional Iris/Thinking/Listening/Generating --- 
                    if isGenerating && showThinkingIndicatorForGeneration {
                        ThinkingIndicator(color: currentIrisColor)
                    } else if isThinking {
                        // Thinking: Focused/Squinted Iris
                        IrisView(
                            irisOffset: -crossEyedOffset, // Use cross-eye offset for focus
                            irisOffsetY: 0, // Keep centered vertically
                            isVisible: !isBlinking, 
                            irisSize: currentIrisSize, 
                            irisColor: currentIrisColor
                        )
                        .scaleEffect(y: 0.8) // Apply squint scale
                    } else if isListening {
                        // Listening: Placeholder for now (e.g., slightly wider pupils?)
                         IrisView(
                             irisOffset: irisOffset, // Use normal random offset
                             irisOffsetY: irisOffsetY,
                             isVisible: !isBlinking, 
                             irisSize: currentIrisSize * 1.1, // Slightly larger iris
                             irisColor: currentIrisColor
                         )
                         .opacity(0.7) // Maybe slightly faded?
                    } else if !isBlinking { // Default Idle Iris
                        IrisView(
                            irisOffset: irisOffset - crossEyedOffset, 
                            irisOffsetY: irisOffsetY, 
                            isVisible: true, // Always visible when not blinking/thinking/listening
                            irisSize: currentIrisSize, 
                            irisColor: currentIrisColor
                        )
                        .scaleEffect(y: irisScaleY) // Use normal scale
                    }
                    // --- End Conditional Iris --- 
                }
                .frame(width: currentEyeWidth, height: currentEyeHeight)
                .clipped()

                // Right Eye
                ZStack {
                    EyeShape(isClosed: false, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval, isSquare: appManager.eyeShape == .square)
                         // Apply pulse color to background temporarily
                        .fill(effectiveBackgroundColor)
                    EyeShape(isClosed: isBlinking, strokeWidth: currentStrokeWidth, isOval: appManager.eyeShape == .oval, isSquare: appManager.eyeShape == .square)
                        .stroke(currentEyeOutlineColor, lineWidth: currentStrokeWidth)
                        
                    // --- Conditional Iris/Thinking/Listening/Generating --- 
                    if isGenerating && showThinkingIndicatorForGeneration {
                        ThinkingIndicator(color: currentIrisColor)
                    } else if isThinking {
                         IrisView(irisOffset: crossEyedOffset, irisOffsetY: 0, isVisible: !isBlinking, irisSize: currentIrisSize, irisColor: currentIrisColor)
                         .scaleEffect(y: 0.8) // Squint
                     } else if isListening {
                         IrisView(irisOffset: irisOffset, irisOffsetY: irisOffsetY, isVisible: !isBlinking, irisSize: currentIrisSize * 1.1, irisColor: currentIrisColor)
                         .opacity(0.7)
                     } else if !isBlinking { // Default Idle Iris
                         IrisView(irisOffset: irisOffset + crossEyedOffset, irisOffsetY: irisOffsetY, isVisible: true, irisSize: currentIrisSize, irisColor: currentIrisColor)
                         .scaleEffect(y: irisScaleY)
                     }
                     // --- End Conditional Iris --- 
                }
                .frame(width: currentEyeWidth, height: currentEyeHeight)
                .clipped()
            }
            .if(appManager.showNeuraEyesBorder) { view in // Conditional Border/BG
                view
                    .padding(10) // Add padding inside the border
                    .background(Color(.secondarySystemBackground)) // Add background
                    .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip background
                    .overlay( // Add border
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 1)
                    )
            }
            .rotationEffect(rollAngle) // Apply roll effect to eyes HStack
            // --- NEW: Apply Glow Effect --- 
            // Use primary color for glow to work in dark mode, reduce radius/opacity for subtlety
            .shadow(color: Color.primary.opacity(generatingGlowOpacity * 0.5), radius: generatingGlowOpacity * 6, x: 0, y: 0) // Subtle glow
            .shadow(color: Color.primary.opacity(generatingGlowOpacity * 0.25), radius: generatingGlowOpacity * 3, x: 0, y: 0)  // Inner glow
            // Add repeating animation modifier directly to the glow opacity state change
            .animation(generatingGlowOpacity > 0 ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: generatingGlowOpacity)
            // --- END NEW ---
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
        // Pause random movement when thinking or listening
        .onChange(of: isThinking) { _, newValue in handleThinkingListeningChange(newValue || isListening) }
        .onChange(of: isListening) { _, newValue in handleThinkingListeningChange(newValue || isThinking) }
        .onChange(of: appManager.transientNoteColorTag) { _, newValue in
             triggerColorPulse(colorTag: newValue)
        }
    }

    // --- Animation Setup/Teardown Helpers --- 
    private func startAnimations() {
        startBlinking()
        startIrisMovement()
        if isGenerating { handleGenerationChange(true) } // Use handler on appear
    }
    
    private func cancelAnimations() {
        cancelBlinking()
        cancelIrisMovement()
        generatingAnimationTask?.cancel()
        resetGenerationState() // Ensure state is reset on disappear
    }
    
    private func handleGenerationChange(_ isGenerating: Bool) {
        generatingAnimationTask?.cancel() 
        if isGenerating {
            // Dispatch based on setting
            switch appManager.generationAnimationStyle {
            case .thinking:
                startThinkingIndicatorAnimation()
            case .glow:
                startGlowAnimation()
            case .random:
                if Bool.random() {
                    startThinkingIndicatorAnimation()
                } else {
                    startGlowAnimation()
                }
            }
        } else {
            resetGenerationState()
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
                 
                 // --- Chance to Pause --- 
                 if Double.random(in: 0...1) < 0.15 { // 15% chance to just pause
                     let pauseDelay = Double.random(in: 1.0...2.5)
                     try? await Task.sleep(nanoseconds: UInt64(pauseDelay * 1_000_000_000))
                     continue // Skip the rest of the loop and decide next action again
                 }
                 // --- End Chance to Pause ---
                 
                 // Randomize horizontal offset
                 var newOffsetX: CGFloat
                 
                 // Randomize vertical offset
                 var newOffsetY: CGFloat = 0
                 
                 // --- Chance for Special Moves --- 
                 let randomAction = Double.random(in: 0...1)
                 
                 var shouldRoll = false
                 var lookDirectionX: CGFloat? = nil
                 var lookDirectionY: CGFloat? = nil
                 
                 if randomAction < 0.15 { // 15% chance to go cross-eyed
                     nextCrossEyedOffset = currentIrisMaxOffset * 0.8 // Move inwards
                     newOffsetX = 0 // Center horizontally while cross-eyed
                     newOffsetY = 0 // Center vertically
                 } else if randomAction < 0.3 { // 15% chance to squint/widen (if not cross-eyed)
                     nextIrisScaleY = Double.random(in: 0...1) < 0.5 ? 0.6 : 1.4 // Squint or Widen
                     // Allow slight drift during squint/widen
                     newOffsetX = irisOffset + CGFloat.random(in: -2...2)
                     newOffsetY = irisOffsetY + CGFloat.random(in: -1...1)
                 } else if randomAction < 0.4 { // 10% chance to roll eyes
                     shouldRoll = true
                     newOffsetX = irisOffset // Keep current offset during roll
                     newOffsetY = irisOffsetY
                 } else if randomAction < 0.60 { // Increased chance (20%) to look together
                     lookDirectionX = [-currentIrisMaxOffset, currentIrisMaxOffset].randomElement() ?? 0
                     lookDirectionY = CGFloat.random(in: -2.0...2.0)
                     newOffsetX = lookDirectionX! // Assign the chosen direction
                     newOffsetY = lookDirectionY! // Assign the chosen direction
                 } else { // Default random movement
                     let possibleOffsetsX: [CGFloat] = [-currentIrisMaxOffset, 0, currentIrisMaxOffset]
                     newOffsetX = possibleOffsetsX.filter { $0 != irisOffset }.randomElement() ?? 0
                     if Double.random(in: 0...1) < 0.3 { // 30% chance for vertical offset
                         newOffsetY = CGFloat.random(in: -2.0...2.0) // Slightly larger range
                     } else {
                         newOffsetY = 0 // Keep centered vertically more often
                     }
                 }
                 // --- End Special Moves ---
                 
                 // Use a slightly different animation for rolling or coordinated look
                 let animation: Animation
                 if shouldRoll {
                     animation = .interpolatingSpring(mass: 0.5, stiffness: 100, damping: 10)
                 } else if lookDirectionX != nil {
                     // Slightly quicker animation for coordinated look
                     animation = .interpolatingSpring(stiffness: 180, damping: 18).speed(1.8)
                 } else {
                     // Default animation
                     animation = .interpolatingSpring(stiffness: 150, damping: 15).speed(1.5)
                 }
                 
                 withAnimation(animation) {
                     irisOffset = newOffsetX
                     irisOffsetY = newOffsetY
                     crossEyedOffset = nextCrossEyedOffset
                     irisScaleY = nextIrisScaleY
                     if shouldRoll {
                         rollAngle = Angle.degrees(Double.random(in: -8...8))
                     }
                 }
                 
                 // Calculate delay
                 var delayMultiplier: Double = 1.0
                 if nextCrossEyedOffset != 0 || nextIrisScaleY != 1.0 || shouldRoll || lookDirectionX != nil {
                     delayMultiplier = 0.6 // Shorter hold for special poses
                 }
                 let delay = Double.random(in: 0.5...1.5) * delayMultiplier
                 try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                 // Animate roll back to center if it happened
                 if shouldRoll {
                     withAnimation(.interpolatingSpring(mass: 0.5, stiffness: 100, damping: 10)) {
                         rollAngle = .degrees(0)
                     }
                     // Add a short delay after roll back before next move
                     try? await Task.sleep(nanoseconds: 200_000_000)
                 }
             }
         }
    }
    
    // --- NEW: Generating Animation ---
    private func startGlowAnimation() {
        generatingAnimationTask?.cancel()
        generatingAnimationTask = Task {
            do {
                // Only handle glow here
                showThinkingIndicatorForGeneration = false
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        generatingGlowOpacity = 1.0
                    }
                }
                // Keep glow active while task runs (implicitly via opacity > 0)
                // Wait indefinitely until cancelled
                try await Task.sleep(nanoseconds: .max)
            } catch is CancellationError {
                // Reset on cancellation
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        generatingGlowOpacity = 0.0
                    }
                    showThinkingIndicatorForGeneration = false
                }
            } catch {
                print("Error in generation animation task: \(error)")
            }
        }
    }
    
    private func startThinkingIndicatorAnimation() {
        generatingAnimationTask?.cancel()
        generatingAnimationTask = Task {
            do {
                await MainActor.run {
                    showThinkingIndicatorForGeneration = true
                    // Ensure glow is off if switching
                    withAnimation(.easeInOut(duration: 0.2)) {
                        generatingGlowOpacity = 0.0 
                    }
                }
                // Wait indefinitely until cancelled
                try await Task.sleep(nanoseconds: .max)
            } catch is CancellationError {
                 await MainActor.run {
                     showThinkingIndicatorForGeneration = false
                 }
            } catch {
                print("Error in thinking indicator task: \(error)")
            }
        }
    }
    
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
            default: // Add default case for the Int switch
                break // Do nothing as a fallback
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

    // NEW: Handle pausing random movement
    private func handleThinkingListeningChange(_ isBusy: Bool) {
        if isBusy {
            cancelIrisMovement() // Stop random movement
            // Optionally reset iris position for thinking/listening start
            withAnimation(.easeOut(duration: 0.2)) {
                 irisOffset = 0 
                 irisOffsetY = 0
                 irisScaleY = 1.0 // Reset scale unless overridden by thinking/listening logic
                 // Set cross-eye focus for thinking
                 crossEyedOffset = isThinking ? currentIrisMaxOffset * 0.6 : 0 
             }
        } else {
            // Resume random movement when not busy
            startIrisMovement()
        }
    }

    // --- NEW: Color Pulse Logic --- 
    private func triggerColorPulse(colorTag: String?) {
        pulseTask?.cancel() // Cancel any existing pulse
        pulseColor = nil // Reset immediately
        
        guard let tag = colorTag, let targetColor = colorForKey(tag) else { return }
        
        pulseTask = Task {
            // Phase 1: Quickly fade in the pulse color
            withAnimation(.easeIn(duration: 0.15)) {
                 pulseColor = targetColor.opacity(0.6) // Use helper for consistency
             }
            
            // Hold duration
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds hold
            guard !Task.isCancelled else { return }
            
            // Phase 2: Fade out
             withAnimation(.easeOut(duration: 0.4)) {
                 pulseColor = nil
             }
            pulseTask = nil
        }
    }
    
    // Helper to get color from tag (can be shared or local)
    private func colorForKey(_ key: String?) -> Color? {
        switch key?.lowercased() {
            case "red": return Color.red
            case "blue": return Color.blue
            case "green": return Color.green
            case "yellow": return Color.yellow
            case "purple": return Color.purple
            default: return nil
        }
    }
    // --- End Color Pulse Logic --- 

    private func resetGenerationState() {
        generatingAnimationTask?.cancel() // Ensure task is cancelled
        Task { @MainActor in // Use Task for async main actor update
            withAnimation(.easeInOut(duration: 0.2)) {
                generatingGlowOpacity = 0.0
            }
            showThinkingIndicatorForGeneration = false
        }
    }
}

// Shape for a single eye that can be open or closed
struct EyeShape: Shape {
    var isClosed: Bool
    var strokeWidth: CGFloat
    var isOval: Bool
    var isSquare: Bool // Add isSquare property

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let insetAmount = strokeWidth / 2
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)

        if isClosed {
            path.move(to: CGPoint(x: insetRect.minX, y: insetRect.midY))
            path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.midY))
        } else if isSquare { // Check for square
            // Draw rounded rectangle for square shape
            path.addRoundedRect(in: insetRect, cornerSize: CGSize(width: 3, height: 3)) // Adjust corner radius as needed
        } else { // Draw ellipse (circle or oval)
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
    NeuraEyesView()
        .environmentObject(AppManager()) // Add AppManager to environment
        .padding()
        .preferredColorScheme(.dark)
} 