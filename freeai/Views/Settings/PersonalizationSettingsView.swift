//
//  PersonalizationSettingsView.swift
//  free ai
//
//  Created by Claude on 4/8/2024.
//

import SwiftUI
import SwiftData

struct PersonalizationSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    
    // Use AppStorage for state persistence
    @AppStorage("customizationEnabled") private var customizationEnabled = false
    
    @State private var userProfile: UserProfile?
    @State private var showCustomizeView = false
    
    var body: some View {
        Form {
            // Customization section
            Section(header: Text("ai PERSONALIZATION")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Customize ai", isOn: $customizationEnabled)
                        .onChange(of: customizationEnabled) { oldValue, newValue in
                            saveCustomizationState(newValue)
                            print("Customization toggle changed from \(oldValue) to \(newValue)")
                            
                            // Force save to UserDefaults to ensure persistence
                            UserDefaults.standard.set(newValue, forKey: "customizationEnabled")
                        }
                    
                    if customizationEnabled {
                        Text("Personalize how ai responds to you with custom traits and preferences")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            
                        Button {
                            showCustomizeView = true
                        } label: {
                            Text("Edit Customization")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Personalization")
        .onAppear {
            // Load user profile on appear
            loadUserProfileSync()
            printDebugInfo()
            
            // Re-sync customization state
            let storedCustomizationEnabled = UserDefaults.standard.bool(forKey: "customizationEnabled")
            
            if customizationEnabled != storedCustomizationEnabled {
                DispatchQueue.main.async {
                    self.customizationEnabled = storedCustomizationEnabled
                    print("Re-sync customization from UserDefaults: \(storedCustomizationEnabled)")
                }
            }
        }
        .onDisappear {
            // Save customization state
            UserDefaults.standard.set(customizationEnabled, forKey: "customizationEnabled")
            UserDefaults.standard.synchronize()
            print("Saving state on disappear - customization: \(customizationEnabled)")
        }
        .sheet(isPresented: $showCustomizeView) {
            CustomizeAIView(userProfile: userProfile, customizationEnabled: $customizationEnabled)
                .environment(\.modelContext, modelContext)
                .environmentObject(appManager)
        }
    }
    
    private func printDebugInfo() {
        print("====== PersonalizationSettingsView State ======")
        print("Customization enabled: \(customizationEnabled)")
        print("User profile exists: \(userProfile != nil)")
        print("============================================")
    }
    
    private func bulletPoint<Content: View>(_ content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("•")
                .foregroundColor(.secondary)
            content()
        }
    }
    
    private func saveCustomizationState(_ enabled: Bool) {
        print("Setting customization enabled to: \(enabled)")
        let descriptor = FetchDescriptor<UserProfile>()
        
        do {
            let profiles = try modelContext.fetch(descriptor)
            
            if let profile = profiles.first {
                // If disabling, clear all customizations
                if !enabled {
                    profile.updateCustomizationEnabled(enabled: false)
                    try modelContext.save()
                    print("Cleared customization settings")
                }
                self.userProfile = profile
                
                // Always update user defaults
                UserDefaults.standard.set(enabled, forKey: "customizationEnabled")
            } else {
                // Create default profile
                createDefaultProfile()
                // Set customization state in user defaults
                UserDefaults.standard.set(enabled, forKey: "customizationEnabled")
            }
            
        } catch {
            print("Error saving customization state: \(error)")
            createDefaultProfile()
            // Still set in user defaults
            UserDefaults.standard.set(enabled, forKey: "customizationEnabled")
        }
    }
    
    private func loadUserProfileSync() {
        print("Loading user profile")
        let descriptor = FetchDescriptor<UserProfile>()
        
        do {
            let profiles = try modelContext.fetch(descriptor)
            print("Found \(profiles.count) profiles")
            
            if let profile = profiles.first {
                // Load existing profile
                self.userProfile = profile
                
                // Sync customization state
                customizationEnabled = profile.hasCustomization()
                
                // --- Update AppManager --- 
                 DispatchQueue.main.async {
                    appManager.currentUserName = profile.name.isEmpty ? nil : profile.name
                 }
                 // --- End Update ---
                
                print("Final states - has customization: \(customizationEnabled)")
            } else {
                // Create default profile
                print("No profile found, creating default")
                createDefaultProfile()
                // Ensure AppManager reflects no name initially
                DispatchQueue.main.async {
                     appManager.currentUserName = nil
                }
            }
            
        } catch {
            print("Failed to load profile: \(error)")
            DispatchQueue.main.async {
                 appManager.currentUserName = nil // Clear on error too
            }
        }
    }
    
    private func createDefaultProfile() {
        print("Creating default profile")
        let profile = UserProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        self.userProfile = profile
        // Update AppManager after creating default (no name)
         DispatchQueue.main.async {
            appManager.currentUserName = nil
         }
        print("Created default profile")
    }
}

struct CustomizeAIView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var appManager: AppManager
    @State var userProfile: UserProfile?
    @Binding var customizationEnabled: Bool
    
    @State private var name = ""
    @State private var occupation = ""
    @State private var customInstructions = "You are a helpful assistant."
    @State private var interests = ""
    @State private var selectedTraits: [String] = []
    @State private var systemPrompt = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System prompt")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("This is the initial instruction that defines ai's behavior")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should ai call you?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        TextField("Name", text: $name)
                            .textContentType(.name)
                            .padding(.vertical, 8)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What do you do?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        TextField("Engineer, student, etc.", text: $occupation)
                            .padding(.vertical, 8)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("What traits should ai have?")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableTraits, id: \.self) { trait in
                                    Button {
                                        toggleTrait(trait)
                                    } label: {
                                        Text(trait)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(selectedTraits.contains(trait) 
                                                          ? Color.blue.opacity(0.1) 
                                                          : Color.gray.opacity(0.1))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(selectedTraits.contains(trait) 
                                                            ? Color.blue 
                                                            : Color.gray.opacity(0.2), 
                                                            lineWidth: 0.5)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anything else ai should know about you?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $interests)
                            .frame(minHeight: 100)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Instructions")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $customInstructions)
                            .frame(minHeight: 150)
                    }
                }
            }
            .navigationTitle("Customize ai")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        // Save the system prompt in AppManager
                        appManager.systemPrompt = systemPrompt
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                loadProfileData()
                // Load the current system prompt
                systemPrompt = appManager.systemPrompt
            }
        }
    }
    
    private var availableTraits: [String] {
        return ["Chatty", "Witty", "Straight shooting", "Encouraging", "Analytical", "Creative", "Concise"]
    }
    
    private func toggleTrait(_ trait: String) {
        if selectedTraits.contains(trait) {
            selectedTraits.removeAll { $0 == trait }
        } else {
            selectedTraits.append(trait)
        }
    }
    
    private func loadProfileData() {
        if let profile = userProfile {
            name = profile.name
            occupation = profile.occupation
            customInstructions = profile.customInstructions
            interests = profile.interests
            selectedTraits = profile.traits
            print("Loaded user profile data for customization")
        }
    }
    
    private func saveProfile() {
        if let existingProfile = userProfile {
            // Always enable customization since they're saving
            customizationEnabled = true
            
            // Update profile
            existingProfile.updateCustomizationEnabled(
                enabled: true,
                name: name,
                occupation: occupation,
                traits: selectedTraits,
                interests: interests,
                customInstructions: customInstructions
            )
            
            try? modelContext.save()
             // --- Update AppManager --- 
             DispatchQueue.main.async {
                appManager.currentUserName = name.isEmpty ? nil : name
             }
             // --- End Update ---
            print("Saved custom profile")
        } else {
            // Create new profile
            let newProfile = UserProfile(
                name: name,
                occupation: occupation,
                traits: selectedTraits,
                interests: interests,
                customInstructions: customInstructions
            )
            
            modelContext.insert(newProfile)
            try? modelContext.save()
            customizationEnabled = true
            // --- Update AppManager --- 
             DispatchQueue.main.async {
                appManager.currentUserName = name.isEmpty ? nil : name
             }
             // --- End Update ---
            print("Created new custom profile")
        }
    }
}

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
            .environmentObject(AppManager())
    }
} 
