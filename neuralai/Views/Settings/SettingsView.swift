//
//  SettingsView.swift
//  free ai
//
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Binding var currentThread: Thread?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("appearance", systemImage: "paintpalette")
                    }

                    NavigationLink(destination: ChatsSettingsView(currentThread: $currentThread)) {
                        Label("chats", systemImage: "message")
                    }
                    
                    NavigationLink(destination: ModelsSettingsView()) {
                        Label {
                            Text("models")
                                .fixedSize()
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                        }
                        .badge(appManager.modelDisplayName(appManager.currentModelName ?? ""))
                    }
                    
                    NavigationLink(destination: PersonalizationSettingsView()) {
                        Label("personalization", systemImage: "person.crop.circle.badge.questionmark")
                    }
                    
                    NavigationLink(destination: DailyDigestSettingsView()) {
                        Label("daily digest", systemImage: "newspaper")
                    }
                    
                    NavigationLink(destination: GamificationSettingsView()) {
                        Label("gamification", systemImage: "gamecontroller")
                    }
                }

                Section {
                    NavigationLink(destination: CreditsView()) {
                        Text("credits")
                    }
                }
                
                // Add "Made by" section at the bottom with version number
                Section {
                    HStack {
                        Text("Made by Jimi Olaoya")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("v\(Bundle.main.releaseVersionNumber ?? "1.0").\(Bundle.main.buildVersionNumber ?? "0")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .destructiveAction) {
                        Button(action: { dismiss() }) {
                            Text("close")
                        }
                    }
                    #endif
                }
        }
        #if !os(visionOS)
        .tint(appManager.appTintColor.getColor())
        #endif
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

#Preview {
    SettingsView(currentThread: .constant(nil))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
