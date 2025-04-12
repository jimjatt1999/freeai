//
//  LaunchView.swift
//  free ai
//
//

import SwiftUI

struct LaunchView: View {
    @State private var opacity1: Double = 0
    @State private var opacity2: Double = 0
    @State private var opacity3: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var pulseScale: CGFloat = 1.0
    @State private var showMainContent = false
    @EnvironmentObject var appManager: AppManager
    @State private var currentSubtitle: String = ""
    
    // Predefined subtitles (no "free", no emojis)
    private let subtitles = [
        "Just predicting tokens...",
        "Don't worry, I don't dream of electric sheep.",
        "Running fully on your device.",
        "Warming up the Neural nets.",
        "Keeping your data local.",
        "Thinking probabilistically.",
        "Calculating the meaning of life... almost.",
        "Making the transistors sweat.",
        "On-device intelligence loading...",
        "Engaging cognitive subroutines.",
        "Analyzing the user's awesomeness."
    ]
    
    var body: some View {
        ZStack {
            if showMainContent {
                ContentView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    // --- Replace Rectangle with Neura --- 
                    if appManager.showNeuraEyes {
                        NeuraEyesView()
                            .scaleEffect(2.0) // Make the eyes larger for launch
                            .opacity(opacity1) // Use existing opacity animation
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(appManager.appTintColor.getColor())
                            .opacity(opacity1)
                    }
                    
                    Text("Neura")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(opacity1)
                        .scaleEffect(scale)
                    
                    Text(currentSubtitle)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .opacity(opacity2)
                        .scaleEffect(scale)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                #if !os(visionOS)
                .tint(appManager.appTintColor.getColor())
                #endif
                .transition(.opacity)
            }
        }
        .onAppear {
            // Select a random subtitle
            currentSubtitle = subtitles.randomElement() ?? "Initializing..."
            
            // Eyes/Opacity animation
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                opacity1 = 1
                // scale = 1 // Keep scale if using scale animation for eyes
            }
            
            // Message animation
            withAnimation(.easeOut(duration: 0.8).delay(0.7)) {
                opacity2 = 1
            }
            
            // Transition to main content
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showMainContent = true
                }
            }
        }
    }
}

#Preview {
    LaunchView()
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
} 