import SwiftUI

struct NeuraSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        Form {
            // --- Show/Hide Toggle --- 
            Section(header: Text("Display")) {
                Toggle(isOn: $appManager.showNeuraEyes) {
                    Label("Show Neura Eyes", systemImage: "eyes")
                }
                .tint(.blue)
            }
            // --- End Toggle ---
            
            // --- Eye Customization Section ---
            Section(header: Text("Appearance Customization"), footer: Text("Customize the look of the Neura.")) {
                // Live Preview
                HStack {
                    Spacer()
                    NeuraEyesView()
                        .scaleEffect(1.5)
                    Spacer()
                }
                .padding(.vertical)
                
                // Settings Pickers
                Picker("Shape", selection: $appManager.eyeShape) {
                    ForEach(EyeShapeType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                
                Picker("Outline Color", selection: $appManager.eyeOutlineColor) {
                    ForEach(AppTintColor.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                
                 Picker("Background", selection: $appManager.eyeBackgroundColor) {
                    ForEach(EyeBackgroundColorType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                
                Picker("Iris Color", selection: $appManager.eyeIrisColor) {
                    ForEach(AppTintColor.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(option.rawValue.capitalized).tag(option)
                    }
                }
                
                Picker("Iris Size", selection: $appManager.eyeIrisSize) {
                    ForEach(EyeIrisSizeType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                
                Picker("Stroke Width", selection: $appManager.eyeStrokeWidth) {
                    ForEach(EyeStrokeWidthType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                
                 Picker("Tap Action", selection: $appManager.eyeTapAction) {
                    ForEach(EyeTapActionType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                 }
                 .pickerStyle(.menu) 
            }
            .disabled(!appManager.showNeuraEyes) // Disable customization if eyes are off
            // --- End Eye Customization Section ---
        }
        .navigationTitle("Neura Eyes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NeuraSettingsView()
            .environmentObject(AppManager()) // Add environment object for preview
    }
} 