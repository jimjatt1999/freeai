//
//  BottomNavBar.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI

struct BottomNavBar: View {
    @EnvironmentObject var appManager: AppManager
    @Binding var showHome: Bool
    @Binding var showChat: Bool
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
                // Home button
                Button {
                    showHome = true
                    showChat = false
                    showFreeDump = false
                    showFreeBuddy = false
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 20))
                            .foregroundColor(showHome ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("Home")
                            .font(.caption2)
                            .foregroundColor(showHome ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Chat button
                Button {
                    showHome = false
                    showChat = true
                    showFreeDump = false
                    showFreeBuddy = false
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 20))
                            .foregroundColor(showChat ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("Chat")
                            .font(.caption2)
                            .foregroundColor(showChat ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // FreeDump button
                Button {
                    showHome = false
                    showChat = false
                    showFreeDump = true
                    showFreeBuddy = false
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundColor(showFreeDump ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(showFreeDump ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // FreeBuddy button
                Button {
                    showHome = false
                    showChat = false
                    showFreeDump = false
                    showFreeBuddy = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundColor(showFreeBuddy ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                        
                        Text("Reminders")
                            .font(.caption)
                            .foregroundColor(showFreeBuddy ? appManager.appTintColor.getColor() : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 5)
            .frame(height: 49) // Use iOS standard tab bar height
            .background(
                // Use more stable background handling
                ZStack {
                    // Base opaque background
                    Color(.systemBackground)
                    
                    // Translucent overlay
                    Rectangle()
                        .fill(Color(.systemBackground).opacity(0.95))
                        .background(Material.thin)
                }
            )
            
            // Remove the extra spacer that was pushing the tab bar down
        }
        .edgesIgnoringSafeArea(.bottom) // Make sure the bar extends to the bottom edge
        .offset(y: -8) // Move the entire tab bar up by 8 points
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}

#Preview {
    BottomNavBar(
        showHome: .constant(true),
        showChat: .constant(false),
        showFreeDump: .constant(false),
        showFreeBuddy: .constant(false)
    )
    .environmentObject(AppManager())
} 