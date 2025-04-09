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
                    
                    // Bottom controls - fixed position with better separation
                    VStack {
                        Spacer()
                        
                        // Add a subtle divider line
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .opacity(fadeInTrigger ? 1 : 0)
                        
                        // Page indicator and buttons
                        HStack {
                            // Page dots
                            HStack(spacing: 8) {
                                ForEach(0..<pages.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            Spacer()
                            
                            // Next/Continue button
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
                                HStack {
                                    Text(currentPage < pages.count - 1 ? "Next" : "Continue")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.body.bold())
                                        .padding(.leading, 4)
                                }
                                .frame(width: 160)
                                .frame(height: 60)
                                .foregroundStyle(.white)
                                .background(Color.primary)
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .background(
                            Rectangle()
                                .fill(Color(.systemBackground))
                                .edgesIgnoringSafeArea(.bottom)
                        )
                        .opacity(fadeInTrigger ? 1.0 : 0.0)
                    }
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
}
