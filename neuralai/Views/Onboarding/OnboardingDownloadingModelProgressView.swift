//
//  OnboardingDownloadingModelProgressView.swift
//  free ai
//
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
        "Installing AI directly into your device... no cloud needed!",
        "Moving in furniture for the AI living in your phone...",
        "Teaching your device to think for itself...",
        "No internet needed! Works even in elevator shafts!",
        "The entire universe of AI, now in your pocket...",
        "Your device is getting smarter by the second...",
        "Building a tiny AI apartment in your local storage...",
        "All the computing happens right here in your hands...",
        "No data vacations to server farms allowed...",
        "If your phone feels warmer, that's just the AI thinking...",
        "100% offline - works great during zombie apocalypses!"
    ]
    
    var installed: Bool {
        llm.progress == 1 && didSwitchModel
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animation and status section
            VStack(spacing: 30) {
                ZStack {
                    // Progress ring
                    Circle()
                        .stroke(
                            Color.primary.opacity(0.15),
                            lineWidth: 10
                        )
                        .frame(width: 140, height: 140)
                    
                    // Progress indicator
                    Circle()
                        .trim(from: 0, to: CGFloat(llm.progress))
                        .stroke(
                            Color.primary,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.2), value: llm.progress)
                    
                    // Keep moon animation for download screen
                    if installed {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        MoonAnimationView(isDone: false)
                            .scaleEffect(progressScale)
                            .frame(width: 70, height: 70)
                    }
                }
                .scaleEffect(animationTrigger ? 1 : 0.5)
                .opacity(animationTrigger ? 1 : 0)
                
                VStack(spacing: 12) {
                    Text(installed ? "Installation Complete" : "Setting Up neural ai")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(installed ? "Ready to use \(appManager.modelDisplayName(selectedModel.name))" : "downloading \(selectedModel.name.contains("3B") ? "Core 3B" : "Core 1B")")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .offset(y: animationTrigger ? 0 : 20)
                .opacity(animationTrigger ? 1 : 0)
                
                // Progress text and fun message
                if !installed {
                    VStack(spacing: 16) {
                        Text("\(Int(llm.progress * 100))%")
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: llm.progress)
                        
                        Text(funMessages[messageIndex])
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
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
                        .frame(height: 60)
                        .foregroundStyle(.white)
                        .background(Color.primary)
                        .cornerRadius(16)
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
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .ignoresSafeArea()
        .navigationTitle("")
        .toolbar(.hidden)
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
