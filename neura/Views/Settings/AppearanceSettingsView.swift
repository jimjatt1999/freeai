//
//  AppearanceSettingsView.swift
//  free ai
//
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        Form {
            #if os(iOS)
            Section {
                Picker(selection: $appManager.appTintColor) {
                    ForEach(AppTintColor.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("color", systemImage: "paintbrush.pointed")
                }
            }
            #endif

            Section(header: Text("App font")) {
                Picker(selection: $appManager.appFontDesign) {
                    ForEach(AppFontDesign.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("type", systemImage: "textformat")
                }

                Picker(selection: $appManager.appFontWidth) {
                    ForEach(AppFontWidth.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("width", systemImage: "arrow.left.and.line.vertical.and.arrow.right")
                }

                #if !os(macOS)
                Picker(selection: $appManager.appFontSize) {
                    ForEach(AppFontSize.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("size", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                #endif
            }
            
            // --- UPDATED: Chat Message Style Settings Section ---
            Section(header: Text("Chat Interface Style")) {
                Toggle("Enable Custom Terminal Style", isOn: $appManager.chatInterfaceStyleEnabled.animation())
                
                // Show terminal settings only if the master toggle is on
                if appManager.chatInterfaceStyleEnabled {
                    Group {
                        Picker("Color Scheme", selection: $appManager.terminalColorScheme) {
                            ForEach(TerminalColorScheme.allCases) { scheme in
                                Text(scheme.rawValue).tag(scheme)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        
                        // Effects
                        Toggle("Scan Lines", isOn: $appManager.terminalScanlinesEnabled)
                        Toggle("Flicker Effect", isOn: $appManager.terminalFlickerEnabled)
                        Toggle("Text Jitter", isOn: $appManager.terminalJitterEnabled)
                        Toggle("Static Noise", isOn: $appManager.terminalStaticEnabled)
                        Toggle("Bloom/Glow", isOn: $appManager.terminalBloomEnabled)
                        
                        // Window Controls
                        Toggle("Show Window Controls", isOn: $appManager.terminalWindowControlsEnabled.animation())
                        
                        if appManager.terminalWindowControlsEnabled {
                            Picker("Control Style", selection: $appManager.terminalWindowControlsStyle) {
                                ForEach(WindowControlStyle.allCases) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            // Consider using .segmented picker style if appropriate on the platform
                            // .pickerStyle(.segmented)
                        }
                    }
                    // Apply a transition to the group
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            // --- End Chat Message Style Settings ---
            
            // --- ADDED: Daily Digest Interface Style Section ---
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
                    // Toggle("Jitter Effect", isOn: $appManager.dailyDigestJitterEnabled)
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
            // --- End Daily Digest Interface Style Section ---
        }
        .formStyle(.grouped)
        .navigationTitle("aesthetics")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    AppearanceSettingsView()
}
