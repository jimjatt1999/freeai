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

struct MessageView: View {
    @Environment(LLMEvaluator.self) var llm
    @EnvironmentObject var appManager: AppManager
    @State private var collapsed = true
    @State private var animationProgress = 0.0
    @State private var typewriterText = ""
    @State private var shouldAnimate = false
    @State private var cursorVisible = true
    let message: Message

    var isThinking: Bool {
        !message.content.contains("</think>")
    }

    // Animation timing
    let animationDuration: Double = 0.8
    
    // Timer for blinking cursor
    let cursorTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    
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
        
        if appManager.chatAnimationStyle == "typewriter" {
            typewriterAnimation()
        } else {
            withAnimation(.easeOut(duration: animationDuration)) {
                animationProgress = 1.0
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
    
    // Get terminal style text with blinking cursor
    private var terminalText: some View {
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? ""
        
        return VStack(alignment: .leading, spacing: 0) {
            // Terminal header
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Spacer()
                Text("Terminal")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.top, 4)
            .padding(.horizontal, 8)
            
            // Terminal line with prompt
            HStack(alignment: .top, spacing: 4) {
                Text("AI>")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                
                if shouldAnimate && animationProgress < 1.0 {
                    Text("\(typewriterText)\(cursorVisible ? "█" : " ")")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                } else {
                    Text("\(finalText)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onReceive(cursorTimer) { _ in 
            if shouldAnimate && animationProgress < 1.0 {
                cursorVisible.toggle()
            } else {
                cursorVisible = false
            }
        }
    }
    
    // Get minimalist animated text
    private var minimalistText: some View {
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? ""
        
        return VStack(alignment: .leading, spacing: 8) {
            // Extract title and content if possible
            let lines = finalText.split(separator: "\n", maxSplits: 1)
            
            if lines.count > 1 {
                // Title
                Text(String(lines[0]))
                    .font(.system(.headline, design: .default))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .padding(.bottom, 2)
                
                // Content with typing animation
                if shouldAnimate && animationProgress < 1.0 {
                    Text(typewriterText)
                        .font(.system(.body, design: .default))
                        .fontWeight(.light)
                        .foregroundColor(.primary.opacity(0.9))
                        .lineSpacing(6)
                        .animation(.easeInOut, value: typewriterText)
                } else {
                    Text(String(lines[1]))
                        .font(.system(.body, design: .default))
                        .fontWeight(.light)
                        .foregroundColor(.primary.opacity(0.9))
                        .lineSpacing(6)
                }
            } else {
                // Just content, no title
                if shouldAnimate && animationProgress < 1.0 {
                    Text(typewriterText)
                        .font(.system(.body, design: .default))
                        .fontWeight(.light)
                        .foregroundColor(.primary.opacity(0.9))
                        .lineSpacing(6)
                } else {
                    Text(finalText)
                        .font(.system(.body, design: .default))
                        .fontWeight(.light)
                        .foregroundColor(.primary.opacity(0.9))
                        .lineSpacing(6)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    // Get retro text with pixelated styling
    private var retroText: some View {
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? message.content
        
        return VStack(alignment: .leading, spacing: 4) {
            Text(finalText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(message.role == .assistant ? Color.green : Color.blue)
                .padding(8)
                .background(
                    ZStack {
                        // Scanlines effect
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.3)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .mask(
                            VStack(spacing: 2) {
                                ForEach(0..<20, id: \.self) { _ in
                                    Color.white
                                        .frame(height: 1)
                                }
                            }
                        )
                        
                        // Base background
                        Color.black
                            .opacity(0.8)
                    }
                )
                .cornerRadius(0)
                .overlay(
                    Rectangle()
                        .strokeBorder(message.role == .assistant ? Color.green.opacity(0.6) : Color.blue.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: message.role == .assistant ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), radius: 8, x: 0, y: 0)
        }
        .scaleEffect(shouldAnimate ? 1.0 : 0.95)
        .opacity(shouldAnimate ? 1.0 : 0.0)
        .animation(.easeOut(duration: animationDuration), value: shouldAnimate)
    }
    
    // Get futuristic text with modern styling
    private var futuristicText: some View {
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? message.content
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Circle()
                    .fill(message.role == .assistant ? Color.purple : Color.blue)
                    .frame(width: 8, height: 8)
                
                Text(message.role == .assistant ? "AI" : "USER")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(Date(), style: .time)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            
            // Content
            Text(finalText)
                .font(.system(.body, design: .rounded))
                .lineSpacing(6)
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.02))
                .shadow(color: Color.primary.opacity(0.05), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            message.role == .assistant ? Color.purple : Color.blue,
                            message.role == .assistant ? Color.blue : Color.cyan
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(shouldAnimate ? 1.0 : 0.9)
        .opacity(shouldAnimate ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shouldAnimate)
    }
    
    // Get handwritten text style
    private var handwrittenText: some View {
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? message.content
        
        return Text(finalText)
            .font(.custom("Noteworthy", size: 16))
            .foregroundColor(message.role == .assistant ? Color.black : Color.blue)
            .lineSpacing(8)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.yellow.opacity(0.2))
            )
            .rotationEffect(.degrees(shouldAnimate ? 0 : -1))
            .scaleEffect(shouldAnimate ? 1.0 : 0.9)
            .opacity(shouldAnimate ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: shouldAnimate)
    }
    
    // Get comic style text with speech bubbles
    private var comicText: some View {
        let (_, afterThink) = processThinkingContent(message.content)
        let finalText = afterThink ?? message.content
        
        return Text(finalText)
            .font(.custom("Marker Felt", size: 16))
            .foregroundColor(.black)
            .lineSpacing(6)
            .padding(16)
            .background(
                ZStack(alignment: message.role == .assistant ? .bottomLeading : .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.role == .assistant ? Color.white : Color.blue.opacity(0.2))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    // Speech bubble tail
                    if message.role == .assistant {
                        Triangle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(180))
                            .offset(x: -5, y: 10)
                    } else {
                        Triangle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .offset(x: 5, y: 10)
                    }
                }
            )
            .scaleEffect(shouldAnimate ? 1.0 : 0.8)
            .opacity(shouldAnimate ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: shouldAnimate)
    }

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            if message.role == .assistant {
                let (thinking, afterThink) = processThinkingContent(message.content)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        // ChatGPT logo for assistant messages
                        Image(systemName: "waveform.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.black)
                            .background(Color.white)
                            .clipShape(Circle())
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            if let thinking {
                                VStack(alignment: .leading, spacing: 12) {
                                    thinkingLabel
                                    if !collapsed {
                                        if !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            HStack(spacing: 12) {
                                                Capsule()
                                                    .frame(width: 2)
                                                    .padding(.vertical, 1)
                                                    .foregroundStyle(.fill)
                                                Markdown(thinking)
                                                    .textSelection(.enabled)
                                                    .markdownTextStyle {
                                                        ForegroundColor(.secondary)
                                                    }
                                            }
                                            .padding(.leading, 5)
                                        }
                                    }
                                }
                                .contentShape(.rect)
                                .onTapGesture {
                                    collapsed.toggle()
                                    if isThinking {
                                        llm.collapsed = collapsed
                                    }
                                }
                            }

                            if let afterThink {
                                Group {
                                    switch appManager.chatAnimationStyle {
                                    case "fade":
                                        Markdown(afterThink)
                                            .textSelection(.enabled)
                                            .opacity(shouldAnimate ? animationProgress : 1)
                                    case "bounce":
                                        Markdown(afterThink)
                                            .textSelection(.enabled)
                                            .scaleEffect(shouldAnimate ? (animationProgress < 1.0 ? 0.95 + (animationProgress * 0.05) : 1.0) : 1)
                                            .opacity(shouldAnimate ? animationProgress : 1)
                                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animationProgress)
                                            .transformEffect(.init(translationX: 0, y: shouldAnimate ? (animationProgress < 1.0 ? (1.0 - animationProgress) * 10 : 0) : 0))
                                    case "typewriter":
                                        if shouldAnimate && animationProgress < 1.0 {
                                            Text(typewriterText)
                                                .textSelection(.enabled)
                                        } else {
                                            Markdown(afterThink)
                                                .textSelection(.enabled)
                                        }
                                    case "terminal":
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.black)
                                                
                                            terminalText
                                                .textSelection(.enabled)
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray, lineWidth: 1)
                                        )
                                    case "minimalist":
                                        minimalistText
                                            .textSelection(.enabled)
                                    case "retro":
                                        retroText
                                            .textSelection(.enabled)
                                    case "futuristic":
                                        futuristicText
                                            .textSelection(.enabled)
                                    case "handwritten":
                                        handwrittenText
                                            .textSelection(.enabled)
                                    case "comic":
                                        comicText
                                            .textSelection(.enabled)
                                    default: // "none" or any other value
                                        Markdown(afterThink)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 48)
                .onAppear {
                    startAnimation()
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    // User avatar for user messages
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white)
                        .background(Color.gray.opacity(0.7))
                        .clipShape(Circle())
                        .padding(.top, 4)
                    
                    // Apply the same animation styles to user messages
                    Group {
                        switch appManager.chatAnimationStyle {
                        case "fade":
                            Markdown(message.content)
                                .textSelection(.enabled)
                                .opacity(shouldAnimate ? animationProgress : 1)
                        case "bounce":
                            Markdown(message.content)
                                .textSelection(.enabled)
                                .scaleEffect(shouldAnimate ? (animationProgress < 1.0 ? 0.95 + (animationProgress * 0.05) : 1.0) : 1)
                                .opacity(shouldAnimate ? animationProgress : 1)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animationProgress)
                                .transformEffect(.init(translationX: 0, y: shouldAnimate ? (animationProgress < 1.0 ? (1.0 - animationProgress) * 10 : 0) : 0))
                        case "typewriter":
                            if shouldAnimate && animationProgress < 1.0 {
                                Text(typewriterText)
                                    .textSelection(.enabled)
                            } else {
                                Markdown(message.content)
                                    .textSelection(.enabled)
                            }
                        case "terminal":
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black)
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    // Terminal header
                                    HStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 8, height: 8)
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Spacer()
                                        Text("Terminal")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                    .padding(.horizontal, 8)
                                    
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("USER>")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.cyan)
                                        
                                        Text(message.content)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.cyan)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .textSelection(.enabled)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        case "minimalist":
                            VStack(alignment: .leading, spacing: 8) {
                                // Extract title and content if possible
                                let lines = message.content.split(separator: "\n", maxSplits: 1)
                                
                                if lines.count > 1 {
                                    // Title
                                    Text(String(lines[0]))
                                        .font(.system(.headline, design: .default))
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .padding(.bottom, 2)
                                    
                                    Text(String(lines[1]))
                                        .font(.system(.body, design: .default))
                                        .fontWeight(.light)
                                        .foregroundColor(.primary.opacity(0.9))
                                        .lineSpacing(6)
                                } else {
                                    // Just content, no title
                                    Text(message.content)
                                        .font(.system(.body, design: .default))
                                        .fontWeight(.light)
                                        .foregroundColor(.primary.opacity(0.9))
                                        .lineSpacing(6)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity(0.03))
                            )
                            .textSelection(.enabled)
                        case "retro":
                            retroText
                                .textSelection(.enabled)
                        case "futuristic":
                            futuristicText
                                .textSelection(.enabled)
                        case "handwritten":
                            handwrittenText
                                .textSelection(.enabled)
                        case "comic":
                            comicText
                                .textSelection(.enabled)
                        default: // "none" or any other value
                            Markdown(message.content)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .padding(.leading, 16)
                .onAppear {
                    // Start animation for user messages too
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        startAnimation()
                    }
                }
            }

            if message.role == .assistant { Spacer() }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(message.role == .assistant ? Color(.systemBackground) : Color.clear)
        .onAppear {
            if llm.running {
                collapsed = false
            }
            
            if message.role == .assistant && !isThinking {
                // Start animation when message appears and is not in thinking state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startAnimation()
                }
            }
        }
        .onChange(of: llm.elapsedTime) {
            if isThinking {
                llm.thinkingTime = llm.elapsedTime
            }
        }
        .onChange(of: isThinking) {
            if llm.running {
                llm.isThinking = isThinking
            }
        }
    }

    let platformBackgroundColor: Color = {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(visionOS)
        return Color(UIColor.separator)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }()
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
                        MessageView(message: message)
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
                            MessageView(message: Message(role: .assistant, content: llm.output))
                            
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
