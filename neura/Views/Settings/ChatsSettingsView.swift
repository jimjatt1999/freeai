//
//  ChatsSettingsView.swift
//  free ai
//
//

import SwiftUI

struct ChatsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    
    var body: some View {
        Form {
            Text("Chat settings moved to main Settings screen.")
                .foregroundColor(.secondary)
        }
        .formStyle(.grouped)
        .navigationTitle("chats")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    ChatsSettingsView(currentThread: .constant(nil))
}
