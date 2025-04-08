//
//  LaunchView.swift
//  free ai
//
//  Created by Jordan Singer on 4/8/24.
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
    @State private var launchMessage: String = ""
    
    var body: some View {
        ZStack {
            if showMainContent {
                ContentView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Minimalist launch icon (removing the moon)
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 60, height: 60)
                        .cornerRadius(15)
                        .opacity(opacity1)
                        .scaleEffect(scale * pulseScale)
                        .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseScale)
                    
                    Text("free ai")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(opacity1)
                        .scaleEffect(scale)
                    
                    Text(launchMessage)
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
            // Load the random message
            launchMessage = UserDefaults.standard.string(forKey: "currentLaunchMessage") ?? "completely free forever"
            
            // First text animation
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                opacity1 = 1
                scale = 1
            }
            
            // Second text animation
            withAnimation(.easeOut(duration: 0.8).delay(0.7)) {
                opacity2 = 1
            }
            
            // Pulse animation
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
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