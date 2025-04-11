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

            // --- ADD NavigationLink to Eyes Settings --- 
             Section(header: Text("Interface Elements")) {
                 NavigationLink(destination: EyesSettingsView()) {
                     Label("Neuron", systemImage: "eyes")
                 }

                 // --- NEW: Generation Animation Picker ---
                 Picker("Generation Animation", selection: $appManager.generationAnimationStyle) {
                     ForEach(GenerationAnimationStyle.allCases) { style in
                         Text(style.rawValue).tag(style)
                     }
                 }
                 // --- END NEW ---
             }
            // --- END NavigationLink --- 
            
            Section(header: Text("font")) {
                Picker(selection: $appManager.appFontDesign) {
                    ForEach(AppFontDesign.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("design", systemImage: "textformat")
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
            Section(header: Text("Chat Message Style")) {
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
        }
        .formStyle(.grouped)
        .navigationTitle("appearance")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    AppearanceSettingsView()
}
