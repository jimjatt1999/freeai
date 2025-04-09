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

// --- Chat Mode Enum ---
fileprivate enum ChatMode: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case freeDump = "FreeDump"
    case reminders = "Reminders"
    var id: String { self.rawValue }
}
// --- End Chat Mode Enum ---

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

    // --- Chat Mode State ---
    @State private var selectedMode: ChatMode = .chat
    // --- End Chat Mode State ---

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
                    .foregroundColor(isRecording ? appManager.appTintColor.getColor() : .gray) // Use tint color for recording icon
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
            // New Chat Button
                Button {
                 newChat()
                } label: {
                 Image(systemName: "plus.circle.fill")
                     .font(.title2)
                     .foregroundColor(.secondary)
             }
             .frame(width: 30, height: 30) // Fixed frame
             .padding(.leading, 4)
            
            // Mic Button OR Keyboard Dismiss
            Group { // Group to apply frame consistently
                 if isPromptFocused {
                     Button { hideKeyboard() } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
            } else {
                     micButton // micButton already includes sizing/padding logic
                 }
            }
            .frame(width: 30, height: 30) // Fixed frame for this slot
            
            // Main TextField
            TextField("freely ask anything...", text: $prompt, axis: .vertical) // Updated placeholder
                .submitLabel(.send)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
                // Give it some vertical padding within the background
                .padding(.vertical, 8)
                // Horizontal padding applied by the outer HStack padding now
                .onSubmit { generate() }
                .frame(minHeight: 36) // Ensure minimum height matches buttons
            
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
    }

    // Updated example prompts view
    var examplePromptsView: some View {
        let currentExamples = switch selectedMode {
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
                    // --- Custom Minimalist Mode Selector ---
                    HStack(spacing: 10) { // Adjust spacing as needed
                        ForEach(ChatMode.allCases) { mode in
                            Button {
                                // Only allow changing mode if conversation hasn't started
                                if currentThread == nil || currentThread?.messages.isEmpty ?? true {
                                    selectedMode = mode
                                }
                            } label: {
                                 Text(mode.rawValue)
                                     .font(.subheadline) // Use a slightly smaller font
                                     .padding(.vertical, 6)
                                     .padding(.horizontal, 12)
                                     .foregroundColor(selectedMode == mode ? Color.primary : Color.secondary)
                                     .background(selectedMode == mode ? Color.gray.opacity(0.15) : Color.clear) // Subtle background for selected
                                     .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(currentThread != nil && !(currentThread?.messages.isEmpty ?? true)) // Disable button itself
                        }
                    }
                    .fontDesign(appManager.appFontDesign.getFontDesign()) // Apply font design to the HStack
                    .padding(.horizontal) // Keep horizontal padding for the group
                    .padding(.vertical, 8)
                    // --- End Custom Minimalist Mode Selector ---
                    
                    // Model picker at the top
                    if appManager.userInterfaceIdiom == .phone {
                        // REMOVED: Phone top bar with model picker
                    }
                    
                    // --- Conversation View --- 
                    // Takes up remaining space
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
                         // Empty state when no thread exists 
                        Spacer()
                    }
                    
                     // --- Example Prompts View (Moved Above Input) --- 
                        examplePromptsView
                         .padding(.bottom, 4) // Padding above input
                         .transition(.opacity.combined(with: .move(edge: .bottom)))
                    
                     // --- Chat Input Area --- 
                    HStack {
                        chatInput
                    }
                    .padding() // Keep padding around input box
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
                    
                    // --- Mode-Specific Logic --- 
                    switch selectedMode {
                    case .chat:
                         print("Generating standard chat response...")
                    if let modelName = appManager.currentModelName {
                        // Fetch profile (no memories)
                        let descriptor = FetchDescriptor<UserProfile>()
                        let profiles = try? modelContext.fetch(descriptor)
                        let userProfile = profiles?.first

                            // Create augmented system prompt
                        let augmentedPrompt = appManager.createAugmentedSystemPrompt(
                            originalPrompt: appManager.systemPrompt,
                            userProfile: userProfile
                        )

                        let output = await llm.generate(
                            modelName: modelName,
                                 thread: currentThread, // Pass the actual thread
                            systemPrompt: augmentedPrompt
                        )
                            sendMessage(Message(role: .assistant, content: output, thread: currentThread, generatingTime: llm.thinkingTime))
                         }
                         
                    case .freeDump:
                         print("Generating response based on FreeDump...")
                         // --- Notes Logic --- 
                         // 1. Parse Query (Simple keywords for now)
                         let noteQuery = message.lowercased()
                         var notePredicate: Predicate<DumpNote>? = nil
                         // TODO: Add more sophisticated tag/date parsing
                         if noteQuery.contains("today") { 
                             let startOfToday = Calendar.current.startOfDay(for: Date())
                             notePredicate = #Predicate<DumpNote> { $0.timestamp >= startOfToday }
                         } else if noteQuery.contains("last week") {
                              let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                              notePredicate = #Predicate<DumpNote> { $0.timestamp >= oneWeekAgo }
                         } else {
                             // Basic text search (can be slow on large datasets)
                             // Consider adding specific tag search later: #Predicate { $0.tags.contains("#tag") }
                             if !noteQuery.isEmpty {
                                 notePredicate = #Predicate<DumpNote> { $0.rawContent.contains(noteQuery) || $0.title.contains(noteQuery) }
                             }
                         }
                         
                         // 2. Fetch Notes (Metadata only initially)
                         var noteDescriptor = FetchDescriptor<DumpNote>(predicate: notePredicate)
                         noteDescriptor.fetchLimit = 20 // Limit context size
                         noteDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
                         
                         let fetchedNotes = (try? modelContext.fetch(noteDescriptor)) ?? []
                         
                         // 3. Prepare Notes Context (Titles, Tags, Timestamps)
                         var notesContextString = "User\'s Notes based on query:\\n"
                         if fetchedNotes.isEmpty {
                             notesContextString += "- No relevant notes found.\\n"
                         } else {
                             let dateFormatter = DateFormatter()
                             dateFormatter.dateStyle = .short
                             for note in fetchedNotes {
                                // Simplify string construction to avoid complex interpolation issues
                                 let dateStr = dateFormatter.string(from: note.timestamp)
                                 let tagsStr = note.tags.isEmpty ? "" : " Tags: [\(note.tags.joined(separator: ", "))]"
                                 let titleStr = note.title.isEmpty ? String(note.rawContent.prefix(30)) + "..." : note.title
                                 let noteLine = "- \"\(titleStr)\" (\(dateStr))\(tagsStr)\n"
                                 notesContextString += noteLine // Append the constructed line
                             }
                         }
                         print("Notes Context:\\n\\(notesContextString)")

                         // 4. Call LLM with Notes Context
                         if let modelName = appManager.currentModelName {
                             let notesSystemPrompt = "You are discussing the user\'s notes from FreeDump. Use the provided list of note titles, dates, and tags to answer their query. Do not assume you have the full note content unless explicitly asked to retrieve it later. Keep responses concise."

                              // Revert to multi-line string construction
                             let combinedNotePrompt = """
                             \(notesSystemPrompt)

                             Context:
                             \(notesContextString)
                             User Query: \(message)
                             """ // Ensure closing quotes are on a new line
                             
                             print("Notes Combined Prompt (Multi-line):\n\(combinedNotePrompt)") // Debugging print

                             let tempNotesThread = Thread()
                             tempNotesThread.messages = [Message(role: .user, content: combinedNotePrompt)]
                             
                             let output = await llm.generate(
                                 modelName: modelName,
                                 thread: tempNotesThread,
                                 systemPrompt: "" // System prompt embedded in message
                             )
                             sendMessage(Message(role: .assistant, content: output, thread: currentThread))
                         } else {
                             sendMessage(Message(role: .assistant, content: "Error: No AI model selected.", thread: currentThread))
                         }
                         // --- End Notes Logic ---
                         
                    case .reminders:
                         print("Generating response based on reminders...")
                         // 1. Parse user query (Simple keyword check for now)
                         let query = message.lowercased()
                         var filterPredicate: Predicate<Reminder>? = nil
                         var fetchLimit = 50 // Limit fetched reminders
                         
                         if query.contains("overdue") {
                             // Fetch incomplete reminders scheduled before the start of today
                             let startOfToday = Calendar.current.startOfDay(for: Date())
                             filterPredicate = #Predicate<Reminder> { !$0.isCompleted && $0.scheduledDate != nil && $0.scheduledDate! < startOfToday }
                         } else if query.contains("today") {
                             // Fetch incomplete reminders scheduled for today
                             let startOfToday = Calendar.current.startOfDay(for: Date())
                             let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
                             filterPredicate = #Predicate<Reminder> { !$0.isCompleted && $0.scheduledDate != nil && $0.scheduledDate! >= startOfToday && $0.scheduledDate! < startOfTomorrow }
                         } else if query.contains("later") || query.contains("upcoming") {
                             // Fetch incomplete reminders scheduled after today (including someday)
                             let startOfTomorrow = Calendar.current.startOfDay(for: Date()) // Start of today to compare
                             // Fetch future dated OR nil date reminders that are not complete
                             filterPredicate = #Predicate<Reminder> { !$0.isCompleted && ($0.scheduledDate == nil || $0.scheduledDate! >= startOfTomorrow) }
                         } else if query.contains("someday") {
                             filterPredicate = #Predicate<Reminder> { !$0.isCompleted && $0.scheduledDate == nil }
                         } else if query.contains("completed") {
                             filterPredicate = #Predicate<Reminder> { $0.isCompleted }
                         } else {
                            // Default: Fetch all non-completed for general queries
                             filterPredicate = #Predicate<Reminder> { !$0.isCompleted }
                             fetchLimit = 20 // Lower limit for general queries
                         }
                         
                         // 2. Fetch relevant Reminder objects
                         var descriptor = FetchDescriptor<Reminder>(predicate: filterPredicate)
                         descriptor.fetchLimit = fetchLimit
                         // Add sorting if desired
                         descriptor.sortBy = [SortDescriptor(\Reminder.scheduledDate, order: .forward)]
                         
                         let fetchedReminders = (try? modelContext.fetch(descriptor)) ?? []
                         
                         // 3. Prepare context
                         var contextString = "User's Reminders based on query:\n"
                         if fetchedReminders.isEmpty {
                             contextString += "- No relevant reminders found.\n"
                         } else {
                             let dateFormatter = DateFormatter()
                             dateFormatter.dateStyle = .short
                             dateFormatter.timeStyle = .short
                             for reminder in fetchedReminders {
                                 let dateStr = reminder.scheduledDate != nil ? dateFormatter.string(from: reminder.scheduledDate!) : "Someday"
                                 let status = reminder.isCompleted ? "Completed" : (reminder.scheduledDate != nil && reminder.scheduledDate! < Date() ? "Overdue" : "Pending")
                                 contextString += "- \(reminder.taskDescription) (Due: \(dateStr), Status: \(status))\n"
                             }
                         }
                         print("Reminder Context:\n\(contextString)")
                         
                         // 4. Call LLM (Revised Prompting AGAIN)
                         if let modelName = appManager.currentModelName {
                             // Stricter System Prompt
                             let reminderSystemPrompt = "You are an assistant that ONLY answers questions about a list of reminders provided below. Use ONLY the information in the \'REMINDER LIST CONTEXT\' section to answer the \'USER QUERY\". Do not infer or discuss anything else. If the list doesn't contain the answer, say so clearly."
                             
                             // Revised User Message Content Format with Markers
                             let userMessageContent = """
                             [CONTEXT START]
                             REMINDER LIST CONTEXT:
                             \(contextString)
                             [CONTEXT END]
                             
                             [QUERY START]
                             USER QUERY: \(message)
                             [QUERY END]
                             """
                             
                             let tempRemindersThread = Thread()
                             tempRemindersThread.messages = [Message(role: .user, content: userMessageContent)]
                             
                             let output = await llm.generate(
                                 modelName: modelName,
                                 thread: tempRemindersThread,
                                 systemPrompt: reminderSystemPrompt 
                             )
                             sendMessage(Message(role: .assistant, content: output, thread: currentThread))
                         } else {
                             sendMessage(Message(role: .assistant, content: "Error: No AI model selected.", thread: currentThread))
                         }
                    }
                    // --- End Mode-Specific Logic ---
                    
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
         selectedMode = .chat // Optionally reset mode to default chat
         isPromptFocused = false // Dismiss keyboard if open
         // TODO: Maybe reset LLM state if needed?
         appManager.playHaptic()
         print("Started new chat.")
     }
    // --- End New Chat Helper ---
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false), showFreeMode: .constant(false))
}
