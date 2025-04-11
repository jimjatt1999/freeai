import SwiftUI

struct EyesSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        Form {
            // --- Show/Hide Toggle --- 
            Section(header: Text("Display")) {
                Toggle(isOn: $appManager.showAnimatedEyes) {
                    Label("Show Animated Eyes", systemImage: "eyes")
                }
                .tint(.blue)
            }
            // --- End Toggle ---
            
            // --- Eye Customization Section ---
            Section(header: Text("Appearance Customization"), footer: Text("Customize the look of the animated eyes.")) {
                // Live Preview
                HStack {
                    Spacer()
                    AnimatedEyesView()
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
            .disabled(!appManager.showAnimatedEyes) // Disable customization if eyes are off
            // --- End Eye Customization Section ---
        }
        .navigationTitle("Animated Eyes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EyesSettingsView()
            .environmentObject(AppManager()) // Add environment object for preview
    }
} 