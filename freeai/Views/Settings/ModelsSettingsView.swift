//
//  ModelsSettingsView.swift
//  free ai
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import MLXLMCommon

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @State var showOnboardingInstallModelView = false
    var isForFreeMode: Bool = false
    
    var body: some View {
        List {
            Section {
                ForEach(appManager.installedModels, id: \.self) { modelName in
                    Button {
                        Task {
                            await switchModel(modelName)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appManager.modelDisplayName(modelName))
                                    .font(.headline)
                                
                                Text(getModelDescription(modelName))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if isForFreeMode ? 
                               (appManager.freeModeModelName == modelName) : 
                               (appManager.currentModelName == modelName) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section {
                Button {
                    showOnboardingInstallModelView.toggle()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Install another model")
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isForFreeMode ? "Free Mode Model" : "Chat Model")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showOnboardingInstallModelView) {
            NavigationStack {
                OnboardingInstallModelView(showOnboarding: $showOnboardingInstallModelView)
                    .environment(llm)
                    .toolbar {
                        #if os(iOS) || os(visionOS)
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Image(systemName: "xmark")
                            }
                        }
                        #elseif os(macOS)
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Text("close")
                            }
                        }
                        #endif
                    }
            }
        }
    }
    
    private func switchModel(_ modelName: String) async {
        if let model = ModelConfiguration.availableModels.first(where: {
            $0.name == modelName
        }) {
            if isForFreeMode {
                appManager.freeModeModelName = modelName
                appManager.playHaptic()
            } else {
                appManager.currentModelName = modelName
                appManager.playHaptic()
                await llm.switchModel(model)
            }
        }
    }
    
    private func getModelDescription(_ modelName: String) -> String {
        if let model = ModelConfiguration.availableModels.first(where: { $0.name == modelName }) {
            if let size = model.modelSize {
                return String(format: "%.1f GB", NSDecimalNumber(decimal: size).doubleValue)
            }
            return "Size unknown"
        }
        return ""
    }
}

#Preview {
    ModelsSettingsView()
}
