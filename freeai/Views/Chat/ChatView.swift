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

// --- Example Prompts View Definition ---
struct ExamplePromptsView: View {
    let prompts = [
        "Explain how planes fly",
        "How do vaccines work?",
        "Write a poem about the moon",
        "What is quantum computing?",
        "Give me a recipe for chocolate chip cookies"
    ]

    @Binding var prompt: String
    @Binding var isPromptFocused: FocusState<Bool>.Binding

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(prompts, id: \.self) { example in
                    Button {
                        prompt = example
                        isPromptFocused.wrappedValue = true // Focus the input field
                    } label: {
                        Text(example)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain) // Use plain style for better visual appearance
                }
            }
            .padding(.horizontal) // Add horizontal padding to the HStack
        }
        .frame(height: 35) // Give the ScrollView a fixed height
    }
}
// --- End Example Prompts View Definition ---

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

    // Add array of example prompts
    let examplePrompts = [
        "How does an airplane work?",
        "Why is the sky blue?",
        "What are black holes?",
        "How do vaccines work?",
        "Explain quantum physics simply",
        "What causes earthquakes?",
        "How do computers store data?",
        "Why do we dream?",
        "How does photosynthesis work?",
        "What makes rainbows appear?",
        "How does GPS navigation work?",
        "Why do leaves change color?",
        "How do batteries store energy?",
        "What's inside the human brain?",
        "How does the internet work?"
    ]

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

    // Update the chat input to include keyboard dismiss button aligned with mic
    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isPromptFocused {
                Button {
                    hideKeyboard()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                        .frame(width: 24, height: 24)
                }
            } else {
                micButton
            }
            
            TextField("freely ask anything", text: $prompt, axis: .vertical)
                .submitLabel(.send)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    generate()
                }
                .padding(.horizontal)
            
            if !isPromptFocused {
                // Only show mic when keyboard is not active
                Spacer().frame(width: 0)
            }
            
            if llm.running {
                stopButton
            } else {
                generateButton
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 8))
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }

    // Create an example prompts view for the scrollable prompts
    var examplePromptsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(examplePrompts, id: \.self) { examplePrompt in
                    Button {
                        prompt = examplePrompt
                        isPromptFocused = true
                    } label: {
                        Text(examplePrompt)
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                            .lineLimit(1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
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
                    
                    // Example prompts section - show only if it's a new chat (no messages yet)
                    if currentThread == nil || currentThread?.messages.isEmpty ?? true {
                        examplePromptsView
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .bottom))) // Add animation
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
                    // --- Conditional Toolbar Layout ---
                    if appManager.showAnimatedEyes {
                        // Eyes Centered, Model Picker & Chats Leading, Settings Trailing
                        ToolbarItemGroup(placement: .navigationBarLeading) {
                             if appManager.userInterfaceIdiom == .phone {
                                 Button(action: {
                                     appManager.playHaptic()
                                     showChats.toggle()
                                 }) {
                                     Image(systemName: "line.3.horizontal")
                                         .font(.system(size: 16, weight: .medium))
                                 }
                             }
                             // Keep Model picker here, maybe make it smaller/icon only?
                             modelPickerButton
                                .font(.caption) // Make picker smaller when leading
                        }
                        ToolbarItem(placement: .principal) {
                            // Eyes Centered
                            AnimatedEyesView(isGenerating: llm.running)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            // Settings Trailing
                            Button(action: {
                                appManager.playHaptic()
                                showSettings.toggle()
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18))
                            }
                        }
                    } else {
                        // No Eyes: Default Layout Restored
                        if appManager.userInterfaceIdiom == .phone {
                            ToolbarItem(placement: .navigationBarLeading) {
                                // Chats Leading
                                Button(action: {
                                    appManager.playHaptic()
                                    showChats.toggle()
                                }) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                        }
                        ToolbarItem(placement: .principal) {
                             // Model Centered
                            modelPickerButton
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                                // Settings Trailing
                                Button(action: {
                                    appManager.playHaptic()
                                    showSettings.toggle()
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 18))
                            }
                        }
                    }
                    // --- End Conditional Toolbar Layout ---
                    #elseif os(macOS)
                    // macOS Toolbar (Keep as is for now, or adjust if needed)
                    ToolbarItem(placement: .primaryAction) {
                            Button(action: {
                                appManager.playHaptic()
                                showSettings.toggle()
                            }) {
                                Label("Settings", systemImage: "gear")
                        }
                    }
                    #endif
                }
        }
    }

    private func generate() {
        if !isPromptEmpty {
            // Dismiss keyboard when sending message
            hideKeyboard()
            
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

    // Helper function to dismiss keyboard
    private func hideKeyboard() {
        isPromptFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func startRecording() throws {
        // Clear previous tasks
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
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false), showFreeMode: .constant(false))
}
