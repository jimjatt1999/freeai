//
//  BottomNavBar.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI

struct BottomNavBar: View {
    @EnvironmentObject var appManager: AppManager
    @Binding var showChat: Bool
    @Binding var showFreeMode: Bool
    @Binding var showFreeDump: Bool
    @Binding var showFreeBuddy: Bool
    @State private var isVisible: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Subtle divider
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)
            
            HStack(spacing: 0) {
                // Chat button
                Button {
                    showChat = true
                    showFreeMode = false
                    showFreeDump = false
                    showFreeBuddy = false
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 20))
                            .foregroundColor(showChat ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("Chat")
                            .font(.caption2)
                            .foregroundColor(showChat ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Freestyle button
                Button {
                    showChat = false
                    showFreeMode = true
                    showFreeDump = false
                    showFreeBuddy = false
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 20))
                            .foregroundColor(showFreeMode ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("Freestyle")
                            .font(.caption2)
                            .foregroundColor(showFreeMode ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // FreeDump button
                Button {
                    showChat = false
                    showFreeMode = false
                    showFreeDump = true
                    showFreeBuddy = false
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 20))
                            .foregroundColor(showFreeDump ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("FreeDump")
                            .font(.caption2)
                            .foregroundColor(showFreeDump ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // FreeBuddy button
                Button {
                    showChat = false
                    showFreeMode = false
                    showFreeDump = false
                    showFreeBuddy = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 20))
                            .foregroundColor(showFreeBuddy ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("Buddy")
                            .font(.caption2)
                            .foregroundColor(showFreeBuddy ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
            .background(
                // Translucent background with subtle blur
                Rectangle()
                    .fill(Color(.systemBackground).opacity(0.92))
                    .background(Material.thin)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}

#Preview {
    BottomNavBar(
        showChat: .constant(true),
        showFreeMode: .constant(false),
        showFreeDump: .constant(false),
        showFreeBuddy: .constant(false)
    )
    .environmentObject(AppManager())
} 