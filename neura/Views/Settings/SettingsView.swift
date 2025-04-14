//
//  SettingsView.swift
//  free ai
//
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.modelContext) private var modelContext
    @Binding var currentThread: Thread?
    @State private var deleteAllChatsAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("Aesthetics", systemImage: "paintpalette")
                    }
                    NavigationLink(destination: NeuraSettingsView()) {
                        Label("Neura Eyes", systemImage: "eyes")
                    }
                    NavigationLink(destination: PersonalizationSettingsView()) {
                        Label("Personalization", systemImage: "person.crop.circle.badge.questionmark")
                    }
                    NavigationLink(destination: ModelsSettingsView()) {
                        Label {
                            Text("Models")
                        } icon: {
                            Image(systemName: "cpu")
                        }
                        .badge(appManager.modelDisplayName(appManager.currentModelName ?? ""))
                    }
                    if appManager.userInterfaceIdiom == .phone {
                        Toggle(isOn: $appManager.shouldPlayHaptics) {
                            Label("Haptics", systemImage: "iphone.gen1.radiowaves.left.and.right")
                        }
                        .tint(.green)
                    }
                }
                
                Section("Features") {
                    NavigationLink(destination: FreeDumpSettingsView()) {
                        Label("Notes", systemImage: "note.text")
                    }
                    NavigationLink(destination: DailyDigestSettingsView()) {
                        Label("Daily Digest", systemImage: "newspaper")
                    }
                    NavigationLink(destination: GamificationSettingsView()) {
                        Label("Gamification", systemImage: "gamecontroller")
                    }
                }
                
                Section("Data Management") {
                    Button(role: .destructive) {
                        deleteAllChatsAlert = true
                    } label: {
                        Label("Delete All Chats", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

                Section {
                    NavigationLink(destination: CreditsView()) {
                        Label("Credits", systemImage: "info.circle")
                    }
                } header: {
                    Text("About")
                } footer: {
                    HStack {
                        Text("Designed & Developed by Jimi Olaoya")
                        Spacer()
                        Text("v1.0") // Simple version
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
            .alert("Delete All Chats?", isPresented: $deleteAllChatsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteChats() }
            } message: {
                Text("This will permanently delete all chat history and cannot be undone.")
            }
        }
        #if !os(visionOS)
        .tint(appManager.appTintColor.getColor())
        #endif
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
    }
    
    private func deleteChats() {
        do {
            currentThread = nil
            try modelContext.delete(model: Thread.self)
            try modelContext.delete(model: Message.self)
            print("All chats deleted.")
        } catch {
            print("Failed to delete chats: \(error)")
        }
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
