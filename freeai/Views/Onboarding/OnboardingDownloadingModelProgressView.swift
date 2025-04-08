//
//  OnboardingDownloadingModelProgressView.swift
//  free ai
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftUI
import MLXLMCommon

struct OnboardingDownloadingModelProgressView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var appManager: AppManager
    @Binding var selectedModel: ModelConfiguration
    @Environment(LLMEvaluator.self) var llm
    @State var didSwitchModel = false
    @State private var animationTrigger = false
    @State private var progressScale: CGFloat = 0.8
    @State private var messageIndex = 0
    
    let funMessages = [
        "AI will take over the world, might as well be free...",
        "Loading intelligence...",
        "Downloading brain cells...",
        "Free forever, no subscriptions ever!",
        "No internet needed, complete privacy",
        "Super free, super private, super cool",
        "Freestyle AI, coming right up",
        "No data leaves your device",
        "The future is free and it's looking good",
        "This is what freedom looks like",
        "Free AI for everyone!"
    ]
    
    var installed: Bool {
        llm.progress == 1 && didSwitchModel
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animation and status section
            VStack(spacing: 24) {
                ZStack {
                    // Progress ring
                    Circle()
                        .stroke(
                            Color.primary.opacity(0.2),
                            lineWidth: 8
                        )
                        .frame(width: 120, height: 120)
                    
                    // Progress indicator
                    Circle()
                        .trim(from: 0, to: CGFloat(llm.progress))
                        .stroke(
                            Color.primary,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.2), value: llm.progress)
                    
                    // Keep moon animation for download screen
                    if installed {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        MoonAnimationView(isDone: false)
                            .scaleEffect(progressScale)
                    }
                }
                .scaleEffect(animationTrigger ? 1 : 0.5)
                .opacity(animationTrigger ? 1 : 0)
                
                VStack(spacing: 8) {
                    Text(installed ? "Installation Complete" : "Installing Model")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(appManager.modelDisplayName(selectedModel.name))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .offset(y: animationTrigger ? 0 : 20)
                .opacity(animationTrigger ? 1 : 0)
                
                // Progress text and fun message
                if !installed {
                    VStack(spacing: 12) {
                        Text("\(Int(llm.progress * 100))%")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: llm.progress)
                        
                        Text(funMessages[messageIndex])
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .frame(height: 50)
                            .transition(.opacity)
                            .id("message-\(messageIndex)")
                    }
                    .padding(.top, 8)
                    .opacity(animationTrigger ? 1 : 0)
                }
            }
            
            Spacer()
            
            if installed {
                // Done button with animation
                Button(action: { showOnboarding = false }) {
                    Text("Let's Get Started")
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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text("Please keep the screen on during installation.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animationTrigger ? 1 : 0)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("")
        .toolbar(installed ? .hidden : .visible)
        .navigationBarBackButtonHidden()
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                animationTrigger = true
            }
            
            // Add pulsing animation for the moon
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                progressScale = 1.0
            }
            
            // Cycle through fun messages
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    messageIndex = (messageIndex + 1) % funMessages.count
                }
            }
        }
        .task {
            await loadLLM()
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: installed)
        #endif
        .onChange(of: installed) {
            addInstalledModel()
        }
        .interactiveDismissDisabled(!installed)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }
    
    func loadLLM() async {
        await llm.switchModel(selectedModel)
        didSwitchModel = true
    }
    
    func addInstalledModel() {
        if installed {
            print("added installed model")
            appManager.currentModelName = selectedModel.name
            appManager.addInstalledModel(selectedModel.name)
        }
    }
}

#Preview {
    OnboardingDownloadingModelProgressView(showOnboarding: .constant(true), selectedModel: .constant(ModelConfiguration.defaultModel))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
