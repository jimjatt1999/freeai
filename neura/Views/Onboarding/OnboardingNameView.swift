//
//  OnboardingNameView.swift
//  free ai
//
// Created by ZECRO on X/XX/XXXX.
//

import SwiftUI
import SwiftData

struct OnboardingNameView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @Binding var showOnboarding: Bool
    @State private var userName: String = ""
    @State private var navigateToModelInstall = false
    @State private var userProfile: UserProfile? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Add NeuraEyesView here
            NeuraEyesView()
                .scaleEffect(1.5) // Match scale from previous screen
                .padding(.bottom, 15)

            Text("What should Neura call you?")
                .font(.system(.title, design: .monospaced))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)


            Text("Personalizing helps Neura assist you better, especially with features like Daily Digest. You can change this and customize more in Settings later.")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .fixedSize(horizontal: false, vertical: true)


            TextField("Your Name (Optional)", text: $userName)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .textContentType(.name)
                .padding(.horizontal, 50)


            Spacer()
            Spacer()


            NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding), isActive: $navigateToModelInstall) { EmptyView() }

            Button {
                saveAndContinue()
            } label: {
                Text("Continue")
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(Color(.systemBackground))
                    .background(appManager.appTintColor.getColor())
                    .cornerRadius(12)
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 30) // Add some bottom padding
        }
        .padding()
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarBackButtonHidden(true) // Hide default back button
        .toolbar {
             ToolbarItem(placement: .navigationBarLeading) {
                 Button {
                     dismiss() // Use dismiss to go back to previous onboarding screen
                 } label: {
                     Image(systemName: "chevron.left")
                 }
             }
        }
        .onAppear(perform: loadUserProfile)
    }

    func loadUserProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        do {
            let profiles = try modelContext.fetch(descriptor)
            if let profile = profiles.first {
                userProfile = profile
                 // Pre-fill if name already exists? Maybe not for onboarding.
                // userName = profile.name
            } else {
                // No profile exists yet
                userProfile = nil
            }
        } catch {
            print("Error fetching user profile: \(error)")
            userProfile = nil
        }
    }

    func saveAndContinue() {
        // Enable personalization
        UserDefaults.standard.set(true, forKey: "customizationEnabled")

        if let profile = userProfile {
            // Update existing profile
            profile.name = userName
            // Ensure customization flag is set correctly
            profile.updateCustomizationEnabled(enabled: true, name: userName, occupation: profile.occupation, traits: profile.traits, interests: profile.interests, customInstructions: profile.customInstructions)
            try? modelContext.save()
             print("Updated existing profile with name: \(userName)")
        } else {
            // Create new profile
            let newProfile = UserProfile(name: userName)
            // Enable customization implicitly
            newProfile.updateCustomizationEnabled(enabled: true, name: userName)
            modelContext.insert(newProfile)
            try? modelContext.save()
            print("Created new profile with name: \(userName)")
        }

        // Update AppManager
        appManager.currentUserName = userName.isEmpty ? nil : userName

        // Navigate
        navigateToModelInstall = true
    }
}

#Preview {
    // Need a temporary model container for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)

    // Create a dummy profile for preview if needed
    // let sampleProfile = UserProfile(name: "Preview")
    // container.mainContext.insert(sampleProfile)

    return NavigationStack { // Wrap in NavigationStack for preview toolbar
         OnboardingNameView(showOnboarding: .constant(true))
             .modelContainer(container)
             .environmentObject(AppManager()) // Add AppManager
     }
} 