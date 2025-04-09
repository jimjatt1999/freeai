//
//  ContentView.swift
//  free ai
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftData
import SwiftUI
import MarkdownUI

// Import views for FreeDump
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @State var showOnboarding = false
    @State var showSettings = false
    @State var showChats = false
    @State var currentThread: Thread?
    @State var showFreeMode = false
    @State var showFreeDump = false
    @State var showFreeBuddy = false
    @FocusState var isPromptFocused: Bool
    
    // Combined state for navigation
    private var showChat: Bool {
        return !showFreeMode && !showFreeDump && !showFreeBuddy
    }

    var body: some View {
        Group {
            if appManager.userInterfaceIdiom == .pad || appManager.userInterfaceIdiom == .mac || appManager.userInterfaceIdiom == .vision {
                // iPad/Mac/Vision layout
                NavigationSplitView {
                    VStack {
                        ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                    }
                    #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 320)
                    #endif
                } detail: {
                    VStack(spacing: 0) {
                        // Main content area
                        if showFreeMode {
                            FreeModeView(showChat: $showFreeMode, currentThread: $currentThread)
                        } else if showFreeDump {
                            FreeDumpView(showFreeDump: $showFreeDump, currentThread: $currentThread)
                        } else if showFreeBuddy {
                            FreeBuddyView()
                                .environmentObject(appManager)
                        } else {
                            ChatView(currentThread: $currentThread, isPromptFocused: $isPromptFocused, showChats: $showChats, showSettings: $showSettings, showFreeMode: $showFreeMode)
                        }
                        
                        // Bottom navigation
                        BottomNavBar(
                            showChat: Binding(
                                get: { !showFreeMode && !showFreeDump && !showFreeBuddy },
                                set: { if $0 { showFreeMode = false; showFreeDump = false; showFreeBuddy = false } }
                            ),
                            showFreeMode: $showFreeMode,
                            showFreeDump: $showFreeDump,
                            showFreeBuddy: $showFreeBuddy
                        )
                    }
                }
            } else {
                // iPhone layout
                ZStack(alignment: .bottom) {
                    // Main content area
                    if showFreeMode {
                        FreeModeView(showChat: $showFreeMode, currentThread: $currentThread)
                            .padding(.bottom, 50) // Add padding for the navigation bar
                    } else if showFreeDump {
                        FreeDumpView(showFreeDump: $showFreeDump, currentThread: $currentThread)
                            .padding(.bottom, 50) // Add padding for the navigation bar
                    } else if showFreeBuddy {
                        FreeBuddyView()
                            .environmentObject(appManager)
                            .padding(.bottom, 50) // Add padding for the navigation bar
                    } else {
                        ChatView(currentThread: $currentThread, isPromptFocused: $isPromptFocused, showChats: $showChats, showSettings: $showSettings, showFreeMode: $showFreeMode)
                            .padding(.bottom, 50) // Add padding for the navigation bar
                    }
                    
                    // Bottom navigation
                    VStack(spacing: 0) {
                        BottomNavBar(
                            showChat: Binding(
                                get: { !showFreeMode && !showFreeDump && !showFreeBuddy },
                                set: { if $0 { showFreeMode = false; showFreeDump = false; showFreeBuddy = false } }
                            ),
                            showFreeMode: $showFreeMode,
                            showFreeDump: $showFreeDump,
                            showFreeBuddy: $showFreeBuddy
                        )
                    }
                }
            }
        }
        .environmentObject(appManager)
        .environment(llm)
        .task {
            if appManager.installedModels.count == 0 {
                showOnboarding.toggle()
            } else {
                isPromptFocused = true
                // load the model
                if let modelName = appManager.currentModelName {
                    _ = try? await llm.load(modelName: modelName)
                }
            }
        }
        .if(appManager.userInterfaceIdiom == .phone) { view in
            view
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if !showChats && gesture.startLocation.x < 20 && gesture.translation.width > 100 {
                                appManager.playHaptic()
                                showChats = true
                            }
                        }
                )
        }
        .sheet(isPresented: $showChats) {
            ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                .environmentObject(appManager)
                .presentationDragIndicator(.hidden)
                .if(appManager.userInterfaceIdiom == .phone) { view in
                    view.presentationDetents([.medium, .large])
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(currentThread: $currentThread)
                .environmentObject(appManager)
                .environment(llm)
                .presentationDragIndicator(.hidden)
                .if(appManager.userInterfaceIdiom == .phone) { view in
                    view.presentationDetents([.medium])
                }
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: dismissOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding)
                .environment(llm)
                .interactiveDismissDisabled(appManager.installedModels.count == 0)
        }
        #if !os(visionOS)
        .tint(appManager.appTintColor.getColor())
        #endif
        .fontDesign(appManager.appFontDesign.getFontDesign())
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
        .fontWidth(appManager.appFontWidth.getFontWidth())
        .onAppear {
            appManager.incrementNumberOfVisits()
        }
    }
    
    func dismissOnboarding() {
        isPromptFocused = true
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    ContentView()
}