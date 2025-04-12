//
//  GamificationSettingsView.swift
//  freeai
//
//  Created by Jimi on 12/04/2025.
//


import SwiftUI

struct GamificationSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var showResetAlert = false

    var body: some View {
        Form {
            Section(header: Text("XP System"), footer: Text("Earn XP for interacting with Neura. Level up for fun! Actions like chatting, completing reminders, saving notes, and generating digests award XP.")) {
                Toggle("Enable XP System", isOn: $appManager.xpSystemEnabled.animation())
            }

            // Show UI and Reset options only if system is enabled
            if appManager.xpSystemEnabled {
                Section(header: Text("Display")) {
                    Toggle("Show Level & XP in UI", isOn: $appManager.showXpInUI.animation())
                        .disabled(!appManager.xpSystemEnabled) // Disable if system is off
                }
                
                Section(header: Text("Reset Progress")) {
                    Button("Reset XP to Zero", role: .destructive) {
                        showResetAlert = true
                    }
                    .disabled(!appManager.xpSystemEnabled) // Disable if system is off
                    .foregroundColor(.red) // Make it clear it's destructive
                }
            }
        }
        .navigationTitle("Gamification")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset XP?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                appManager.resetXP()
            }
        } message: {
            Text("Are you sure you want to reset your XP and level progress back to zero?")
        }
    }
}

#Preview {
    NavigationStack {
        GamificationSettingsView()
            .environmentObject(AppManager())
    }
}
