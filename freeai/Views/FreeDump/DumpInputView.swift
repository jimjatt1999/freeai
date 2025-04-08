//
//  DumpInputView.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI
import SwiftData

struct DumpInputView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.dismiss) var dismiss
    
    @State private var rawContent: String = ""
    @State private var isProcessing = false
    @State private var processingError: String? = nil
    @State private var selectedStyle: String = "Simple"
    @State private var tagInput: String = ""
    @State private var noteTags: [String] = []
    @State private var showDictation = false
    @FocusState private var isTextFieldFocused: Bool
    
    // Available formatting styles - same as in settings
    private let formattingStyles = [
        "Simple": "Basic restructuring with simple formatting",
        "Grammar Fix": "Focus on correcting grammar and spelling",
        "Detailed": "Comprehensive organization with detailed sections",
        "Journal": "Format as a reflective journal entry"
    ]
    
    // Completion handler
    var onCompletion: (DumpNote?) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Text input - now significantly larger
                ZStack(alignment: .topLeading) {
                    if rawContent.isEmpty {
                        Text("Just start typing anything... AI will help organize your thoughts.")
                            .foregroundColor(.secondary)
                            .font(.body)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $rawContent)
                        .font(.body)
                        .padding(16)
                        .focused($isTextFieldFocused)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemBackground))
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.4) // Much bigger text space
                
                // Options section in a collapsible disclosure group
                DisclosureGroup("Options") {
                    VStack(alignment: .leading, spacing: 16) {
                        // Processing style picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Processing Style")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Picker("Style", selection: $selectedStyle) {
                                ForEach(Array(formattingStyles.keys).sorted(), id: \.self) { style in
                                    Text(style).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 4)
                            
                            // Style description
                            if let description = formattingStyles[selectedStyle] {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Tags input and display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                TextField("Add tag...", text: $tagInput)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .onSubmit {
                                        addTag()
                                    }
                                
                                Button(action: addTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20))
                                }
                            }
                            
                            // Display tags
                            if !noteTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(noteTags, id: \.self) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag)
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                
                                                Button(action: {
                                                    noteTags.removeAll { $0 == tag }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.subheadline)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(8)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        // Error message (if any)
                        if let error = processingError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Main process button
                        Button {
                            processContent()
                        } label: {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 5)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 16))
                                        .padding(.trailing, 5)
                                }
                                
                                Text(isProcessing ? "Processing..." : "Process with AI")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(rawContent.isEmpty || isProcessing ? Color.blue.opacity(0.5) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(rawContent.isEmpty || isProcessing)
                        
                        // Dictation button
                        #if os(iOS)
                        Button {
                            showDictation = true
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20))
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.blue))
                                .foregroundColor(.white)
                        }
                        #endif
                    }
                    
                    Button {
                        saveRawNote()
                    } label: {
                        Text("Save Without Processing")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .disabled(rawContent.isEmpty)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Mind Dump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCompletion(nil)
                    }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showDictation) {
                DictationView { dictatedText in
                    if !dictatedText.isEmpty {
                        if rawContent.isEmpty {
                            rawContent = dictatedText
                        } else {
                            rawContent += "\n\n" + dictatedText
                        }
                    }
                    showDictation = false
                }
            }
            #endif
            .onAppear {
                // Focus the text field when view appears
                isTextFieldFocused = true
                // Load saved formatting style
                selectedStyle = UserDefaults.standard.string(forKey: "freeDumpFormattingStyle") ?? "Simple"
            }
            .onChange(of: selectedStyle) { _, newValue in
                // Save the selected style
                UserDefaults.standard.set(newValue, forKey: "freeDumpFormattingStyle")
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
    
    // Process the content with AI
    private func processContent() {
        guard !rawContent.isEmpty else { return }
        
        isProcessing = true
        processingError = nil
        
        Task {
            do {
                // Create a note with raw content
                let note = DumpNote(rawContent: rawContent)
                note.isProcessing = true
                note.tags = noteTags // Add the user's manual tags
                
                // Return the note immediately so user can see it in the list
                DispatchQueue.main.async {
                    onCompletion(note)
                }
                
                // Process the content
                let structuredContent = try await processWithAI(rawContent: rawContent)
                
                // Extract title (we'll keep the user-provided tags)
                let (title, autoTags) = extractTitleAndTags(from: structuredContent)
                
                // Merge auto-generated tags with user tags, removing duplicates
                var combinedTags = noteTags
                for tag in autoTags {
                    if !noteTags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                        combinedTags.append(tag)
                    }
                }
                
                // Update the note with processed content
                DispatchQueue.main.async {
                    note.structuredContent = structuredContent
                    note.title = title
                    note.tags = combinedTags
                    note.modelName = appManager.currentModelName
                    note.isProcessing = false
                }
            } catch {
                // Show error, but still save raw content
                DispatchQueue.main.async {
                    processingError = "Could not process content: \(error.localizedDescription)"
                    isProcessing = false
                    saveRawNote()
                }
            }
        }
    }
    
    // Save note without AI processing
    private func saveRawNote() {
        let note = DumpNote(rawContent: rawContent)
        
        // Extract a simple title from the first line
        let lines = rawContent.split(separator: "\n", maxSplits: 1)
        if let firstLine = lines.first, !firstLine.isEmpty {
            let title = String(firstLine)
            note.title = title.count > 50 ? String(title.prefix(50)) + "..." : title
        }
        
        // Add tags
        note.tags = noteTags
        
        onCompletion(note)
    }
    
    // Process content with AI - simplified
    private func processWithAI(rawContent: String) async throws -> String {
        // Ensure LLM is loaded
        guard let modelName = appManager.currentModelName ?? appManager.freeModeModelName else {
            throw NSError(domain: "FreeDump", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected"])
        }
        
        // Make sure the model is loaded - simplified check
        try await llm.load(modelName: modelName)
        
        // Create prompt based on the selected style - much simpler now
        let prompt: String
        
        switch selectedStyle {
        case "Simple":
            prompt = "Organize this text in a clean, simple way. Just improve readability but keep the original meaning and tone:\n\n\(rawContent)"
        case "Grammar Fix":
            prompt = "Fix grammar, spelling, and punctuation in this text without changing its meaning or adding any formatting:\n\n\(rawContent)"
        case "Journal":
            prompt = "Format this as a simple journal entry using a personal, reflective tone. No symbols or special formatting needed:\n\n\(rawContent)"
        case "Detailed":
            prompt = "Create a more detailed version of this text, organizing it in a clear structure. Focus on content, not formatting:\n\n\(rawContent)"
        default: // Simple
            prompt = "Organize this text in a clean, simple way. Just improve readability but keep the original meaning and tone:\n\n\(rawContent)"
        }
        
        // Create a temporary thread for generation
        let tempThread = Thread()
        let systemMessage = Message(role: .system, content: "You are a helpful assistant that organizes text. Respond only with the improved text without adding any special markdown symbols, asterisks, or section markers.", thread: tempThread)
        let userMessage = Message(role: .user, content: prompt, thread: tempThread)
        
        modelContext.insert(tempThread)
        modelContext.insert(systemMessage)
        modelContext.insert(userMessage)
        
        // Get AI response using generate instead of evaluate
        let response = await llm.generate(
            modelName: modelName,
            thread: tempThread,
            systemPrompt: "You are a helpful assistant that organizes text. Respond only with the improved text without adding any special markdown symbols, asterisks, or section markers."
        )
        
        // Clean up temporary thread
        modelContext.delete(systemMessage)
        modelContext.delete(userMessage)
        modelContext.delete(tempThread)
        
        return response
    }
    
    // Extract title and tags from processed content
    private func extractTitleAndTags(from content: String) -> (String, [String]) {
        var title = ""
        var tags: [String] = []
        
        // Extract title from first heading
        let lines = content.split(separator: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("# ") {
                title = String(trimmedLine.dropFirst(2))
                break
            }
        }
        
        // Extract tags - safer approach
        if let tagsLine = lines.last(where: { $0.lowercased().contains("tags:") }) {
            let components = tagsLine.components(separatedBy: ":")
            if components.count > 1 {
                let tagsText = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                tags = tagsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        
        // If no title found, create one from the first sentence
        if title.isEmpty, let firstLine = lines.first {
            title = String(firstLine.prefix(50))
            if title.count == 50 {
                title += "..."
            }
        }
        
        return (title, tags)
    }
}

#Preview {
    DumpInputView { _ in }
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
} 