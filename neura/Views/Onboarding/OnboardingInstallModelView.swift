//
//  OnboardingInstallModelView.swift
//  free ai
//
//

import MLXLMCommon
import SwiftUI

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var deviceSupportsMetal3: Bool = true
    @Binding var showOnboarding: Bool
    @State var selectedModel = ModelConfiguration.defaultModel
    let suggestedModel = ModelConfiguration.defaultModel
    @State private var animationTrigger = false

    func sizeBadge(_ model: ModelConfiguration?) -> String? {
        guard let size = model?.modelSize else { return nil }
        return "\(size) GB"
    }

    var modelsList: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 18) {
                // Minimalist icon
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 60, height: 60)
                    .cornerRadius(16)
                    .scaleEffect(animationTrigger ? 1.0 : 0.5)
                    .opacity(animationTrigger ? 1.0 : 0.0)

                VStack(spacing: 12) {
                    Text("Let's get you started")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text("Choose a model that lives entirely on your device")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .offset(y: animationTrigger ? 0 : 20)
                .opacity(animationTrigger ? 1.0 : 0.0)
            }
            .padding(.top, 60)
            .padding(.bottom, 10)

            // Model sections
            ScrollView {
                VStack(spacing: 26) {
                    if appManager.installedModels.count > 0 {
                        ModelSection(
                            title: "Installed",
                            delay: 0.1
                        ) {
                            ForEach(appManager.installedModels, id: \.self) { modelName in
                                let model = ModelConfiguration.getModelByName(modelName)
                                ModelRow(
                                    title: appManager.modelDisplayName(modelName),
                                    subtitle: nil,
                                    isSelected: false,
                                    isDisabled: true,
                                    size: sizeBadge(model),
                                    isInstalled: true
                                )
                            }
                        }
                        
                        // Show available models section if there are any non-installed models
                        if !filteredModels.isEmpty {
                            ModelSection(
                                title: "Available Models",
                                delay: 0.2
                            ) {
                                ForEach(filteredModels, id: \.name) { model in
                                    ModelRow(
                                        title: appManager.modelDisplayName(model.name),
                                        subtitle: model.name.contains("3B") ? 
                                            "The big brain that lives in your phone - no cloud needed" : 
                                            "Light and zippy - the AI that fits in your pocket",
                                        isSelected: selectedModel.name == model.name,
                                        isDisabled: false,
                                        size: sizeBadge(model),
                                        action: { selectedModel = model }
                                    )
                                }
                            }
                        }
                    } else {
                        ModelSection(
                            title: "Choose a Model",
                            delay: 0.1
                        ) {
                            // Core 1B (previously Llama 3.2 1B)
                            ModelRow(
                                title: "Core 1B",
                                subtitle: "Light and zippy - the AI that fits in your pocket",
                                isSelected: selectedModel.name == suggestedModel.name,
                                isDisabled: false,
                                size: sizeBadge(suggestedModel),
                                action: { selectedModel = suggestedModel }
                            )
                            
                            // Core 3B (previously Llama 3.2 3B)
                            if let model3b = ModelConfiguration.getModelByName("mlx-community/Llama-3.2-3B-Instruct-4bit") {
                                ModelRow(
                                    title: "Core 3B",
                                    subtitle: "The big brain that lives in your phone - no cloud needed",
                                    isSelected: selectedModel.name == model3b.name,
                                    isDisabled: false,
                                    size: sizeBadge(model3b),
                                    action: { selectedModel = model3b }
                                )
                            }
                        }
                        
                        // Feature showcase section
                        ModelSection(
                            title: "App Features",
                            delay: 0.2
                        ) {
                            AppFeatureRow(
                                title: "Chat",
                                description: "Your AI buddy that never leaves your device (or judges your spelling)",
                                iconName: "message.fill"
                            )
                            
                            AppFeatureRow(
                                title: "Notes",
                                description: "Turn your thoughts into organized notes with AI assistance",
                                iconName: "doc.text.fill"
                            )

                            AppFeatureRow(
                                title: "Reminders",
                                description: "Set reminders using natural language and get things done",
                                iconName: "bell.fill"
                            )
                        }
                        
                        // Local processing emphasis section
                        ModelSection(
                            title: "100% On-Device",
                            delay: 0.3
                        ) {
                            AppFeatureRow(
                                title: "No Internet Required",
                                description: "Works in airplane mode, underwater, or in a tin foil bunker",
                                iconName: "wifi.slash"
                            )
                            
                            AppFeatureRow(
                                title: "Your Data Stays Local",
                                description: "What happens on your device, stays on your device. Vegas rules.",
                                iconName: "lock.shield"
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Install button
            NavigationLink(destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)) {
                Text("Install and Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .foregroundStyle(.white)
                    .background(Color.primary)
                    .cornerRadius(16)
            }
            .disabled(filteredModels.isEmpty && appManager.installedModels.isEmpty)
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
            .opacity(animationTrigger ? 1.0 : 0.0)
            .offset(y: animationTrigger ? 0 : 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                animationTrigger = true
            }
            checkModels()
        }
    }

    var body: some View {
        ZStack {
            if deviceSupportsMetal3 {
                modelsList
            } else {
                DeviceNotSupportedView()
            }
        }
        .onAppear {
            checkMetal3Support()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden)
    }

    var filteredModels: [ModelConfiguration] {
        ModelConfiguration.availableModels
            .filter { !appManager.installedModels.contains($0.name) }
            .sorted { $0.name < $1.name }
    }

    private func checkModels() {
        // automatically select the first available model
        if appManager.installedModels.contains(suggestedModel.name) {
            if let model = filteredModels.first {
                selectedModel = model
            }
        }
    }

    func checkMetal3Support() {
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
        #endif
    }
}

struct ModelSection<Content: View>: View {
    let title: String
    let delay: Double
    @ViewBuilder let content: Content
    @State private var appear = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 8) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: appear ? 0 : 20)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.6).delay(delay)) {
                appear = true
            }
        }
    }
}

struct ModelRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let isDisabled: Bool
    let size: String?
    var isInstalled: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            HStack {
                HStack {
                    Image(systemName: isInstalled ? "checkmark.circle.fill" : (isSelected ? "circle.fill" : "circle"))
                        .font(.system(size: 20))
                        .foregroundStyle(isInstalled ? .green : (isSelected ? .primary : .secondary))
                    
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(isDisabled ? .secondary : .primary)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if let size = size {
                    Text(size)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground).opacity(0.8))
                    .strokeBorder(isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: isSelected ? 1.5 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

struct AppFeatureRow: View {
    let title: String
    let description: String
    let iconName: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    @Previewable @State var appManager = AppManager()

    OnboardingInstallModelView(showOnboarding: .constant(true))
        .environmentObject(appManager)
}
