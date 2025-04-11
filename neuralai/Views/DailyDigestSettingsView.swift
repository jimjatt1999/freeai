//
//  DailyDigestSettingsView.swift
//  freeai
//
//  Created by Jimi on 11/04/2025.
//


import SwiftUI

struct DailyDigestSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        Form {
            // --- Included Sections ---
            Section(header: Text("Included Sections")) {
                Toggle(isOn: $appManager.dailyDigestShowCalendar) {
                    Label("Calendar Events", systemImage: "calendar")
                }
                Toggle(isOn: $appManager.dailyDigestShowReminders) {
                    Label("Reminders", systemImage: "bell")
                }
            }

            // --- Discover Section Settings ---
            Section(header: Text("Discover Feature")) {
                Toggle("Show Discover Section", isOn: $appManager.dailyDigestShowDiscover.animation())
            }

            if appManager.dailyDigestShowDiscover {
                // --- Common Topics Selection ---
                Section(header: Text("Common Topics")) {
                    // Use a grid or list for toggles
                    // Example using List:
                    ForEach(appManager.commonDiscoverTopics, id: \.self) { topic in
                        Toggle(topic, isOn: Binding(
                            get: { appManager.selectedCommonDiscoverTopics.contains(topic) },
                            set: { isOn in
                                if isOn {
                                    appManager.selectedCommonDiscoverTopics.insert(topic)
                                } else {
                                    appManager.selectedCommonDiscoverTopics.remove(topic)
                                }
                            }
                        ))
                    }
                }

                // --- Custom Topics Input ---
                Section(header: Text("Custom Topics"), footer: Text("Add your own topics, comma-separated.")) {
                    // Simple Text Field for comma-separated topics
                    VStack(alignment: .leading) {
                         TextField("e.g., mythology, cooking, economics", text: $appManager.dailyDigestDiscoverTopics)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                }
            }
        }
        .navigationTitle("Daily Digest Settings")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appManager.appFontDesign.getFontDesign()) // Consistent font
    }
}

#Preview {
    NavigationStack { // Wrap in NavStack for preview
        DailyDigestSettingsView()
            .environmentObject(AppManager())
    }
}