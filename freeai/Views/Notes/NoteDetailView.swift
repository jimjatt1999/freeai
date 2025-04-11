//
//  DumpDetailView.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI
import SwiftData
import MarkdownUI

struct DumpDetailView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.colorScheme) var colorScheme
    
    var note: DumpNote
    
    @State private var isEditing = false
    @State private var editedRawContent: String = ""
    @State private var editedTitle: String = ""
    @State private var editedStructuredContent: String = ""
    @State private var isProcessing = false
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var streamedContent: String = ""
    @State private var animationProgress: CGFloat = 0
    @State private var showDictation = false
    @State private var selectedStyle: String = UserDefaults.standard.string(forKey: "selectedProcessingStyle") ?? "Simple"
    @State private var editMode: EditMode = .structured
    @State private var processingError: String? = nil
    
    // --- NEW: Color Tag State for Editing ---
    @State private var editedColorTag: String? = nil // Store the selected color key
    private let availableColorTags: [String?] = [nil, "red", "blue", "green", "yellow", "purple"] // Keep consistent
    // --- End Color Tag State ---
    
    // --- NEW: Tag Editing State ---
    @State private var editedTags: [String] = []
    @State private var tagInput: String = ""
    @State private var savedUserTags: [String] = []
    // --- End Tag Editing State ---
    
    // Edit mode enum
    enum EditMode {
        case raw
        case structured
    }
    
    var body: some View {
        NavigationStack {
            if isEditing {
                editingView
            } else {
                noteView
            }
        }
        .onAppear { // Load initial edit state
            editedRawContent = note.rawContent
            editedStructuredContent = note.structuredContent
            editedTitle = note.title
            editedColorTag = note.colorTag
            editedTags = note.tags // Load tags
            appManager.transientNoteColorTag = note.colorTag
            
            // Load saved tags from UserDefaults
            if let savedTags = UserDefaults.standard.stringArray(forKey: "freeDumpUserTags") {
                savedUserTags = savedTags
            }
        }
        .onDisappear { 
            appManager.transientNoteColorTag = nil
        }
    }
    
    // View for displaying note
    private var noteView: some View {
        // Determine background color based on the note's tag
        let noteBackgroundColor = colorForKey(note.colorTag) ?? Color(.systemBackground)
        // --- NEW: Determine appropriate text color for contrast --- 
        let foregroundTextColor = (noteBackgroundColor == Color(.systemBackground) || colorScheme == .dark) ? Color.primary : Color.black
        // --- END NEW ---
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Date info (Model info removed)
                HStack {
                    Text(formattedDate(note.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Tags (if any)
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(note.tags, id: \.self) { tag in
                                // Use simple Text styled as a chip for display
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(appManager.appTintColor.getColor().opacity(0.1))
                                    .foregroundColor(appManager.appTintColor.getColor())
                                    .clipShape(Capsule())
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 30)
                }
                
                Spacer().frame(height: 8) // Keep consistent spacing
                
                Divider().padding(.horizontal)
                
                // Content Display (Default to Processed)
                Group {
                    if note.isProcessing {
                        processingContentView
                            .padding(.horizontal)
                    // Show structured first if available
                    } else if !note.structuredContent.isEmpty { 
                        Markdown(note.structuredContent)
                            // --- NEW: Apply dynamic theme --- 
                            .markdownTheme(
                                .gitHub.text { 
                                     ForegroundColor(foregroundTextColor) // Set base text color
                                 }
                            )
                            // --- END NEW ---
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    } else { // Fallback to raw
                        Text(note.rawContent)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .background(noteBackgroundColor) // Apply the color here
        // Ensure text has good contrast
        .toolbar { // Toolbar for NOTE VIEW
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 15) {
                    Button { // Edit Button (Action unchanged)
                        editedRawContent = note.rawContent
                        editedStructuredContent = note.structuredContent
                        editedTitle = note.title
                        editedColorTag = note.colorTag
                        // Default edit mode when entering edit view
                        // If it's an audio note, always start with raw (transcript)
                        editMode = note.audioFilename != nil ? .raw : (!note.structuredContent.isEmpty ? .structured : .raw) 
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    // Share Button (unchanged)
                    Button { showShareSheet = true } label: { Image(systemName: "square.and.arrow.up") }
                    // Delete Button (unchanged)
                    Button(role: .destructive) { showDeleteConfirmation = true } label: { Image(systemName: "trash") }
                }
                .foregroundColor(.primary)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            // Share structured content if available, otherwise raw
            let contentToShare = note.structuredContent.isEmpty ? note.rawContent : note.structuredContent
            let textToShare = "\(note.title.isEmpty ? "Note" : note.title)\n\n\(contentToShare)"
            
            #if os(iOS)
            ActivityViewController(itemsToShare: [textToShare])
            #endif
        }
        .alert("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(note)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
    }
    
    // Processing content view with streaming text
    private var processingContentView: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text("AI is organizing...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical)
    }
    
    // View for editing note
    private var editingView: some View {
        // Calculate background color based on selection
        let currentEditBackgroundColor = colorForKey(editedColorTag) ?? Color(.systemBackground)
        
        return VStack(spacing: 0) {
            // --- Add Segmented Control BACK --- 
            // --- Hide Picker for Audio Notes --- 
            if note.audioFilename == nil {
                Picker("Edit Mode", selection: $editMode) {
                    Text("Processed").tag(EditMode.structured)
                    Text("Original").tag(EditMode.raw)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top]) // Add padding
                .disabled(isProcessing) // Disable during processing
            }
            // --- End Segmented Control ---
             
            // Title field (adjust padding, font)
            TextField("Title", text: $editedTitle)
                .font(.title2.weight(.semibold)) // Slightly smaller title
                .padding(.horizontal)
                .padding(.top, 16) // Increased top padding significantly
                .padding(.bottom, 6) // Slightly increased bottom padding too
            
            Divider()
            
            // Content field - switch based on editMode or show raw for audio
            Group {
                 // Always show raw editor if it's an audio note
                 if note.audioFilename != nil {
                     TextEditor(text: $editedRawContent)
                 } else if editMode == .raw {
                    TextEditor(text: $editedRawContent)
                 } else { // Show structured only if NOT audio and mode is structured
                    TextEditor(text: $editedStructuredContent)
                 }
            }
            .font(.body)
            .padding()
            .scrollContentBackground(.hidden) 
            .background(.clear)
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // --- Add ScrollView for bottom controls --- 
            ScrollView { 
                VStack(spacing: 0) {
                    // Color Picker Row (Unchanged)
                    HStack {
                        Text("Color:")
                            .font(.caption) // Reduced font size
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        ForEach(availableColorTags, id: \.self) { colorKey in
                            Button {
                                editedColorTag = colorKey
                                appManager.transientNoteColorTag = colorKey // Update AppManager for real-time effect
                            } label: {
                                Circle()
                                    .fill(colorForKey(colorKey) ?? Color.gray.opacity(0.2))
                                    .frame(width: 20, height: 20) // Reduced circle size
                                    .overlay(
                                        Circle().stroke(editedColorTag == colorKey ? Color.accentColor : Color.clear, lineWidth: 1.5) // Thinner stroke
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 6) // Further reduced vertical padding
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // --- NEW: Tag Editing Section --- 
                    VStack(alignment: .leading, spacing: 6) { // Reduced spacing
                        Text("Tags")
                            .font(.caption) // Reduced font size
                            .foregroundColor(.secondary)
                            .padding(.leading)
                        
                        // Display existing tags with delete
                        if !editedTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(editedTags, id: \.self) { tag in
                                        TagChipView(tag: tag) { // Use chip with remove
                                            editedTags.removeAll { $0 == tag }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 28) // Reduced height further
                        }
                        
                        // Input for new tags
                        HStack {
                            TextField("Add tag...", text: $tagInput)
                                .textFieldStyle(.plain)
                                .onSubmit(addTag) // Add tag on return
                            Button(action: addTag) { // Add tag button
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4) // Reduced bottom padding further
                        
                        // Add saved tags section
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
                                                if !editedTags.contains(tag) {
                                                    editedTags.append(tag)
                                                }
                                            } label: {
                                                HStack {
                                                    Text(tag)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                        .lineLimit(1)
                                                    
                                                    if editedTags.contains(tag) {
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
                                .frame(height: 35)
                            }
                        }
                    }
                    .padding(.top, 4) // Reduced top padding further
                    // --- End Tag Editing Section ---
                }
            }
            .frame(maxHeight: 180) // Increased height to accommodate saved tags
            .background(Color(.systemGray6))
            
            // --- NEW: Save Button at the Bottom --- 
            Button { 
                saveChanges()
                isEditing = false
            } label: {
                Text("Save Changes")
                    .font(.headline) // Keeping headline font for now
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10) // Reduced vertical padding
                    .background(appManager.appTintColor.getColor())
                    .foregroundColor(.white)
                    .cornerRadius(8) // Slightly smaller corner radius
            }
            .padding(.horizontal) // Keep horizontal padding
            .padding(.vertical, 8) // Reduced vertical padding around button
            .disabled(isProcessing) // Disable if processing
            // --- End Save Button --- 
        }
        .background(currentEditBackgroundColor.ignoresSafeArea()) // Apply background to main VStack
        .foregroundColor(currentEditBackgroundColor == Color(.systemBackground) ? .primary : .black) // Adjust foreground for contrast
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar { // Toolbar for EDITING VIEW
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isEditing = false
                    // Reset changes
                    editedRawContent = note.rawContent
                    editedStructuredContent = note.structuredContent
                    editedTitle = note.title
                    editedColorTag = note.colorTag
                    editedTags = note.tags // Reset tags
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                HStack(spacing: 15) { 
                    // Reprocess Button (Icon) - Keep this one
                    // --- Hide Reprocess for Audio Notes --- 
                    if note.audioFilename == nil {
                        Button {
                             reprocessNote()
                        } label: {
                             Image(systemName: "wand.and.stars.inverse")
                        }
                        .disabled(isProcessing || editedRawContent.isEmpty) // Disable if processing or raw is empty
                    }
                }
            }
        }
    }
    
    // --- NEW: Add Tag Function --- 
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty, !editedTags.contains(trimmedTag) else { 
            tagInput = "" // Clear input even if tag is duplicate or empty
            return 
        }
        editedTags.append(trimmedTag)
        tagInput = "" // Clear input field
    }
    // --- End Add Tag Function ---
    
    // Updated Save Changes Function
    private func saveChanges() {
        // --- Assign all edits to the note object FIRST ---
        note.rawContent = editedRawContent
        note.structuredContent = editedStructuredContent
        note.title = editedTitle
        note.colorTag = editedColorTag
        note.tags = editedTags // Save edited tags
        
        // --- Save main changes immediately ---
        do {
            try modelContext.save()
        } catch {
            // Handle or log the save error if needed
            print("Error saving main note changes: \(error)")
        }
        
        // --- THEN attempt to re-fetch link meta asynchronously ---
        Task {
            var linkChanged = false
            let oldLink = note.linkURL
            var fetchedLinkURL: String? = nil
            var fetchedLinkTitle: String? = nil
            var fetchedLinkImageURL: String? = nil
            
            if let detectedURL = LinkMetadataFetcher.detectURL(in: note.rawContent) {
                 fetchedLinkURL = detectedURL.absoluteString
                 if fetchedLinkURL != oldLink { // Only fetch if URL changed
                     linkChanged = true
                     let metadata = await LinkMetadataFetcher.fetchMetadata(for: detectedURL)
                     fetchedLinkTitle = metadata.title
                     fetchedLinkImageURL = metadata.imageURL
                 }
             } else if oldLink != nil {
                 // URL was removed
                 linkChanged = true
                 fetchedLinkURL = nil
                 fetchedLinkTitle = nil
                 fetchedLinkImageURL = nil
             }
             
             // Update note on main thread only if link changed
             if linkChanged {
                 await MainActor.run { 
                     note.linkURL = fetchedLinkURL
                     note.linkTitle = fetchedLinkTitle
                     note.linkImageURL = fetchedLinkImageURL
                     try? modelContext.save() // Save link changes AGAIN if they occurred
                 }
             }
        }
    }
    
    // Updated Reprocess Note Function
    private func reprocessNote() {
        guard !isProcessing else { return }
        isProcessing = true
        processingError = nil
        
        // Use the CURRENT content of the RAW editor
        let contentToReprocess = editedRawContent 
        let style = UserDefaults.standard.string(forKey: "freeDumpFormattingStyle") ?? "Simple"
        
        Task {
            var newTitle: String? = nil
            var newStructuredContent: String? = nil
            var processError: Error? = nil
            
            do {
                newTitle = try await generateTitle(for: contentToReprocess)
                // Use the non-streaming version for direct update
                newStructuredContent = try await processWithAI(rawContent: contentToReprocess, style: style)
            } catch {
                processError = error
            }
            
            await MainActor.run {
                isProcessing = false
                if let error = processError {
                    print("Reprocessing failed: \(error)")
                    processingError = "Reprocessing failed: \(error.localizedDescription)"
                } else {
                    // Update the EDITING fields, not the note directly yet
                    editedTitle = newTitle ?? generateBasicTitle(for: contentToReprocess)
                    editedStructuredContent = newStructuredContent ?? "" // Update the structured editor content
                    // Switch view to processed if not already
                    if editMode == .raw {
                         editMode = .structured
                    }
                    // User still needs to press Save to commit these changes
                    // Optionally, briefly show a success message?
                }
            }
        }
    }

    // Add non-streaming processWithAI (copied from DumpInputView)
    private func processWithAI(rawContent: String, style: String) async throws -> String { 
        guard let modelName = appManager.currentModelName else {
            throw NSError(domain: "FreeDump", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected for content processing"])
        }
        _ = try await llm.load(modelName: modelName) 
        
        let prompt: String
        switch style { // Use same styles as input view
            case "Simple Restructure": prompt = "Organize this text cleanly. Keep meaning/tone. NO TITLE:\n\n\(rawContent)"
            case "Grammar Fix": prompt = "Fix grammar/spelling/punctuation. Keep meaning. NO TITLE:\n\n\(rawContent)"
            case "Journal Entry": prompt = "Format as simple journal entry. Personal/reflective tone. NO TITLE:\n\n\(rawContent)"
            case "Detailed Summary": prompt = "Create detailed, structured version. Focus on content. NO TITLE:\n\n\(rawContent)"
            default: prompt = "Organize this text cleanly. Keep meaning/tone. NO TITLE:\n\n\(rawContent)"
        }
        
        let tempThread = Thread()
        let systemPrompt = "You organize text based on style. Respond ONLY with improved text. NO TITLE or extra markdown unless style requires it."
        let systemMessage = Message(role: .system, content: systemPrompt, thread: tempThread)
        let userMessage = Message(role: .user, content: prompt, thread: tempThread)
        
        modelContext.insert(tempThread)
        modelContext.insert(systemMessage)
        modelContext.insert(userMessage)
        
        let response = await llm.generate(
            modelName: modelName,
            thread: tempThread,
            systemPrompt: systemPrompt
        )
        
        modelContext.delete(systemMessage)
        modelContext.delete(userMessage)
        modelContext.delete(tempThread)
        
        return response
    }
    
    // --- NEW: Basic Title Generation (Copied from InputView) --- 
    private func generateBasicTitle(for content: String) -> String {
        let firstLine = content.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first ?? ""
        let title = String(firstLine.prefix(50))
        return title.isEmpty ? "Untitled Note" : title
    }
    // --- End Basic Title Generation ---
    
    // Process content with AI
    private func processContent() {
        guard !isProcessing else { return }
        isProcessing = true
        streamedContent = ""
        animationProgress = 0
        
        Task {
            do {
                let generatedTitle = try await generateTitle(for: note.rawContent)
                let structured = try await processWithAIStream(rawContent: note.rawContent)
                DispatchQueue.main.async {
                    note.title = generatedTitle
                    note.structuredContent = structured
                    note.modelName = appManager.currentModelName
                    isProcessing = false
                }
            } catch {
                print("Error reprocessing: \(error)")
                DispatchQueue.main.async {
                    isProcessing = false
                }
            }
        }
    }
    
    // Generate title for the note
    private func generateTitle(for rawContent: String) async throws -> String {
        guard let modelName = appManager.currentModelName else {
            throw NSError(domain: "FreeDump", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected for title generation"])
        }
        _ = try await llm.load(modelName: modelName)
        
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
        
        let cleanedTitle = titleResponse
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        
        return cleanedTitle.isEmpty ? "Untitled Note" : cleanedTitle
    }
    
    // Process content with AI - with streaming capability
    private func processWithAIStream(rawContent: String) async throws -> String {
        guard let modelName = appManager.currentModelName else {
            throw NSError(domain: "FreeDump", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model selected"])
        }
        _ = try await llm.load(modelName: modelName)
        
        // Use the style saved in UserDefaults or default to Simple
        let style = UserDefaults.standard.string(forKey: "freeDumpFormattingStyle") ?? "Simple"
        
        // Prompt based on style (Copied from InputView, adjusted)
        let prompt: String
        switch style {
            case "Simple": prompt = "Organize this text cleanly. Keep meaning/tone. NO TITLE:\n\n\(rawContent)"
            case "Grammar Fix": prompt = "Fix grammar/spelling/punctuation. Keep meaning. NO TITLE:\n\n\(rawContent)"
            case "Journal": prompt = "Format as simple journal entry. Personal/reflective tone. NO TITLE:\n\n\(rawContent)"
            case "Detailed": prompt = "Create detailed, structured version. Focus on content. NO TITLE:\n\n\(rawContent)"
            default: prompt = "Organize this text cleanly. Keep meaning/tone. NO TITLE:\n\n\(rawContent)"
        }
        
        let tempThread = Thread()
        let systemPrompt = "You organize text based on style. Respond ONLY with improved text. NO TITLE or extra markdown unless style requires it."
        let systemMessage = Message(role: .system, content: systemPrompt, thread: tempThread)
        let userMessage = Message(role: .user, content: prompt, thread: tempThread)
        
        modelContext.insert(tempThread)
        modelContext.insert(systemMessage)
        modelContext.insert(userMessage)
        
        let stream = llm.generateStream(
            modelName: modelName,
            thread: tempThread,
            systemPrompt: systemPrompt
        )
        
        // Reset streamedContent before starting
        DispatchQueue.main.async {
            streamedContent = ""
        }
        
        // Accumulate directly into streamedContent
        for try await chunk in stream {
            let currentChunk = chunk // Capture chunk locally for the dispatch block
            DispatchQueue.main.async {
                streamedContent += currentChunk // Append chunk on main thread
                withAnimation(.linear(duration: 0.1)) {
                    animationProgress = 1.0 // Keep animation logic
                }
            }
        }
        
        modelContext.delete(systemMessage)
        modelContext.delete(userMessage)
        modelContext.delete(tempThread)
        
        // Return the final accumulated content
        return streamedContent
    }
    
    // Format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // --- NEW: Color Helper --- 
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
    // --- End Color Helper ---
}

#if os(iOS)
// Activity view controller for sharing
struct ActivityViewController: UIViewControllerRepresentable {
    var itemsToShare: [Any]
    var servicesToShareItem: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: itemsToShare, applicationActivities: servicesToShareItem)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
#endif

#Preview {
    // Use the correct initializer with all required parameters
    DumpDetailView(note: DumpNote(
        rawContent: "This is a test note with some random thoughts.\nI need to remember to buy groceries tomorrow.\nAlso, I should finish that project by Friday.",
        structuredContent: "# Daily Tasks and Reminders\n\n## Groceries\n- Buy groceries tomorrow\n\n## Work\n- Finish project by Friday\n\nTAGS: tasks, reminders, groceries, work",
        title: "Daily Tasks and Reminders",
        tags: ["tasks", "reminders", "groceries", "work"],
        modelName: nil, // Provide nil or a value
        isPinned: false, // Provide default
        colorTag: "blue", // Provide nil or a value for preview
        audioFilename: nil // Provide nil for preview
    ))
    .environmentObject(AppManager())
    .modelContainer(for: DumpNote.self, inMemory: true)
    .environment(LLMEvaluator())
} 
