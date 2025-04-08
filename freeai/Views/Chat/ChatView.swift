//
//  ChatView.swift
//  free ai
//
//  Created by Jordan Singer on 12/3/24.
//

import MarkdownUI
import SwiftUI
import Speech
import SwiftData

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Namespace var bottomID
    @State var showModelPicker = false
    @State var prompt = ""
    @FocusState.Binding var isPromptFocused: Bool
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    @Binding var showFreeMode: Bool
    
    @State var thinkingTime: TimeInterval?
    
    @State private var generatingThreadID: UUID?

    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var isRecording = false

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    let platformBackgroundColor: Color = {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(visionOS)
        return Color(UIColor.separator)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }()

    // Voice dictation button with toggle state
    var micButton: some View {
        Button {
            startSpeechRecognition()
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.blue.opacity(0.1) : Color.clear)
                    .frame(width: 36, height: 36)
                
                Image(systemName: isRecording ? "waveform" : "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: isRecording ? 18 : 24, height: isRecording ? 18 : 24)
                    .foregroundColor(isRecording ? .blue : .gray)
                    .animation(.spring(duration: 0.3), value: isRecording)
            }
            .overlay(
                isRecording ? 
                Circle()
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 36, height: 36) 
                : nil
            )
        }
        .padding(.trailing, 4)
    }

    // Update the chat input to remove memory buttons and logic
    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message FREEly", text: $prompt, axis: .vertical)
                .submitLabel(.send)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    generate()
                }
                .padding(.horizontal)
            
            micButton
            
            if llm.running {
                stopButton
            } else {
                generateButton
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 8))
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    var modelPickerButton: some View {
        Button {
            appManager.playHaptic()
            showModelPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Text(String(appManager.modelDisplayName(appManager.currentModelName ?? "").prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text(appManager.modelDisplayName(appManager.currentModelName ?? ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var generateButton: some View {
        Button {
            generate()
        } label: {
            ZStack {
                Circle()
                    .fill(isPromptEmpty ? Color.gray.opacity(0.2) : Color.blue)
                    .frame(width: 32, height: 32)
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isPromptEmpty ? .gray : .white)
            }
        }
        .disabled(isPromptEmpty)
        .buttonStyle(.plain)
    }

    var stopButton: some View {
        Button {
            llm.stop()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .disabled(llm.cancelled)
        .buttonStyle(.plain)
    }

    var chatTitle: String {
        if let currentThread = currentThread {
            if let firstMessage = currentThread.sortedMessages.first {
                return firstMessage.content
            }
        }

        return "chat"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background tap area to dismiss keyboard
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: 0) {
                    // Model picker at the top
                    if appManager.userInterfaceIdiom == .phone {
                        // REMOVED: Phone top bar with model picker
                    }
                    
                    // Conversation view
                    if let currentThread = currentThread {
                        ConversationView(thread: currentThread, generatingThreadID: generatingThreadID)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(alignment: .topTrailing) {
                                if appManager.userInterfaceIdiom != .phone {
                                    HStack {
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                    } else {
                        Spacer()
                    }
                    
                    HStack {
                        chatInput
                    }
                    .padding()
                }
            }
            .navigationTitle(chatTitle)
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .sheet(isPresented: $showModelPicker) {
                    NavigationStack {
                        ModelsSettingsView()
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showModelPicker.toggle() }) {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                        #endif
                    }
                    #if os(iOS)
                    .presentationDragIndicator(.visible)
                    .if(appManager.userInterfaceIdiom == .phone) { view in
                        view.presentationDetents([.fraction(0.4)])
                    }
                    #elseif os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showModelPicker.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
                }
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    if appManager.userInterfaceIdiom == .phone {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                appManager.playHaptic()
                                showChats.toggle()
                            }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }

                    // Model picker in center
                    ToolbarItem(placement: .principal) {
                        modelPickerButton
                    }

                    // Free Mode & Settings buttons in consistent position
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            // Free Mode button
                            Button(action: {
                                appManager.playHaptic()
                                showFreeMode = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.text.square")
                                    Text("Freestyle")
                                }
                                .foregroundColor(.blue)
                            }
                            
                            // Settings button
                            Button(action: {
                                appManager.playHaptic()
                                showSettings.toggle()
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18))
                            }
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 8) {
                            Button(action: {
                                appManager.playHaptic()
                                showFreeMode = true
                            }) {
                                Label("Free Mode", systemImage: "brain.head.profile")
                            }
                            
                            Button(action: {
                                appManager.playHaptic()
                                showSettings.toggle()
                            }) {
                                Label("Settings", systemImage: "gear")
                            }
                        }
                    }
                    #endif
                }
        }
    }

    private func generate() {
        if !isPromptEmpty {
            if currentThread == nil {
                let newThread = Thread()
                currentThread = newThread
                modelContext.insert(newThread)
                try? modelContext.save()
            }

            if let currentThread = currentThread {
                generatingThreadID = currentThread.id
                Task {
                    let message = prompt
                    prompt = ""
                    appManager.playHaptic()

                    sendMessage(Message(role: .user, content: message, thread: currentThread))
                    isPromptFocused = true
                    if let modelName = appManager.currentModelName {
                        // Fetch profile (no memories)
                        let descriptor = FetchDescriptor<UserProfile>()
                        let profiles = try? modelContext.fetch(descriptor)
                        let userProfile = profiles?.first

                        // Create augmented system prompt (no memories)
                        let augmentedPrompt = appManager.createAugmentedSystemPrompt(
                            originalPrompt: appManager.systemPrompt,
                            userProfile: userProfile
                        )

                        let output = await llm.generate(
                            modelName: modelName,
                            thread: currentThread,
                            systemPrompt: augmentedPrompt
                        )

                        sendMessage(Message(role: .assistant, content: output, thread: currentThread, generatingTime: llm.thinkingTime))
                        generatingThreadID = nil
                    }
                }
            }
        }
    }

    private func sendMessage(_ message: Message) {
        appManager.playHaptic()
        modelContext.insert(message)
        try? modelContext.save()
    }

    #if os(macOS)
    private func handleShiftReturn() {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            prompt.append("\n")
            isPromptFocused = true
        } else {
            generate()
        }
    }
    #endif

    private func startSpeechRecognition() {
        // Check if already recording
        if isRecording {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isRecording = false
            return
        }
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            
            do {
                try startRecording()
                isRecording = true
                appManager.playHaptic()
            } catch {
                print("Speech recognition failed: \(error)")
            }
        }
    }

    private func startRecording() throws {
        // Cancel existing task if it exists
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        recognitionRequest?.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            var isFinal = false
            
            if let result = result {
                self.prompt = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
            }
        }
        
        // Configure audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }

    // Add this method to handle keyboard dismissal on different platforms
    private func hideKeyboard() {
        #if os(iOS) || os(visionOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #elseif os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false), showFreeMode: .constant(false))
}
