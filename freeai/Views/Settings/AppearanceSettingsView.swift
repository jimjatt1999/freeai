//
//  AppearanceSettingsView.swift
//  free ai
//
//  Created by Jordan Singer on 10/5/24.
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
                     Label("Animated Eyes", systemImage: "eyes")
                 }
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
            
            Section(header: Text("chat interface design")) {
                Picker("Style", selection: $appManager.chatAnimationStyle) {
                    Text("None").tag("none")
                    Text("Fade In").tag("fade")
                    Text("Bounce").tag("bounce")
                    Text("Typewriter").tag("typewriter")
                    Text("Terminal").tag("terminal")
                    Text("Minimalist").tag("minimalist")
                    Text("Retro").tag("retro")
                    Text("Futuristic").tag("futuristic")
                    Text("Handwritten").tag("handwritten")
                    Text("Comic").tag("comic")
                }
                .pickerStyle(.navigationLink)
                
                Text("Animation styles (Fade, Bounce, Typewriter) enhance the streaming effect of chat responses.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
