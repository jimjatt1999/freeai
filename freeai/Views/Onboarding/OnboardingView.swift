//
//  OnboardingView.swift
//  free ai
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var animationTrigger = false
    @State private var featureAnimationDelay = 0.0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                // Logo and title section
                VStack(spacing: 16) {
                    // Icon instead of moon
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.primary)
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .scaleEffect(animationTrigger ? 1.0 : 0.5)
                        .opacity(animationTrigger ? 1.0 : 0.0)
                    
                    // Title and subtitle
                    VStack(spacing: 8) {
                        Text("free ai")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                        
                        Text("chat freely with local language models\ninternet free")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .offset(y: animationTrigger ? 0 : 20)
                    .opacity(animationTrigger ? 1.0 : 0.0)
                }
                .padding(.top, 60)
                
                // Features section
                VStack(alignment: .leading, spacing: 24) {
                    FeatureRow(
                        icon: "cpu",
                        title: "Quick",
                        description: "Optimized for Apple Silicon",
                        delay: 0
                    )
                    
                    FeatureRow(
                        icon: "lock.shield.fill",
                        title: "Private",
                        description: "Everything stays on your device",
                        delay: 0.2
                    )
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Get started button with animation
                NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding)) {
                    Text("Let's Begin")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(.white)
                        .background(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(animationTrigger ? 1.0 : 0.0)
                .offset(y: animationTrigger ? 0 : 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(.systemBackground)
            )
            .onAppear {
                withAnimation(.spring(duration: 0.8)) {
                    animationTrigger = true
                }
            }
            .navigationTitle("")
            .toolbar(.hidden)
        }
        #if os(macOS)
        .frame(width: 480, height: 640)
        #endif
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let delay: Double
    @State private var appear = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.primary)
                .frame(width: 48, height: 48)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground).opacity(0.8))
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .offset(x: appear ? 0 : -20)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.6).delay(delay)) {
                appear = true
            }
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
