//
//  ContentView.swift
//  free ai
//
//  Created by Jordan Singer on 10/4/24.
//

import SwiftData
import SwiftUI
import MarkdownUI

// Import views
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
    @FocusState var isPromptFocused: Bool

    var body: some View {
        Group {
            if appManager.userInterfaceIdiom == .pad || appManager.userInterfaceIdiom == .mac || appManager.userInterfaceIdiom == .vision {
                // iPad
                NavigationSplitView {
                    VStack {
                        // Mode toggle buttons at the top
                        HStack {
                            Spacer()
                            
                            Button {
                                showFreeMode = false
                            } label: {
                                Text("Chat")
                                    .fontWeight(showFreeMode ? .regular : .bold)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(showFreeMode ? Color.clear : Color.blue)
                                    )
                                    .foregroundColor(showFreeMode ? .primary : .white)
                            }
                            
                            Button {
                                showFreeMode = true
                            } label: {
                                Text("Freestyle")
                                    .fontWeight(showFreeMode ? .bold : .regular)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(showFreeMode ? Color.blue : Color.clear)
                                    )
                                    .foregroundColor(showFreeMode ? .white : .primary)
                            }
                        }
                        .padding()
                        
                        // Chat list
                        ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                    }
                    #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 320)
                    #endif
                } detail: {
                    if showFreeMode {
                        FreeModeView(showChat: $showFreeMode, currentThread: $currentThread)
                    } else {
                        ChatView(currentThread: $currentThread, isPromptFocused: $isPromptFocused, showChats: $showChats, showSettings: $showSettings, showFreeMode: $showFreeMode)
                    }
                }
            } else {
                // iPhone
                if showFreeMode {
                    FreeModeView(showChat: $showFreeMode, currentThread: $currentThread)
                } else {
                    ChatView(currentThread: $currentThread, isPromptFocused: $isPromptFocused, showChats: $showChats, showSettings: $showSettings, showFreeMode: $showFreeMode)
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
        .sheet(isPresented: $showOnboarding, onDismiss: dismissOnboarding) {
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