//
//  ConversationView.swift
//  free ai
//
//  Created by Xavier on 16/12/2024.
//

import MarkdownUI
import SwiftUI

extension TimeInterval {
    var formatted: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

// --- Custom Markdown Theme for Plain Style ---
extension Theme {
    static var plain: Theme {
        Theme()
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .font(.system(.body, design: .monospaced))
                        .relativeLineSpacing(.em(0.25))
                        .padding()
                }
                .background(Color(.secondarySystemBackground)) // Subtle background for code
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: .em(0.5), bottom: .em(0.5))
            }
    }
}
// --- End Custom Theme ---

struct MessageView: View {
    @Environment(LLMEvaluator.self) var llm
    @EnvironmentObject var appManager: AppManager
    
    // Thinking state
    @State private var collapsed = true
    var isThinking: Bool { !message.content.contains("</think>") }

    // Animation states
    @State private var shouldAnimate = false
    @State private var animationProgress = 0.0
    @State private var typewriterText = ""
    @State private var cursorVisible = true
    
    // Terminal effect states
    @State private var flickerOpacity: Double = 0.0
    @State private var jitterOffset: CGSize = .zero
    @State private var staticOpacity: Double = 0.0
    @State private var isHovering = false
    
    let message: Message
    let isGenerating: Bool

    // Timers
    let cursorTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    let effectsTimer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
    
    // Computed properties for colors based on scheme
    private var textColor: Color { appManager.terminalColorScheme.textColor }
    private var bgColor: Color { appManager.terminalColorScheme.backgroundColor }
    private var userPromptColor: Color { appManager.terminalColorScheme.promptUserColor }
    private var aiPromptColor: Color { appManager.terminalColorScheme.promptAiColor }

    // --- Body --- 
    var body: some View {
        // Conditionally apply custom styling or plain text
        Group {
            if appManager.chatInterfaceStyleEnabled {
                styledMessageBody // Use the styled version
            } else {
                plainMessageBody // Use the plain version
            }
        }
        // Move modifiers that apply regardless of style here
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onChange(of: llm.elapsedTime, perform: { _ in updateThinkingTimeIfNeeded() })
        .onChange(of: isThinking, perform: { _ in updateLLMThinkingStateIfNeeded() })
    } // End body
    
    // --- Styled Terminal Body --- 
    private var styledMessageBody: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer() }

            VStack(alignment: .leading, spacing: 4) {
                // Conditionally show window controls header
                if appManager.terminalWindowControlsEnabled {
                    windowControlsHeader
                }
                
                // Thinking label + Content
                if message.role == .assistant {
                    let (thinking, afterThink) = processThinkingContent(message.content)
                    if let thinking = thinking { thinkingLabelView(thinking: thinking) }
                    if let afterThink = afterThink { terminalMessageContent(content: afterThink) }
                } else {
                    terminalMessageContent(content: message.content)
                }
            }
            .padding(.vertical, appManager.terminalWindowControlsEnabled ? 4 : 8) // Adjust padding based on header
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .background(
                 bgColor
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: textColor.opacity(appManager.terminalBloomEnabled ? 0.5 : 0), radius: appManager.terminalBloomEnabled ? 9 : 0, x: 0, y: 0)
             )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(textColor.opacity(0.5), lineWidth: 1)
            )
            .onAppear(perform: startAnimationIfNeeded)
            
            if message.role == .assistant { Spacer() }
        }
        // Modifiers specific to the styled view can remain here if needed
    }
    
    // --- Plain Text Body --- 
    private var plainMessageBody: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer() } // Align user right

            VStack(alignment: .leading, spacing: 4) {
                // Show thinking label simply if present
                if message.role == .assistant {
                    let (thinking, afterThink) = processThinkingContent(message.content)
                    if let thinking = thinking, !collapsed {
                        // Revert thinking label to simple Text
                        Text("(Thinking...)")
                            .font(.caption.monospaced()) // Use standard SwiftUI modifiers
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                    }
                    // Use Markdown view to render content with custom theme
                    if let afterThink = afterThink {
                        Markdown(afterThink)
                            .textSelection(.enabled)
                            .markdownTheme(.plain)
                    }
                } else {
                    // Use Markdown view for user content too with custom theme
                    Markdown(message.content)
                        .textSelection(.enabled)
                        .markdownTheme(.plain)
                }
            }
            .padding(.vertical, 8) // Keep some vertical padding
            .padding(.horizontal, 12) // Add some horizontal padding to prevent edge collision
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .onAppear {
                shouldAnimate = false
                animationProgress = 1.0
            }
            
            if message.role == .assistant { Spacer() } // Align assistant left
        }
    }
    
    // --- New Window Controls Header --- 
    @ViewBuilder
    private var windowControlsHeader: some View {
        HStack(spacing: 8) {
            switch appManager.terminalWindowControlsStyle {
            case .macOS:
                Circle().fill(.red).frame(width: 10, height: 10)
                Circle().fill(.yellow).frame(width: 10, height: 10)
                Circle().fill(.green).frame(width: 10, height: 10)
            case .windows:
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .background(Color.gray.opacity(0.2))
                
                Image(systemName: "square")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.gray.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .background(Color.gray.opacity(0.2))
                
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 12, height: 12)
                    .background(Color.red.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // --- Terminal Content View (Remains largely the same) --- 
    @ViewBuilder
    private func terminalMessageContent(content: String) -> some View {
        ZStack {
            // --- Optional Effects Layers (Bottom) ---
            if appManager.terminalStaticEnabled {
                Canvas { context, size in
                    context.opacity = staticOpacity // Control overall noise visibility
                    // Keep density relatively low for performance
                    let density = 0.10 
                    let dotCount = Int(size.width * size.height * density * 0.03) 
                    
                    for _ in 0..<dotCount {
                        let x = CGFloat.random(in: 0..<size.width)
                        let y = CGFloat.random(in: 0..<size.height)
                        // Increase brightness range
                        let grayValue = Double.random(in: 0.5...0.9) 
                        // Slightly larger max dot size
                        let dotSize = CGFloat.random(in: 0.5...1.8) 
                        
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)), 
                                     with: .color(Color(white: grayValue)))
                    }
                }
                .blendMode(.screen) 
                // Increase base opacity slightly
                .opacity(0.6) 
                .allowsHitTesting(false)
                .clipped()
            }
            
            if appManager.terminalScanlinesEnabled {
                 enhancedScanLinesEffect
                    .allowsHitTesting(false)
                    .clipped()
            }
            
            if appManager.terminalFlickerEnabled {
                Color.white.opacity(flickerOpacity)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                    .clipped()
            }
            
            // --- Main Text Content ---
            HStack(alignment: .top, spacing: 4) {
                Text(message.role == .user ? "USER>" : "AI>")
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundColor(message.role == .user ? userPromptColor : aiPromptColor)
                    .padding(.leading, 8)
                
                Group {
                    if shouldAnimate && animationProgress < 1.0 && message.role == .assistant {
                        Text("\(typewriterText)\(cursorVisible ? "█" : " ")")
                            .lineSpacing(4)
                    } else {
                        Text(content)
                           .lineSpacing(4)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .offset(appManager.terminalJitterEnabled ? jitterOffset : .zero)
                .blur(radius: appManager.terminalBloomEnabled ? 0.6 : 0)
                .shadow(color: appManager.terminalBloomEnabled ? textColor.opacity(0.4) : .clear, radius: appManager.terminalBloomEnabled ? 0.8 : 0)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.trailing, 8)
        }
        .onReceive(cursorTimer, perform: { _ in updateCursorVisibility() })
        .onReceive(effectsTimer) { _ in
            updateFlicker()
            updateJitter()
        }
        .onHover { hovering in
            isHovering = hovering
            updateStatic(isHovering: hovering)
        }
        .onChange(of: isGenerating) { _, newGeneratingState in
            if !newGeneratingState {
                updateStatic(isHovering: isHovering)
            }
        }
        .textSelection(.enabled)
    }
    
    // --- Effect Helper Views --- 
    private var enhancedScanLinesEffect: some View {
        GeometryReader { geo in
            let lineHeight: CGFloat = 2.5
            let lineSpacing: CGFloat = 1.5
            let totalLines = Int(geo.size.height / (lineHeight + lineSpacing))
            
            VStack(spacing: lineSpacing) {
                ForEach(0..<totalLines, id: \.self) { _ in
                    Rectangle()
                        .fill(bgColor)
                        .frame(height: lineHeight)
                        .opacity(0.15)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
    }
    
    // --- Timer Update Functions (Check master toggle) --- 
    private func updateFlicker() {
        guard appManager.chatInterfaceStyleEnabled && appManager.terminalFlickerEnabled else {
            if flickerOpacity != 0 { flickerOpacity = 0 } 
            return
        }
        flickerOpacity = Double.random(in: 0.0...0.03)
    }
    
    private func updateJitter() {
        guard appManager.chatInterfaceStyleEnabled && appManager.terminalJitterEnabled else {
            if jitterOffset != .zero { jitterOffset = .zero } 
            return
        }
        jitterOffset = CGSize(width: CGFloat.random(in: -0.5...0.5), height: CGFloat.random(in: -0.5...0.5))
    }
    
    private func updateStatic(isHovering: Bool) {
        guard appManager.chatInterfaceStyleEnabled && appManager.terminalStaticEnabled else {
            if staticOpacity != 0 { staticOpacity = 0 }
            return
        }
        if isHovering || isGenerating {
            staticOpacity = Double.random(in: 0.0...0.08)
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                staticOpacity = 0.0
            }
        }
    }

    // --- Thinking Label View (Keep as is) ---
    @ViewBuilder
    private func thinkingLabelView(thinking: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            thinkingLabel // The HStack with button and text
            if !collapsed && !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 12) {
                    Capsule()
                        .frame(width: 2)
                        .padding(.vertical, 1)
                        .foregroundStyle(.fill)
                    Markdown(thinking)
                        .textSelection(.enabled)
                        .markdownTextStyle { ForegroundColor(.secondary) }
                }
                .padding(.leading, 5)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            collapsed.toggle()
            if isThinking { llm.collapsed = collapsed }
        }
    }
    
    // --- Core Logic Helpers (Keep as is) ---
    private func startAnimationIfNeeded() {
        // Simplified logic from original .onAppear
        if llm.running { collapsed = false }
        if message.role == .assistant && !isThinking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { startAnimation() }
        } else if message.role == .user {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { startAnimation() }
        }
    }
    
    private func updateThinkingTimeIfNeeded() {
        if isThinking { llm.thinkingTime = llm.elapsedTime }
    }
    
    private func updateLLMThinkingStateIfNeeded() {
        if llm.running { llm.isThinking = isThinking }
    }
    
    func processThinkingContent(_ content: String) -> (String?, String?) {
        guard let startRange = content.range(of: "<think>") else {
            // No <think> tag, return entire content as the second part
            return (nil, content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let endRange = content.range(of: "</think>") else {
            // No </think> tag, return content after <think> without the tag
            let thinking = String(content[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking, nil)
        }

        let thinking = String(content[startRange.upperBound ..< endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let afterThink = String(content[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return (thinking, afterThink.isEmpty ? nil : afterThink)
    }

    var time: String {
        if llm.running, let elapsedTime = llm.elapsedTime {
            if isThinking {
                return "(\(elapsedTime.formatted))"
            }
            if let thinkingTime = llm.thinkingTime {
                return thinkingTime.formatted
            }
        }

        if let generatingTime = message.generatingTime {
            return "\(generatingTime.formatted)"
        }

        return "0s"
    }

    var thinkingLabel: some View {
        HStack {
            Button {
                collapsed.toggle()
            } label: {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 12))
                    .fontWeight(.medium)
            }

            Text("\(isThinking ? "thinking..." : "thought for") \(time)")
                .italic()
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
    
    // Function to start animation when view appears
    private func startAnimation() {
        guard shouldAnimate == false else { return }
        shouldAnimate = true
        
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? ""
        
        // Reset the typewriter text
        typewriterText = ""
        
        // Calculate typing speed based on content length
        let characterCount = finalText.count
        let baseSpeed = max(0.01, min(0.05, Double(characterCount) * 0.0005))
        
        // Schedule a series of updates to simulate typing
        for index in 0..<characterCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * baseSpeed) {
                let stringIndex = finalText.index(finalText.startIndex, offsetBy: index)
                typewriterText = String(finalText[...stringIndex])
                
                // Update animation progress for combined effects
                animationProgress = Double(index) / Double(characterCount)
                
                // Ensure we mark it as complete at the end
                if index == characterCount - 1 {
                animationProgress = 1.0
                }
            }
        }
    }
    
    // Typewriter animation effect
    private func typewriterAnimation() {
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? ""
        
        // Reset the typewriter text
        typewriterText = ""
        
        // Calculate typing speed based on content length
        let characterCount = finalText.count
        let baseSpeed = max(0.01, min(0.05, Double(characterCount) * 0.0005))
        
        // Schedule a series of updates to simulate typing
        for index in 0..<characterCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * baseSpeed) {
                let stringIndex = finalText.index(finalText.startIndex, offsetBy: index)
                typewriterText = String(finalText[...stringIndex])
                
                // Update animation progress for combined effects
                animationProgress = Double(index) / Double(characterCount)
                
                // Ensure we mark it as complete at the end
                if index == characterCount - 1 {
                    animationProgress = 1.0
                }
            }
        }
    }
    
    private func updateCursorVisibility() {
        if message.role == .assistant && shouldAnimate && animationProgress < 1.0 {
                cursorVisible.toggle()
            } else {
                cursorVisible = false
            }
        }
}

struct ConversationView: View {
    @Environment(LLMEvaluator.self) var llm
    @EnvironmentObject var appManager: AppManager
    let thread: Thread
    let generatingThreadID: UUID?

    @State private var scrollID: String?
    @State private var scrollInterrupted = false
    @State private var disableAllAnimations = false

    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(thread.sortedMessages) { message in
                        VStack(spacing: 0) {
                        MessageView(message: message, isGenerating: generatingThreadID == message.id)
                            .id(message.id.uuidString)
                            .animation(disableAllAnimations ? nil : .default, value: message.id)
                            
                            if message.role == .assistant {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }

                    if llm.running && !llm.output.isEmpty && thread.id == generatingThreadID {
                        VStack(spacing: 0) {
                            MessageView(message: Message(role: .assistant, content: llm.output), isGenerating: true)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 4, height: 4)
                                    .opacity(0.7)
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 4, height: 4)
                                    .opacity(0.7)
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 4, height: 4)
                                    .opacity(0.7)
                        }
                            .padding(.leading, 48)
                            .padding(.top, 8)
                            
                            Divider()
                                .padding(.horizontal)
                        }
                        .id("output")
                        .onAppear {
                            scrollInterrupted = false // reset interruption when a new output begins
                        }
                    }

                    Rectangle()
                        .fill(.clear)
                        .frame(height: 1)
                        .id("bottom")
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollID, anchor: .bottom)
            .onChange(of: llm.output) { _, _ in
                // auto scroll to bottom
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom", anchor: .bottom)
                }

                if !llm.isThinking {
                    appManager.playHaptic()
                }
            }
            .onChange(of: scrollID) { _, _ in
                // interrupt auto scroll to bottom if user scrolls away
                if llm.running {
                    scrollInterrupted = true
                }
            }
            .onAppear {
                // Temporarily disable animations when the view first appears
                disableAllAnimations = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    disableAllAnimations = false
                }
            }
            .onDisappear {
                // Disable animations when leaving the view to prevent unwanted effects
                disableAllAnimations = true
            }
        }
        .defaultScrollAnchor(.bottom)
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
        #endif
    }
}

// Triangle shape for comic speech bubbles
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    let thread = Thread()
    let message1 = Message(role: .user, content: "Hello! Can you explain quantum computing?", thread: thread)
    let message2 = Message(role: .assistant, content: "<think>Quantum computing is a complex topic that uses principles of quantum mechanics to process information. Let me provide a clear explanation.</think>Quantum computing uses quantum bits or 'qubits' that can exist in multiple states simultaneously, unlike classical bits that are either 0 or 1. This allows quantum computers to solve certain problems exponentially faster than classical computers.", thread: thread)
    
    return ConversationView(thread: thread, generatingThreadID: nil)
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
