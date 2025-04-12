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
            // --- NEW: Terminal Style Section ---
            Section("Daily Digest Interface Style") {
                Toggle("Enable Interface Style", isOn: $appManager.dailyDigestTerminalStyleEnabled.animation())

                if appManager.dailyDigestTerminalStyleEnabled {
                    Picker("Color Scheme", selection: $appManager.dailyDigestColorScheme) {
                        // Filter out schemes with black backgrounds for Digest
                        ForEach(TerminalColorScheme.allCases.filter { $0 != .green && $0 != .amber && $0 != .matrix && $0 != .futuristic }) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }

                    Toggle("Scanlines", isOn: $appManager.dailyDigestScanlinesEnabled)
                    Toggle("Flicker Effect", isOn: $appManager.dailyDigestFlickerEnabled)
                    // Toggle("Jitter Effect", isOn: $appManager.dailyDigestJitterEnabled) // Keep hidden for now if not fully implemented
                    // Toggle("Static Effect", isOn: $appManager.dailyDigestStaticEnabled)
                    Toggle("Pixel Effect", isOn: $appManager.dailyDigestPixelEffectEnabled)

                    Toggle("Window Controls", isOn: $appManager.dailyDigestWindowControlsEnabled)
                    if appManager.dailyDigestWindowControlsEnabled {
                        Picker("Control Style", selection: $appManager.dailyDigestWindowControlsStyle) {
                            ForEach(WindowControlStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            // --- END NEW ---
            
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
                Text("Include a section in your digest with a brief, interesting insight or fact based on selected topics.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .fontDesign(appManager.appFontDesign.getFontDesign()) // Consistent font
    }
}

#Preview {
    NavigationStack { // Wrap in NavStack for preview
        DailyDigestSettingsView()
            .environmentObject(AppManager())
    }
}