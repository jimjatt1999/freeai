//
//  OnboardingView.swift
//  free ai
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appManager: AppManager
    @Binding var showOnboarding: Bool
    @State private var animationTrigger = false
    @State private var fadeInTrigger = false
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var navigateToModelSelection = false
    
    // Onboarding pages content
    let pages = [
        OnboardingPage(
            title: "free ai",
            subtitle: "local intelligence, unlimited freedom",
            features: [
                Feature(icon: "bolt.fill", title: "Fast", description: "Optimized for Apple Silicon"),
                Feature(icon: "lock.shield.fill", title: "Private", description: "Everything stays on your device"),
                Feature(icon: "wand.and.stars", title: "Creative", description: "Freestyle mode for content generation"),
                Feature(icon: "doc.text.magnifyingglass", title: "Organized", description: "Process your notes with AI")
            ]
        ),
        OnboardingPage(
            title: "freestyle",
            subtitle: "create content with AI",
            features: [
                Feature(icon: "square.text.square", title: "Topics", description: "Generate content on any topic"),
                Feature(icon: "arrow.triangle.branch", title: "Flexible", description: "Set your own creativity preferences"),
                Feature(icon: "bookmark", title: "Save", description: "Save interesting content for later"),
                Feature(icon: "bubble.left.and.text.bubble.right", title: "Chat", description: "Continue in a conversation")
            ]
        ),
        OnboardingPage(
            title: "freedump",
            subtitle: "organize your notes with AI",
            features: [
                Feature(icon: "mic", title: "Dictate", description: "Speak your thoughts and ideas"),
                Feature(icon: "wand.and.stars", title: "Process", description: "Transform raw notes into organized content"),
                Feature(icon: "tag", title: "Categorize", description: "Auto-tag and filter your notes"),
                Feature(icon: "pencil", title: "Edit", description: "Refine your processed notes")
            ]
        ),
        OnboardingPage(
            title: "freebuddy",
            subtitle: "natural language reminders",
            features: [
                Feature(icon: "bell", title: "Reminders", description: "Set reminders like \"call mom tomorrow 5pm\""),
                Feature(icon: "figure.walk", title: "Gamification", description: "Level up by completing tasks & get insights"),
                Feature(icon: "app.badge.checkmark", title: "Checklist", description: "Track tasks and stay organized"),
                Feature(icon: "speaker.wave.2", title: "Voice Input", description: "Dictate reminders quickly and easily")
            ]
        )
    ]
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // Background layer
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    // Paging content
                    TabView(selection: $currentPage) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(
                                page: pages[index],
                                geo: geo,
                                animationTrigger: animationTrigger,
                                fadeInTrigger: fadeInTrigger,
                                isActive: currentPage == index
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentPage)
                    
                    // Minimalist Bottom Controls
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 16) { // Increased spacing between dots and button
                            // Page dots
                            HStack(spacing: 8) {
                                ForEach(0..<pages.count, id: \.self) { index in
                                    Circle()
                                        // Use tint color for active dot
                                        .fill(index == currentPage ? appManager.appTintColor.getColor() : Color.secondary.opacity(0.3))
                                        .frame(width: 6, height: 6) // Slightly smaller dots
                                        .animation(.spring(), value: currentPage == index) // Add animation
                                }
                            }
                            
                            Spacer()
                            
                            // Next/Continue Button (Minimal Style)
                            Button {
                                if currentPage < pages.count - 1 {
                                    withAnimation {
                                        currentPage += 1
                                    }
                                } else {
                                    // On last page, navigate to model selection
                                    navigateToModelSelection = true
                                }
                            } label: {
                                HStack(spacing: 6) { // Reduced spacing inside button
                                    Text(currentPage < pages.count - 1 ? "Next" : "Continue")
                                        .font(.headline) // Smaller font
                                        .fontWeight(.medium)
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.weight(.medium)) // Smaller icon
                                }
                                .padding(.horizontal, 20) // Adjust padding
                                .padding(.vertical, 12) // Adjust padding
                                .foregroundColor(currentPage < pages.count - 1 ? appManager.appTintColor.getColor() : Color(.systemBackground)) // Tint for next, background for continue
                                .background(
                                    Capsule()
                                        // Use tint color for Continue background
                                        .fill(currentPage < pages.count - 1 ? Color.clear : appManager.appTintColor.getColor())
                                        // Subtle border for Next button
                                        .overlay(currentPage < pages.count - 1 ? Capsule().stroke(appManager.appTintColor.getColor().opacity(0.5), lineWidth: 1) : nil)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 0 : 16) // Adjust bottom padding based on safe area
                        .padding(.top, 10) // Add some top padding
                        .background(Color(.systemBackground).edgesIgnoringSafeArea(.bottom)) // Ensure background extends
                        .opacity(fadeInTrigger ? 1.0 : 0.0)
                        .animation(.easeInOut, value: currentPage) // Animate changes
                    }
                    // End Minimalist Bottom Controls
                }
                .onAppear {
                    // Sequence the animations for a more dramatic effect
                    withAnimation(.spring(duration: 1.0, bounce: 0.4)) {
                        animationTrigger = true
                    }
                    
                    withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                        fadeInTrigger = true
                    }
                }
                .navigationDestination(isPresented: $navigateToModelSelection) {
                    OnboardingInstallModelView(showOnboarding: $showOnboarding)
                }
                .navigationTitle("")
                .toolbar(.hidden)
            }
        }
    }
}

// Extension to find navigation controller
extension UIViewController {
    func findNavigationController() -> UINavigationController? {
        if let nav = self as? UINavigationController {
            return nav
        }
        
        for child in children {
            if let nav = child.findNavigationController() {
                return nav
            }
        }
        
        if let presenter = presentedViewController {
            if let nav = presenter as? UINavigationController {
                return nav
            }
            
            for child in presenter.children {
                if let nav = child.findNavigationController() {
                    return nav
                }
            }
        }
        
        if let nav = parent as? UINavigationController {
            return nav
        }
        
        return nil
    }
}

// Model to represent a feature
struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

// Model to represent an onboarding page
struct OnboardingPage {
    let title: String
    let subtitle: String
    let features: [Feature]
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let delay: Double
    @State private var appear = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon in a circle - smaller size
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.3).delay(delay)) {
                appear = true
            }
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
        .environmentObject(AppManager())
}
