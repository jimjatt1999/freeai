//
//  ChatView.swift
//  free ai
//
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

// --- Custom Button Style for Top Bar --- 
struct DimmingButtonStyle: ButtonStyle {
    @EnvironmentObject var appManager: AppManager
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(appManager.appTintColor.getColor()) // Use system tint color
            .opacity(configuration.isPressed ? 0.6 : 1.0) // Dim on press
            .contentShape(Rectangle()) // Ensure hit area is defined
    }
}
// --- End Custom Button Style --- 

// --- Context Type Enum (Moved from ChatView) ---
enum ChatContextType { 
    case notes, reminders, calendar, document 
}
// --- End Context Type Enum ---

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
    
    @State var thinkingTime: TimeInterval?
    
    @State private var generatingThreadID: UUID?

    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var isRecording = false
    // --- Input Cursor State ---
    @State private var inputCursorVisible = true
    let inputCursorTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    // --- End Input Cursor State ---

    // --- Context Management --- 
    @State private var showingContextSelector = false
    @State private var activeContextDescription: String? = nil // e.g., "Reminders" or "3 Notes"
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var useContextType: ChatContextType? = nil // :notes or :reminders
    // --- NEW: State for Calendar Fetch Parameters ---
    @State private var calendarFetchParams: (range: Calendar.Component, value: Int)? = nil
    // --- END NEW ---
    // --- NEW: Document Summary ---
    @State var documentSummary: String = ""
    // --- END NEW ---

    // --- Example Prompts (Updated & Renamed) ---
    let chatExamples = [
        "Explain how planes fly", "How do vaccines work?", "Write a poem about the moon"
        // ... more chat examples if needed
    ]
    let freeDumpExamples = [ // Renamed & updated examples
        "Summarize notes from today", "Find notes tagged #idea", "What did I write last week?",
        "List note titles containing 'budget'", "Show all tags used"
    ]
    let reminderExamples = [
        "What's due today?", "Show overdue reminders", "What's scheduled for tomorrow?",
        "List my completed tasks", "Any 'someday' reminders?"
    ]
    // --- End Example Prompts ---

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
            if isRecording {
                 stopSpeechRecognition()
             } else {
            startSpeechRecognition()
             }
        } label: {
            ZStack {
                Circle()
                    .fill(isRecording ? appManager.appTintColor.getColor().opacity(0.1) : Color.clear) // Use tint color for recording BG
                    .frame(width: 36, height: 36)
                
                Image(systemName: isRecording ? "waveform" : "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: isRecording ? 18 : 24, height: isRecording ? 18 : 24)
                    .foregroundColor(appManager.appTintColor.getColor())
                    .animation(.spring(duration: 0.3), value: isRecording)
            }
            .overlay(
                isRecording ? 
                Circle()
                    .stroke(appManager.appTintColor.getColor(), lineWidth: 1.5) // Use tint color for recording stroke
                    .frame(width: 36, height: 36) 
                : nil
            )
        }
        .padding(.trailing, 4)
    }

    // Updated Chat Input with Alignment Fixes
    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 6) { // Reduced spacing
            // Context Button
            Button {
                showingContextSelector = true
            } label: {
                Image(systemName: "plus.circle.fill") // Keep icon for now
                    .font(.title2)
                    .foregroundColor(appManager.appTintColor.getColor())
            }
            .frame(width: 30, height: 30) // Verified size
            .padding(.leading, 4)
            
            // Mic Button OR Keyboard Dismiss
            Group { // Group to apply frame consistently
                 if isPromptFocused {
                     Button { hideKeyboard() } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(appManager.appTintColor.getColor())
                        .font(.system(size: 18))
                }
            } else {
                     micButton // micButton already includes sizing/padding logic
                 }
            }
            .frame(width: 30, height: 30) // Verified size matches context button
            
            // Main TextField with Blinking Cursor Overlay
            ZStack(alignment: .leading) {
                TextField("freely ask anything...", text: $prompt, axis: .vertical)
                    .submitLabel(.send)
                    .focused($isPromptFocused)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 8)
                    .onSubmit { generate() }
                    .frame(minHeight: 36)
                
                // Blinking Cursor (only shows when focused and prompt is empty)
                if isPromptFocused && prompt.isEmpty && inputCursorVisible {
                    Rectangle()
                        .fill(appManager.appTintColor.getColor())
                        .frame(width: 2, height: 18) // Adjust size as needed
                        .offset(y: -1) // Adjust vertical position slightly
                        .transition(.opacity)
                        .id(UUID()) // Add ID to help with transitions
                }
            }
            // --- End TextField with Blinking Cursor ---
            
            // Send / Stop Button Slot
             Group {
                 if llm.running { stopButton } else { generateButton }
             }
             .frame(width: 32, height: 32) // Use fixed frame matching buttons inside
             .padding(.trailing, 4)

        }
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)) // Adjusted padding
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        // Add timer listener for input cursor
        .onReceive(inputCursorTimer) { _ in
             if isPromptFocused {
                 withAnimation(.easeInOut(duration: 0.1)) { // Faster blink transition
                     inputCursorVisible.toggle()
                 }
             } else {
                 inputCursorVisible = true // Ensure cursor is ready when refocused
             }
         }
    }

    // Updated example prompts view
    var examplePromptsView: some View {
        let currentExamples = switch appManager.selectedChatMode {
        case .chat: chatExamples
        case .freeDump: freeDumpExamples
        case .reminders: reminderExamples
        }
        
        // Only show examples if the list is NOT empty for the current mode
        guard !currentExamples.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                    ForEach(currentExamples, id: \.self) { examplePrompt in
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
                    // Use tint color for enabled background
                    .fill(isPromptEmpty ? Color.gray.opacity(0.2) : appManager.appTintColor.getColor())
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
                    // Keep stop red for clarity
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
                    // --- New Top Bar Area --- 
                    topBarContent // Add the new HStack here
                    // --- End New Top Bar Area ---

                    // --- Conversation View --- 
                    // Takes up remaining space
                    if let currentThread = currentThread {
                        ConversationView(thread: currentThread, generatingThreadID: generatingThreadID)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                           // Removed overlay as top elements are now inline
                    } else {
                         // Empty state when no thread exists 
                        Spacer()
                    }
                    
                     // --- Example Prompts View (Only show if no messages yet) --- 
                    if currentThread == nil || currentThread?.messages.isEmpty ?? true {
                        examplePromptsView
                           .padding(.bottom, 4) // Padding above input
                           .transition(.opacity.combined(with: .move(edge: .bottom)))
                           .id("ExamplePrompts") // Add ID for transition stability
                    }
                    
                     // --- Chat Input Area --- 
                    // Active Context Indicator (Optional)
                    if let contextDesc = activeContextDescription {
                        HStack {
                            // Context capsule with icon and text
                            HStack(spacing: 6) {
                                // Add icon based on context type
                                if let contextType = useContextType {
                                    Image(systemName: contextTypeIcon(contextType))
                                        .font(.caption)
                                }
                                
                                Text(contextDesc)
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(useContextType.map { contextColor($0) } ?? Color.gray)
                            )
                            
                            Button {
                                // Clear all context state variables and provide feedback
                                print("X button pressed on context: \(contextDesc), type: \(String(describing: useContextType)), calendar: \(String(describing: calendarFetchParams))")
                                clearContextState()
                                appManager.playHaptic() // Add haptic feedback
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.gray.opacity(0.3)))
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 2) // Small spacing before input
                        .onAppear {
                            // Debug: Log context state when indicator appears
                            print("Context indicator appeared: \(contextDesc), type: \(String(describing: useContextType)), calendar: \(String(describing: calendarFetchParams))")
                        }
                    }
                    
                    HStack {
                        chatInput
                    }
                    .padding() // Keep padding around input box
                }
            }
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
            .sheet(isPresented: $showingContextSelector) {
                ContextSelectorView(
                    activeContextDescription: $activeContextDescription,
                    selectedNoteIDs: $selectedNoteIDs,
                    useContextType: $useContextType,
                    calendarFetchParams: $calendarFetchParams,
                    documentSummaryBinding: $documentSummary
                )
                .environmentObject(appManager) // Pass environment objects
                .environment(llm) // Pass LLM for document processing
            }
        }
    }

    // --- New Top Bar Content View --- 
    @ViewBuilder
    private var topBarContent: some View {
        ZStack {
            // Left and right side buttons in an HStack
            HStack {
                // --- Left Side --- 
                if appManager.userInterfaceIdiom == .phone {
                     Button(action: {
                         appManager.playHaptic()
                         showChats.toggle()
                     }) {
                         // Add padding around the image
                         Image(systemName: "line.3.horizontal")
                             .font(.system(size: 18, weight: .medium))
                             .padding(8) // Increase tap area
                     }
                     .buttonStyle(DimmingButtonStyle())
                }
                
                Spacer()
                
                // --- Right Side --- 
                HStack(spacing: 16) {
                    // New Chat button
                     Button { newChat() } label: {
                         // Add padding around the image
                         Image(systemName: "square.and.pencil")
                             .font(.system(size: 18))
                             .padding(8) // Increase tap area
                     }
                     .buttonStyle(DimmingButtonStyle())
                     
                     // Settings Trailing
                     Button(action: {
                         appManager.playHaptic()
                         showSettings.toggle()
                     }) {
                         // Add padding around the image
                         Image(systemName: "gearshape")
                             .font(.system(size: 18))
                             .padding(8) // Increase tap area
                     }
                     .buttonStyle(DimmingButtonStyle())
                }
            }
            
            // Centered eyes or model picker
            if appManager.showNeuraEyes {
                Button { 
                    showModelPicker.toggle()
                    appManager.playHaptic()
                } label: {
                    NeuraEyesView(
                        isGenerating: llm.running,
                        isThinking: generatingThreadID != nil,
                        isListening: isRecording
                    )
                }
                .buttonStyle(DimmingButtonStyle())
            } else {
                 modelPickerButton
            }
        }
        .padding(.horizontal) // Keep outer padding
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(height: 50) // Slightly increased height to accommodate padding
    }

    // --- Context Selection Sheet --- 
    @ViewBuilder
    private func contextSelectorSheet() -> some View {
        // Placeholder - build ContextSelectorView next
        NavigationStack {
            VStack {
                Text("Select Context")
                    .font(.title2)
                Spacer()
                Text("TODO: Build Note/Reminder Selection UI")
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingContextSelector = false }
                }
            }
        }
    }
    // --- End Context Selection Sheet ---

    private func generate() {
        if !isPromptEmpty {
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

                    // --- Context Prep --- 
                    var contextString = ""
                    // Use the default system prompt, it might be overridden by context
                    var systemPrompt = "you are a helpful assistant" 

                    if let contextType = useContextType {
                        switch contextType {
                        case .reminders:
                            print("Preparing Reminder Context...")
                            // Fetch reminders (using logic similar to the old .reminders case)
                            // Basic fetch for now - could be refined based on `message` keywords later if needed
                            let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { !$0.isCompleted }, 
                                                                   sortBy: [SortDescriptor(\.scheduledDate, order: .forward)])
                            let fetchedReminders = (try? modelContext.fetch(descriptor)) ?? []

                            if !fetchedReminders.isEmpty {
                                contextString += "CONTEXT: The user has provided the following relevant reminders:\n"
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateStyle = .short
                                dateFormatter.timeStyle = .short
                                for reminder in fetchedReminders {
                                    let dateStr = reminder.scheduledDate != nil ? dateFormatter.string(from: reminder.scheduledDate!) : "Someday"
                                    let status = reminder.isCompleted ? "Completed" : (reminder.scheduledDate != nil && reminder.scheduledDate! < Date() ? "Overdue" : "Pending")
                                    contextString += "- \(reminder.taskDescription) (Due: \(dateStr), Status: \(status))\n"
                                }
                                // Update system prompt for reminder context
                                systemPrompt = "You are an assistant discussing the user's reminders. Use the provided context to answer the user's query. Base prompt: \(systemPrompt)"
                            }
                            
                        case .notes:
                            if !selectedNoteIDs.isEmpty {
                                print("Preparing Note Context for IDs: \(selectedNoteIDs)")
                                // Fetch *only* the selected notes by ID
                                let selectedIDs = selectedNoteIDs // Capture for predicate
                                let descriptor = FetchDescriptor<DumpNote>(predicate: #Predicate { selectedIDs.contains($0.id) },
                                                                     sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                                let selectedNotes = (try? modelContext.fetch(descriptor)) ?? []

                                if !selectedNotes.isEmpty {
                                    contextString += "CONTEXT: The user has provided the following selected notes:\n"
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateStyle = .short
                                    for note in selectedNotes {
                                        let dateStr = dateFormatter.string(from: note.timestamp)
                                        let tagsStr = note.tags.isEmpty ? "" : " Tags: [\(note.tags.joined(separator: ", "))]"
                                        let titlePrefix = note.title.isEmpty ? "Note Content:" : "Title: \"\(note.title)\" Content:"
                                        contextString += "- \(titlePrefix) \(note.rawContent) (Created: \(dateStr))\(tagsStr)\n\n"
                                    }
                                    // Update system prompt for notes context
                                    systemPrompt = "You are an assistant discussing specific notes provided by the user. Use the provided context to answer the user's query. Base prompt: \(systemPrompt)"
                                }
                            } else if !documentSummary.isEmpty {
                                // Handle document context (uploaded file)
                                print("Using document summary as context")
                                contextString += "CONTEXT: The user has provided the following document for context:\n\n"
                                contextString += documentSummary
                                // Update system prompt for document context
                                systemPrompt = "You are an assistant discussing a document uploaded by the user. Use the provided document summary to answer the user's query. Base prompt: \(systemPrompt)"
                            }
                        
                        // --- Add Calendar Case --- 
                        case .calendar:
                            print("Preparing Calendar Context... Parameters: \(String(describing: calendarFetchParams))")
                            // Fetch calendar events using selected parameters
                            let params = calendarFetchParams ?? (.month, 1) // Default if nil
                            let calendarContext = await appManager.fetchCalendarEvents(for: params.range, value: params.value)
                            // The fetchCalendarEvents method now handles permission requests internally
                            if !calendarContext.isEmpty {
                                contextString += "CONTEXT: The user has provided the following calendar context:\n"
                                contextString += calendarContext // Append fetched events
                                // Update system prompt for calendar context
                                systemPrompt = "You are an assistant discussing the user's schedule. Use the provided calendar context to answer the user's query. Base prompt: \(systemPrompt)"
                                print("Successfully added calendar context of length: \(calendarContext.count)")
                            } else {
                                print("Calendar context was empty - using calendar access was not successful")
                            }
                        // --- End Calendar Case ---
                        
                        // --- Document Context Case ---
                        case .document:
                            if !documentSummary.isEmpty {
                                print("Using document context")
                                contextString += "CONTEXT: The user has provided the following document for context:\n\n"
                                contextString += documentSummary
                                // Update system prompt for document context
                                systemPrompt = "You are an assistant discussing a document uploaded by the user. Use the provided document summary to answer the user's query. Base prompt: \(systemPrompt)"
                            } else {
                                print("Document summary was empty - no document context available")
                            }
                        // --- End Document Context Case ---
                        }
                        contextString += "\nUSER QUERY: " // Separator before the actual user message
                        print("Context String Prepared:\n\(contextString)")
                    }

                    // Prepend context to the message
                    let finalMessageContent = contextString + message
                    sendMessage(Message(role: .user, content: finalMessageContent, thread: currentThread))

                    // --- LLM Call --- 
                    if let modelName = appManager.currentModelName {
                        // Fetch profile (if no specific context was added, use profile)
                        let descriptor = FetchDescriptor<UserProfile>()
                        let profiles = try? modelContext.fetch(descriptor)
                        let userProfile = profiles?.first

                        // Use augmented prompt ONLY if no specific context was added
                        let finalSystemPrompt = (useContextType == nil && userProfile != nil) ? 
                            appManager.createAugmentedSystemPrompt(originalPrompt: systemPrompt, userProfile: userProfile) : 
                            systemPrompt

                        // Generate response using the current thread
                        let output = await llm.generate(
                            modelName: modelName,
                            thread: currentThread, // Pass the actual thread
                            systemPrompt: finalSystemPrompt
                        )
                        sendMessage(Message(role: .assistant, content: output, thread: currentThread, generatingTime: llm.thinkingTime))
                        appManager.awardXP(points: 5, trigger: "Chat Response") // Increased to 5 XP
                    } else {
                        sendMessage(Message(role: .assistant, content: "Error: No AI model selected.", thread: currentThread))
                    }

                    // --- Reset Context State --- 
                    clearContextState() // Use the helper function for consistency
                    // --- End Reset ---
                    
                    generatingThreadID = nil
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

    // --- Add stopSpeechRecognition Function ---
    private func stopSpeechRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        print("Stopped recording via button")
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    // --- End stopSpeechRecognition Function ---

    // --- New Chat Helper --- 
    private func newChat() {
         currentThread = nil // Clear the current thread
         prompt = "" // Clear any text in the input field
         appManager.selectedChatMode = .chat // Reset global mode to default chat
         isPromptFocused = false // Dismiss keyboard if open
         // TODO: Maybe reset LLM state if needed?
         appManager.playHaptic()
         print("Started new chat.")
     }
    // --- End New Chat Helper ---

    // --- Context State Management --- 
    private func clearContextState() {
        // Clear all context-related state
        print("Clearing context state - Before: type=\(String(describing: useContextType)), calendar=\(String(describing: calendarFetchParams)), document=\(documentSummary.isEmpty ? "empty" : "exists")")
        
        // First reset calendar params to ensure they're cleared
        calendarFetchParams = nil
        
        // Clear document summary
        documentSummary = ""
        
        // Then clear the rest
        activeContextDescription = nil
        selectedNoteIDs = []
        useContextType = nil
        
        print("Context state cleared - After: type=\(String(describing: useContextType)), calendar=\(String(describing: calendarFetchParams)), document=\(documentSummary.isEmpty ? "empty" : "exists")")
    }

    // Return appropriate icon for each context type
    private func contextTypeIcon(_ type: ChatContextType) -> String {
        switch type {
        case .notes:
            return "note.text"
        case .reminders:
            return "checklist"
        case .calendar:
            return "calendar"
        case .document:
            return "doc.text"
        }
    }

    // Return appropriate color for each context type
    private func contextColor(_ type: ChatContextType) -> Color {
        switch type {
        case .notes:
            return Color.blue
        case .reminders:
            return Color.orange
        case .calendar:
            return Color.purple
        case .document:
            return Color.green
        }
    }
    // --- End Context State Management ---
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false))
}
