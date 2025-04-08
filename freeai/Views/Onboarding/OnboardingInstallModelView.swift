//
//  OnboardingInstallModelView.swift
//  free ai
//
//  Created by Jordan Singer on 10/4/24.
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
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.primary)
                    .frame(width: 80, height: 80)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .scaleEffect(animationTrigger ? 1.0 : 0.5)
                    .opacity(animationTrigger ? 1.0 : 0.0)

                VStack(spacing: 8) {
                    Text("Let's get you started")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text("Choose a model for your device")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .offset(y: animationTrigger ? 0 : 20)
                .opacity(animationTrigger ? 1.0 : 0.0)
            }
            .padding(.top, 36)
            .padding(.bottom, 20)

            // Model sections
            ScrollView {
                VStack(spacing: 20) {
                    if appManager.installedModels.count > 0 {
                        ModelSection(
                            title: "Installed",
                            delay: 0.1
                        ) {
                            ForEach(appManager.installedModels, id: \.self) { modelName in
                                let model = ModelConfiguration.getModelByName(modelName)
                                ModelRow(
                                    title: appManager.modelDisplayName(modelName),
                                    isSelected: false,
                                    isDisabled: true,
                                    size: sizeBadge(model),
                                    isInstalled: true
                                )
                            }
                        }
                    } else {
                        ModelSection(
                            title: "Free",
                            delay: 0.1
                        ) {
                            ModelRow(
                                title: "Llama 3.2 (Recommended)",
                                isSelected: selectedModel.name == suggestedModel.name,
                                isDisabled: false,
                                size: sizeBadge(suggestedModel),
                                action: { selectedModel = suggestedModel }
                            )
                        }
                    }

                    if filteredModels.count > 0 {
                        ModelSection(
                            title: "More Options",
                            delay: 0.3
                        ) {
                            ForEach(filteredModels, id: \.name) { model in
                                ModelRow(
                                    title: appManager.modelDisplayName(model.name),
                                    isSelected: selectedModel.name == model.name,
                                    isDisabled: false,
                                    size: sizeBadge(model),
                                    action: { selectedModel = model }
                                )
                            }
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
                    .frame(height: 56)
                    .foregroundStyle(.white)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            }
            .disabled(filteredModels.isEmpty && appManager.installedModels.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .opacity(animationTrigger ? 1.0 : 0.0)
            .offset(y: animationTrigger ? 0 : 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
    }

    var filteredModels: [ModelConfiguration] {
        ModelConfiguration.availableModels
            .filter { !appManager.installedModels.contains($0.name) }
            .filter { model in
                !(appManager.installedModels.isEmpty && model.name == suggestedModel.name)
            }
            .sorted { $0.name < $1.name }
    }

    func checkModels() {
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
                    
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
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

#Preview {
    @Previewable @State var appManager = AppManager()

    OnboardingInstallModelView(showOnboarding: .constant(true))
        .environmentObject(appManager)
}
