//
//  DumpInputView.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI
import SwiftData
import AVFoundation
import Speech

// --- Move TagChipView to top level --- 
struct TagChipView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .clipShape(Capsule())
    }
}
// --- End TagChipView Move ---

struct DumpInputView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.dismiss) var dismiss
    
    @State private var rawContent: String = ""
    @State private var isProcessing = false
    @State private var processingError: String? = nil
    @State private var tagInput: String = ""
    @State private var noteTags: [String] = []
    @State private var savedUserTags: [String] = []
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedColorTag: String? = nil
    private let availableColorTags: [String?] = [nil, "red", "blue", "green", "yellow", "purple"]
    @State private var selectedProcessingStyle: String = UserDefaults.standard.string(forKey: "freeDumpFormattingStyle") ?? "Save Raw"
    private let processingStyles = ["Save Raw", "Simple Restructure", "Grammar Fix", "Journal Entry", "Detailed Summary"]
    
    // Completion handler
    var onCompletion: (DumpNote?) -> Void
    
    var body: some View {
        // Calculate background color based on selection
        let currentBackgroundColor = colorForKey(selectedColorTag) ?? Color(.systemBackground)
        
            VStack(spacing: 0) {
            // --- Top Action Buttons --- 
            HStack {
                Button("Cancel") {
                    onCompletion(nil)
                    dismiss() // Dismiss directly
                }
                .padding()
                
                Spacer()
                
                Button {
                    // Call the unified save function
                    finalizeAndSaveNote()
                } label: {
                    Text("Save")
                                .font(.headline)
                }
                .padding()
                .disabled(rawContent.isEmpty || isProcessing) // Disable Save if empty or processing
            }
            .overlay(isProcessing ? ProgressView().scaleEffect(0.8) : nil) // Show progress centrally
            
            Divider()
            
            // --- Main Text Editor --- 
            TextEditor(text: $rawContent)
                .focused($isTextFieldFocused)
                .scrollContentBackground(.hidden)
                .padding()
                .frame(maxHeight: .infinity) // Expand to fill space
                .background(.clear)
            
            // --- Bottom Controls (Tags, Color, etc.) --- 
            VStack(spacing: 0) { 
                Divider()
                
                // --- Tag Display --- 
                            if !noteTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(noteTags, id: \.self) { tag in
                                TagChipView(tag: tag) { // Display added tags
                                                    noteTags.removeAll { $0 == tag }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6) // Padding for tag chips
                    }
                    .frame(height: 40) // Give scroll view a fixed height
                    Divider()
                }
                // --- End Tag Display ---
                
                // Tag Input Row (existing)
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(.secondary)
                    TextField("Add tag...", text: $tagInput)
                        .onSubmit {
                            addTag()
                        }
                    Spacer()
                    if !tagInput.isEmpty {
                        Button(action: addTag) {
                            Text("Add")
                                .font(.footnote.weight(.medium))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8) // Consistent padding
                
                // --- New Saved Tags Selection Section --- 
                if !savedUserTags.isEmpty {
                    Divider()
                    VStack(alignment: .leading) {
                        Text("Saved Tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 4)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(savedUserTags, id: \.self) { tag in
                                    Button {
                                        // Only add if not already added
                                        if !noteTags.contains(tag) {
                                            noteTags.append(tag)
                                        }
                                    } label: {
                                        HStack {
                                            Text(tag)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .lineLimit(1)
                                            
                                            if noteTags.contains(tag) {
                                                Image(systemName: "checkmark")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            } else {
                                                Image(systemName: "plus")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 40)
                    }
                    .padding(.vertical, 4)
                }
                // --- End Saved Tags Section ---
                
                // Color Picker Row (existing)
                HStack {
                    Text("Color:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                Spacer()
                
                    // Simple circular color buttons
                    ForEach(availableColorTags, id: \.self) { colorKey in
                        Button {
                            selectedColorTag = colorKey
                        } label: {
                            Circle()
                                .fill(colorForKey(colorKey) ?? Color.gray.opacity(0.2)) // Use helper
                                .frame(width: 24, height: 24)
                                .overlay(
                                    // Show checkmark if selected
                                    Circle().stroke(selectedColorTag == colorKey ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // --- Replace Toggle with Picker --- 
                Picker("AI Processing", selection: $selectedProcessingStyle) {
                    ForEach(processingStyles, id: \.self) { style in
                        Text(style).tag(style)
                    }
                }
                .pickerStyle(.menu) // Use menu style for compactness
                .padding(.horizontal)
                .padding(.vertical, 8)
                // --- End Picker ---
                
                // Error Message (existing)
                if let error = processingError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .background(Color(.systemGray6)) // Keep controls background distinct
        }
        .background(currentBackgroundColor.ignoresSafeArea()) // Apply background to main VStack
        .foregroundColor(currentBackgroundColor == Color(.systemBackground) ? .primary : .black) // Adjust foreground for contrast
            .onAppear {
                isTextFieldFocused = true
                
                // Load saved tags from UserDefaults
                if let savedTags = UserDefaults.standard.stringArray(forKey: "freeDumpUserTags") {
                    savedUserTags = savedTags
                }
        }
    }
    
    // Add tag function
    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !noteTags.contains(tag) {
            noteTags.append(tag)
            tagInput = ""
        }
    }
    
    // Renamed function: Process the content with AI and Save
    private func finalizeAndSaveNote() {
        guard !rawContent.isEmpty else { return }
        
        isProcessing = true
        processingError = nil
        
        let contentToSave = rawContent // Capture content
        let tagsToSave = noteTags // Capture tags
        let colorToSave = selectedColorTag // Capture color
        let styleToProcess = selectedProcessingStyle // Capture selected style
        
        Task {
            var finalTitle: String? = nil
            var finalStructuredContent: String? = nil
            var finalLinkURL: String? = nil
            var finalLinkTitle: String? = nil
            var finalLinkImageURL: String? = nil
            var saveError: Error? = nil

            do {
                // --- Conditionally Perform Async AI Ops --- 
                if styleToProcess != "Save Raw" { // Check selection
                    // 1. Generate Title
                    finalTitle = try await generateTitle(for: contentToSave)
                    
                    // 2. Process Content using selected style
                    finalStructuredContent = try await processWithAI(rawContent: contentToSave, style: styleToProcess)
                } else {
                    // Save Raw: Use raw content and basic title
                    finalStructuredContent = contentToSave // Or keep nil/empty?
                    finalTitle = generateBasicTitle(for: contentToSave)
                }
                
                // 3. Fetch Link Metadata (Always fetch if URL exists)
                if let detectedURL = LinkMetadataFetcher.detectURL(in: contentToSave) {
                     finalLinkURL = detectedURL.absoluteString
                     let metadata = await LinkMetadataFetcher.fetchMetadata(for: detectedURL)
                     finalLinkTitle = metadata.title
                     finalLinkImageURL = metadata.imageURL
                 }
                // --- End Async Operations ---
                
            } catch {
                print("Error during note finalization: \(error)")
                saveError = error
                // If title/processing failed, still try to fetch link for raw content
                 if finalLinkURL == nil, let detectedURL = LinkMetadataFetcher.detectURL(in: contentToSave) {
                     finalLinkURL = detectedURL.absoluteString
                     let metadata = await LinkMetadataFetcher.fetchMetadata(for: detectedURL)
                     finalLinkTitle = metadata.title
                     finalLinkImageURL = metadata.imageURL
                 }
                
                // Ensure basic title if AI fails but we wanted processing
                if styleToProcess != "Save Raw" && finalTitle == nil {
                    finalTitle = generateBasicTitle(for: contentToSave)
                }
            }

            // --- Finalize on Main Thread --- 
            await MainActor.run {
                isProcessing = false // Mark processing finished
                
                if let error = saveError, styleToProcess != "Save Raw" { // Check if AI was attempted AND failed
                    processingError = "Could not fully process note: \(error.localizedDescription)" 
                    // Save raw version if AI processing failed
                     let note = DumpNote(
                         rawContent: contentToSave,
                         structuredContent: "", // Save empty structured on error
                         title: finalTitle ?? generateBasicTitle(for: contentToSave), // Use basic title
                         tags: tagsToSave,
                         modelName: nil, // No model used if failed
                         isPinned: false,
                         colorTag: colorToSave
                     )
                     note.linkURL = finalLinkURL
                     note.linkTitle = finalLinkTitle
                     note.linkImageURL = finalLinkImageURL
                     modelContext.insert(note)
                     try? modelContext.save() // Attempt to save raw
                     onCompletion(note) // Complete with raw note
                     dismiss()

                } else { // Success or Save Raw path
                    let note = DumpNote(
                        rawContent: contentToSave,
                        // Use processed content only if processing was selected and successful
                        structuredContent: (styleToProcess != "Save Raw" && saveError == nil) ? (finalStructuredContent ?? "") : "", 
                        title: finalTitle ?? generateBasicTitle(for: contentToSave), 
                        tags: tagsToSave,
                        // Set model name only if processing occurred successfully
                        modelName: (styleToProcess != "Save Raw" && saveError == nil) ? appManager.currentModelName : nil, 
                        isPinned: false,
                        colorTag: colorToSave
                    )
                    note.linkURL = finalLinkURL
                    note.linkTitle = finalLinkTitle
                    note.linkImageURL = finalLinkImageURL
                    
                    modelContext.insert(note)
                    // Try saving the context
                    do {
                        try modelContext.save()
                        onCompletion(note) // Pass the successfully saved note back
                        dismiss() // Dismiss after successful save

                        // Award XP for saving a note
                        appManager.awardXP(points: 10, trigger: "Note Saved")
                    } catch {
                        processingError = "Failed to save note: \(error.localizedDescription)"
                        // Optionally delete the inserted note if save fails?
                        // modelContext.delete(note)
                    }
                }
            }
        }
    }
    
    // --- NEW: Generate Title Function --- 
    private func generateTitle(for rawContent: String) async throws -> String {
        guard let modelName = appManager.currentModelName else {
            throw NSError(domain: "FreeDump", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected for title generation"])
        }
        _ = try await llm.load(modelName: modelName) // Ignore result
        
        let titlePrompt = "Generate a very short, concise title (max 6 words) for the following text. Output ONLY the title, nothing else:\n\n\(rawContent)"
        
        let tempThread = Thread()
        let systemMessage = Message(role: .system, content: "You are an expert title generator.", thread: tempThread)
        let userMessage = Message(role: .user, content: titlePrompt, thread: tempThread)
        
        modelContext.insert(tempThread)
        modelContext.insert(systemMessage)
        modelContext.insert(userMessage)
        
        let titleResponse = await llm.generate(
            modelName: modelName,
            thread: tempThread,
            systemPrompt: "You are an expert title generator."
        )
        
        modelContext.delete(systemMessage)
        modelContext.delete(userMessage)
        modelContext.delete(tempThread)
        
        // Clean up the response (remove quotes, extra spaces)
        let cleanedTitle = titleResponse
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        return cleanedTitle.isEmpty ? "Untitled Note" : cleanedTitle
    }
    // --- End New Title Function --- 
    
    // Process content with AI - MODIFIED to accept style
    private func processWithAI(rawContent: String, style: String) async throws -> String { // Added style parameter
        guard let modelName = appManager.currentModelName else {
            throw NSError(domain: "FreeDump", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected for content processing"])
        }
        _ = try await llm.load(modelName: modelName) // Ignore result
        
        // Create prompt based on the selected style
        let prompt: String
        switch style {
        case "Simple":
            prompt = "Organize this text in a clean, simple way. Just improve readability but keep the original meaning and tone. DO NOT include a title:\n\n\(rawContent)" // Added DO NOT include title
        case "Grammar Fix":
            prompt = "Fix grammar, spelling, and punctuation in this text without changing its meaning or adding any formatting. DO NOT include a title:\n\n\(rawContent)" // Added DO NOT include title
        case "Journal":
            prompt = "Format this as a simple journal entry using a personal, reflective tone. No symbols or special formatting needed. DO NOT include a title:\n\n\(rawContent)" // Added DO NOT include title
        case "Detailed":
            prompt = "Create a more detailed version of this text, organizing it in a clear structure. Focus on content, not formatting. DO NOT include a title:\n\n\(rawContent)" // Added DO NOT include title
        default: // Simple
            prompt = "Organize this text in a clean, simple way. Just improve readability but keep the original meaning and tone. DO NOT include a title:\n\n\(rawContent)" // Added DO NOT include title
        }
        
        // Create a temporary thread for generation
        let tempThread = Thread()
        // Updated system prompt
        let systemMessage = Message(role: .system, content: "You are a helpful assistant that organizes text based on a specific style. Respond only with the improved text according to the user's style request. DO NOT include a title or any special markdown symbols unless the style naturally implies them.", thread: tempThread)
        let userMessage = Message(role: .user, content: prompt, thread: tempThread)
        
        modelContext.insert(tempThread)
        modelContext.insert(systemMessage)
        modelContext.insert(userMessage)
        
        // Get AI response
        let response = await llm.generate(
            modelName: modelName,
            thread: tempThread,
            // Updated system prompt
            systemPrompt: "You are a helpful assistant that organizes text based on a specific style. Respond only with the improved text according to the user's style request. DO NOT include a title or any special markdown symbols unless the style naturally implies them."
        )
        
        // Clean up temporary thread
        modelContext.delete(systemMessage)
        modelContext.delete(userMessage)
        modelContext.delete(tempThread)
        
        return response
    }
    
    // Extract tags ONLY from processed content - RENAMED
    private func extractTags(from content: String) -> (String, [String]) { // Renamed, title extraction removed
        // var title = "" // Removed title logic
        var tags: [String] = []
        
        let lines = content.split(separator: "\n")
        
        /* // Removed title extraction logic
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("# ") {
                title = String(trimmedLine.dropFirst(2))
                break
            }
        }
        */
        
        // Extract tags - safer approach
        if let tagsLine = lines.last(where: { $0.lowercased().contains("tags:") }) {
            let components = tagsLine.components(separatedBy: ":")
            if components.count > 1 {
                let tagsText = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                tags = tagsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        
        /* // Removed fallback title logic
        if title.isEmpty, let firstLine = lines.first {
            title = String(firstLine.prefix(50))
            if title.count == 50 {
                title += "..."
            }
        }
        */
        
        return ("", tags) // Return empty string for title
    }
    
    // --- NEW: Color Helper Function --- 
    private func colorForKey(_ key: String?) -> Color? {
        switch key?.lowercased() {
            case "red": return Color.red.opacity(0.6)
            case "blue": return Color.blue.opacity(0.6)
            case "green": return Color.green.opacity(0.6)
            case "yellow": return Color.yellow.opacity(0.6)
            case "purple": return Color.purple.opacity(0.6)
            default: return nil // Represents default/no color
        }
    }
    // --- End Color Helper Function ---
    
    // --- NEW: Basic Title Generation --- 
    private func generateBasicTitle(for content: String) -> String {
        let firstLine = content.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first ?? ""
        let title = String(firstLine.prefix(50))
        return title.isEmpty ? "Untitled Note" : title
    }
    // --- End Basic Title Generation ---
}

#Preview {
    DumpInputView { _ in }
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
} 

// --- NEW: Audio Input View (Separate UI) --- 
struct AudioInputView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    // State variables copied/adapted from DumpInputView
    @State private var isProcessing = false // Used for saving state
    @State private var processingError: String? = nil
    @State private var tagInput: String = ""
    @State private var noteTags: [String] = []
    @State private var selectedColorTag: String? = nil
    private let availableColorTags: [String?] = [nil, "red", "blue", "green", "yellow", "purple"]

    // Audio Recording State
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingSession = AVAudioSession.sharedInstance()
    @State private var isRecording = false
    @State private var audioFilename: String? = nil
    @State private var audioFileURL: URL?

    // Speech Recognition State
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var transcribedText: String? = nil
    @State private var showPermissionsAlert = false

    // Completion handler
    var onCompletion: (DumpNote?) -> Void

    var body: some View {
        let currentBackgroundColor = colorForKey(selectedColorTag) ?? Color(.systemGray6) // Default to gray

        VStack(spacing: 0) {
            // --- Recording Control / Display ---
            VStack {
                Spacer()
                Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(isRecording ? .red : appManager.appTintColor.getColor())
                    .padding(.bottom, 10)

                Text(isRecording ? (transcribedText ?? "Listening...") : "Tap mic to record")
                    .foregroundColor(.secondary)
                    .font(.title3)
                
                if !isRecording && audioFilename != nil {
                     Text("Recording Saved!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle()) // Make the whole area tappable
            .onTapGesture(perform: toggleRecording) // Tap anywhere to toggle

            Divider()

            // --- Bottom Controls (Tags, Color, Save) ---
            VStack(spacing: 0) {
                // Tag Display (if any)
                 if !noteTags.isEmpty {
                     ScrollView(.horizontal, showsIndicators: false) {
                         HStack(spacing: 8) {
                             ForEach(noteTags, id: \.self) { tag in
                                 // Use TagChipView (defined earlier in this file)
                                 TagChipView(tag: tag) { noteTags.removeAll { $0 == tag } }
                             }
                         }
                         .padding(.horizontal).padding(.top, 8)
                     }
                     .frame(height: 35)
                 }
                
                // Tag Input Row
                 HStack {
                     Image(systemName: "tag")
                         .foregroundColor(.secondary)
                     TextField("Add tag...", text: $tagInput)
                         .onSubmit(addTag)
                     Spacer()
                     if !tagInput.isEmpty {
                         Button(action: addTag) {
                             Text("Add")
                                 .font(.footnote.weight(.medium))
                         }
                     }
                 }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                Divider()
                 
                // Color Picker Row
                 HStack {
                     Text("Color:")
                         .font(.subheadline)
                         .foregroundColor(.secondary)
                     Spacer()
                     ForEach(availableColorTags, id: \.self) { colorKey in
                         Button {
                             selectedColorTag = colorKey
                         } label: {
                             Circle()
                                 .fill(colorForKey(colorKey) ?? Color.gray.opacity(0.2))
                                 .frame(width: 24, height: 24)
                                 .overlay(Circle().stroke(selectedColorTag == colorKey ? Color.accentColor : Color.clear, lineWidth: 2))
                         }
                     }
                 }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                Divider()
                
                // Save Button
                Button(action: saveAudioNote) {
                     Text("Save Audio Note")
                         .font(.headline)
                         .frame(maxWidth: .infinity)
                         .padding()
                         .background(appManager.appTintColor.getColor())
                         .foregroundColor(.white)
                         .cornerRadius(10)
                }
                .padding()
                .disabled(audioFilename == nil || isProcessing || isRecording) // Disable if no audio or saving/recording

                // Error Message
                if let error = processingError {
                    Text(error)
                         .font(.footnote)
                         .foregroundColor(.red)
                         .padding(.horizontal)
                }

            }
            .background(Color(.secondarySystemBackground)) // Distinct background

        }
        .background(currentBackgroundColor.ignoresSafeArea(.container, edges: .all))
         .alert("Permissions Required", isPresented: $showPermissionsAlert) {
            Button("Open Settings") {
                 if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
             }
             Button("Cancel", role: .cancel) { }
         } message: {
             Text("Microphone and Speech Recognition access are needed for audio notes. Please enable them in Settings.")
         }
         .onAppear(perform: requestPermissions) // Request on appear
         .onDisappear { // Cleanup if view disappears unexpectedly
             if isRecording {
                 stopRecording(cancel: true) // Cancel saving if view dismissed
             }
         }
    }

    // --- Helper Functions (Copied/Adapted from DumpInputView) ---
    private func saveAudioNote() {
         guard let savedFilename = audioFilename else {
             processingError = "No audio recorded."
             return
         }
         // Stop recording if somehow still active (shouldn't be if button is enabled)
         if isRecording { stopRecording(cancel: true) }
         
         isProcessing = true
         processingError = nil
         
         let note = DumpNote(
             rawContent: transcribedText ?? "", // Use transcription as raw content for searchability
             title: "Audio Note - \(formattedTimestamp())", // Auto-generate title
             tags: noteTags,
             isPinned: false,
             colorTag: selectedColorTag,
             audioFilename: savedFilename,
             transcription: transcribedText
         )
         
         modelContext.insert(note)
         do {
             try modelContext.save()
             onCompletion(note)
             dismiss()

             // Award XP for saving a note
             appManager.awardXP(points: 10, trigger: "Note Saved")
         } catch {
             print("Error saving audio note: \(error)")
             processingError = "Failed to save audio note."
             isProcessing = false
         }
    }
    
    private func formattedTimestamp() -> String {
         let formatter = DateFormatter()
         formatter.dateFormat = "yyyy-MM-dd HH:mm"
         return formatter.string(from: Date())
     }
     
    // --- Copied Helper Functions --- 
    private func requestPermissions() {
        var micPermissionGranted = false
        var speechPermissionGranted = false
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        recordingSession.requestRecordPermission { allowed in micPermissionGranted = allowed; dispatchGroup.leave() }
        dispatchGroup.enter()
        SFSpeechRecognizer.requestAuthorization { status in speechPermissionGranted = (status == .authorized); dispatchGroup.leave() }
        dispatchGroup.notify(queue: .main) {
            if micPermissionGranted && speechPermissionGranted { startRecording() } else { showPermissionsAlert = true }
        }
    }
    
    private func toggleRecording() {
        if isRecording { stopRecording() } else { requestPermissions() }
    }

    private func startRecording() {
        transcribedText = nil; audioFilename = nil
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers); try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let uniqueFilename = UUID().uuidString + ".m4a"; audioFileURL = documentPath.appendingPathComponent(uniqueFilename)
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            guard let url = audioFileURL else { return }
            audioRecorder = try AVAudioRecorder(url: url, settings: settings); audioRecorder?.record(); isRecording = true; audioFilename = uniqueFilename
            startSpeechRecognition(audioSession: audioSession)
        } catch { print("Error starting recording: \(error)"); stopRecording(cancel: true) }
    }

    // Modified stopRecording to handle cancellation
    private func stopRecording(cancel: Bool = false) {
        audioRecorder?.stop()
        if cancel, let url = audioFileURL { 
            try? FileManager.default.removeItem(at: url) // Delete file if cancelled
            audioFilename = nil // Clear filename if cancelled
            print("Recording cancelled and file deleted.")
        } else {
             print("Stopped Recording. Final transcription: \(transcribedText ?? "None")")
        }
        audioRecorder = nil; isRecording = false
        audioEngine.stop(); recognitionRequest?.endAudio(); audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startSpeechRecognition(audioSession: AVAudioSession) {
         recognitionTask?.cancel(); self.recognitionTask = nil; transcribedText = ""
         recognitionRequest = SFSpeechAudioBufferRecognitionRequest(); guard let recognitionRequest = recognitionRequest else { return }
         recognitionRequest.shouldReportPartialResults = true
         let inputNode = audioEngine.inputNode; _ = inputNode.outputFormat(forBus: 0) 
         let recordingFormat = inputNode.outputFormat(forBus: 0)
         inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in self.recognitionRequest?.append(buffer) }
         audioEngine.prepare(); try? audioEngine.start()
         recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
             var isFinal = false
             if let result = result { self.transcribedText = result.bestTranscription.formattedString; isFinal = result.isFinal }
             if error != nil || isFinal {
                 self.audioEngine.stop(); inputNode.removeTap(onBus: 0); self.recognitionRequest = nil; self.recognitionTask = nil
             }
         }
    }
    
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty, !noteTags.contains(trimmedTag) else { tagInput = ""; return }
        noteTags.append(trimmedTag); tagInput = ""
    }
    
    private func colorForKey(_ key: String?) -> Color? {
        switch key?.lowercased() {
            case "red": return Color.red.opacity(0.6)
            case "blue": return Color.blue.opacity(0.6)
            case "green": return Color.green.opacity(0.6)
            case "yellow": return Color.yellow.opacity(0.6)
            case "purple": return Color.purple.opacity(0.6)
            default: return nil
        }
    }
}

// --- Need to add color cases back to colorForKey in AudioInputView ---

// Preview for AudioInputView (Optional)
#Preview {
     AudioInputView { _ in }
         .environmentObject(AppManager())
         .environment(LLMEvaluator())
         .modelContainer(for: DumpNote.self, inMemory: true) // Add model container
} 