//
//  PersonalizationSettingsView.swift
//  free ai
//
//  Created by Claude on 4/8/2024.
//

import SwiftUI
import SwiftData
import EventKit

struct PersonalizationSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    private let eventStore = EKEventStore()
    
    // State properties
    @State private var customizationEnabled = false
    @State private var userProfile: UserProfile? = nil
    @State private var showCustomizeView = false
    
    // NEW: Calendar permission alert state
    @State private var showingCalendarAlert = false
    @State private var calendarAlertMessage = ""
    
    var body: some View {
        Form {
            // Name Display Section
            Section {
                VStack(alignment: .center, spacing: 6) {
                    // Static header above title
                    Text("PERSONALIZED AI")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Dynamic title with name if available
                    if let name = userProfile?.name, !name.isEmpty {
                        Text("Hello, \(name)!")
                            .font(.title)
                            .fontWeight(.medium)
                    } else {
                        Text("Hello!")
                            .font(.title)
                            .fontWeight(.medium)
                    }
                    
                    // Toggle for customization
                    Toggle("Enable Personalization", isOn: $customizationEnabled)
                        .tint(.blue)
                        .onChange(of: customizationEnabled) { _, newValue in
                            saveCustomizationState(newValue)
                        }
                        .frame(maxWidth: 230)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                // --- NEW: Customization Button ---
                Button {
                    showCustomizeView = true
                } label: {
                    Label("Customize Your AI", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!customizationEnabled)
            }
            
            // --- Personalization Info Section ---
            Section(header: Text("ABOUT PERSONALIZATION")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When you enable personalization, the AI will:")
                        .font(.callout.bold())
                    
                    bulletPoint {
                        Text("Remember your name and preferences")
                    }
                    
                    bulletPoint {
                        Text("Provide responses tailored to your interests")
                    }
                    
                    bulletPoint {
                        Text("Follow your custom instructions")
                    }
                }
                .padding(.vertical, 4)
            }
            
            // --- NEW: Integrations Section --- 
            // This section is removed since calendar access is now compulsory
            // --- END NEW --- 
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
        // --- Add Alert for Calendar Permission --- 
        .alert("Calendar Access", isPresented: $showingCalendarAlert) {
            Button("OK") { }
        } message: {
            Text(calendarAlertMessage)
        }
        // --- End Alert --- 
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
    
    // --- NEW: Calendar Permission Logic --- 
    private func requestCalendarAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .notDetermined:
            // Request access
            Task { // Use Task for async operation
                 do {
                     let granted = try await eventStore.requestFullAccessToEvents()
                     if !granted {
                         // User denied access, toggle back off on main thread
                         DispatchQueue.main.async {
                             appManager.calendarAccessEnabled = false
                             calendarAlertMessage = "Calendar access was denied. You can enable it later in the Settings app."
                             showingCalendarAlert = true
                         }
                     } else {
                         print("Calendar access granted.")
                     }
                 } catch {
                     // Handle error, toggle back off
                     print("Error requesting calendar access: \(error)")
                     DispatchQueue.main.async {
                         appManager.calendarAccessEnabled = false
                         calendarAlertMessage = "An error occurred while requesting calendar access."
                         showingCalendarAlert = true
                     }
                 }
             }
        case .restricted:
            // Access restricted, likely parental controls
            appManager.calendarAccessEnabled = false // Ensure toggle is off
            calendarAlertMessage = "Calendar access is restricted on this device."
            showingCalendarAlert = true
        case .denied:
            // User previously denied access
            appManager.calendarAccessEnabled = false // Ensure toggle is off
            calendarAlertMessage = "Calendar access was previously denied. Please enable it in the Settings app if you want to use this feature."
            showingCalendarAlert = true
        case .fullAccess, .writeOnly: // Treat writeOnly as sufficient for reading context
            // Already authorized
            print("Calendar access already authorized.")
            // Ensure toggle state matches authorization
            if !appManager.calendarAccessEnabled {
                 DispatchQueue.main.async {
                     appManager.calendarAccessEnabled = true
                 }
            }
        @unknown default:
            // Future case
            appManager.calendarAccessEnabled = false
            calendarAlertMessage = "An unknown calendar authorization status was encountered."
            showingCalendarAlert = true
        }
    }
    // --- END NEW ---
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should neura call you?")
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
                            Text("What traits should neura have?")
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
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear {
                loadProfileData()
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
