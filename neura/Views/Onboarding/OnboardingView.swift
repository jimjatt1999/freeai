//
//  OnboardingView.swift
//  free ai
//
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appManager: AppManager
    @Binding var showOnboarding: Bool
    @State private var animationTrigger = false
    @State private var fadeInTrigger = false
    @State private var navigateToModelSelection = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // Background layer
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    // Single page content
                    VStack(spacing: 20) {
                        Spacer()
                            .frame(height: geo.size.height * 0.05)
                        
                        // Neura
                        NeuraEyesView()
                            .scaleEffect(1.5)
                            .opacity(fadeInTrigger ? 1 : 0)
                            .scaleEffect(animationTrigger ? 1 : 0.8)
                            .offset(y: animationTrigger ? 0 : 30)
                            .padding(.bottom, 5)
                        
                        // App title
                        Text("Neura")
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                            .scaleEffect(animationTrigger ? 1 : 0.8)
                            .offset(y: animationTrigger ? 0 : 30)
                            .opacity(fadeInTrigger ? 1 : 0)
                            .padding(.bottom, 1)
                        
                        // Tapping hint
                        Text("(Try tapping my eyes!)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .scaleEffect(animationTrigger ? 1 : 0.8)
                            .offset(y: animationTrigger ? 0 : 30)
                            .opacity(fadeInTrigger ? 1 : 0)
                            .padding(.bottom, 5)
                        
                        // App subtitle
                        Text("Say Hi to Neura your Private on-device AI assistant")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .scaleEffect(animationTrigger ? 1 : 0.8)
                            .offset(y: animationTrigger ? 0 : 30)
                            .opacity(fadeInTrigger ? 1 : 0)
                            .padding(.bottom, 40)
                            .fixedSize(horizontal: false, vertical: true)

                        
                        // Core features list
                        VStack(alignment: .leading, spacing: 20) {
                            FeatureRow(icon: "lock.shield.fill", title: "privacy first", description: "Everything runs locally, no data ever leaves your device, no internet needed. The Power of AI in the palm of your hands")
                            
                            FeatureRow(icon: "message.fill", title: "chat", description: "Have private conversations that stay on your device")
                            
                            FeatureRow(icon: "doc.text.fill", title: "Notes", description: "Transform your thoughts into organized notes with AI")
                            
                            FeatureRow(icon: "bell.fill", title: "Reminders", description: "Create natural language reminders and get things done")
                            
                            FeatureRow(icon: "calendar.day.timeline.left", title: "Daily Digest", description: "Get a personalized summary of your day, including calendar events and reminders.")
                        }
                        .padding(.horizontal, 25)
                        .offset(y: fadeInTrigger ? 0 : 40)
                        .opacity(fadeInTrigger ? 1 : 0)
                        
                        // Continue button
                        Button {
                            navigateToModelSelection = true
                        } label: {
                            Text("Get Started")
                                .font(.system(.headline, design: .monospaced))
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundColor(Color(.systemBackground))
                                .background(appManager.appTintColor.getColor())
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 25)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 16 : 25)
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 30, height: 30, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
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

#Preview {
    OnboardingView(showOnboarding: .constant(true))
        .environmentObject(AppManager())
}
