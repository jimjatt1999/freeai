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
    @State private var selectedTheme: NoteTheme = .standard
    @State private var animationProgress: CGFloat = 0
    @State private var showThemeSelector = false
    @State private var editMode: EditMode = .raw  // Either .raw or .structured
    @State private var showHistory = false
    @State private var showDictation = false
    @State private var selectedStyle: String = UserDefaults.standard.string(forKey: "selectedProcessingStyle") ?? "Simple"
    
    // Edit mode enum
    enum EditMode {
        case raw
        case structured
    }
    
    // Note themes
    enum NoteTheme: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case minimal = "Minimal"
        case paper = "Paper"
        case dark = "Dark"
        case colorful = "Colorful"
        case terminal = "Terminal"
        case retro = "Retro"
        
        var id: String { self.rawValue }
        
        func backgroundColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .standard:
                return Color(.systemBackground)
            case .minimal:
                return colorScheme == .dark ? Color.black : Color.white
            case .paper:
                return Color(red: 0.98, green: 0.97, blue: 0.94)
            case .dark:
                return Color.black.opacity(0.9)
            case .colorful:
                return colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.3) : Color(red: 0.9, green: 0.95, blue: 1.0)
            case .terminal:
                return Color.black
            case .retro:
                return Color(red: 0.9, green: 0.87, blue: 0.7)
            }
        }
        
        func textColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .dark:
                return .white
            case .colorful:
                return colorScheme == .dark ? Color(red: 0.9, green: 0.9, blue: 1.0) : Color(red: 0.1, green: 0.1, blue: 0.3)
            case .standard, .minimal:
                return colorScheme == .dark ? .white : .black
            case .paper:
                return .black
            case .terminal:
                return Color.green
            case .retro:
                return Color(red: 0.2, green: 0.0, blue: 0.0)
            }
        }
        
        func accentColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .standard:
                return .blue
            case .minimal:
                return colorScheme == .dark ? .gray : .black
            case .paper:
                return .brown
            case .dark:
                return .blue
            case .colorful:
                return .purple
            case .terminal:
                return .green.opacity(0.8)
            case .retro:
                return Color(red: 0.6, green: 0.1, blue: 0.1)
            }
        }
        
        func fontName() -> String? {
            switch self {
            case .standard, .minimal, .dark, .colorful, .paper:
                return nil // Use default system font
            case .terminal:
                return "Menlo"
            case .retro:
                return "AmericanTypewriter"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            if isEditing {
                editingView
            } else {
                noteView
            }
        }
    }
    
    // View for displaying note
    private var noteView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(selectedTheme.textColor(for: colorScheme))
                    .padding(.horizontal)
                
                // Date and model info
                HStack {
                    Text(formattedDate(note.timestamp))
                        .font(.caption)
                        .foregroundColor(selectedTheme.textColor(for: colorScheme).opacity(0.7))
                    
                    Spacer()
                    
                    if let modelName = note.modelName {
                        Text("Processed with \(appManager.modelDisplayName(modelName))")
                            .font(.caption)
                            .foregroundColor(selectedTheme.textColor(for: colorScheme).opacity(0.7))
                    }
                }
                .padding(.horizontal)
                
                // Tags
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedTheme.accentColor(for: colorScheme).opacity(0.1))
                                    .foregroundColor(selectedTheme.accentColor(for: colorScheme))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Toggle between processed content and original
                if !note.rawContent.isEmpty && !note.structuredContent.isEmpty && !note.isProcessing {
                    Toggle(isOn: $showHistory) {
                        Text(showHistory ? "Showing Original Content" : "Showing Processed Content")
                            .font(.caption)
                            .foregroundColor(selectedTheme.textColor(for: colorScheme).opacity(0.7))
                    }
                    .padding(.horizontal)
                    .toggleStyle(SwitchToggleStyle(tint: selectedTheme.accentColor(for: colorScheme)))
                }
                
                Divider()
                    .padding(.horizontal)
                    .background(selectedTheme.textColor(for: colorScheme).opacity(0.2))
                
                // Content - show either processed or original based on toggle
                Group {
                    if note.isProcessing {
                        // Show streaming content when processing
                        processingContentView
                    } else if showHistory {
                        // Show original raw content
                        Text(note.rawContent)
                            .font(themeFont)
                            .padding(.horizontal)
                            .foregroundColor(selectedTheme.textColor(for: colorScheme))
                    } else if !note.structuredContent.isEmpty {
                        // Structured content with Markdown or custom formatting
                        structuredContentView
                    } else {
                        // Raw content
                        rawContentView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Action buttons
                if !note.isProcessing {
                    HStack(spacing: 20) {
                        Spacer()
                        
                        // Theme selector button
                        Button {
                            showThemeSelector = true
                        } label: {
                            Label("Theme", systemImage: "paintpalette")
                                .font(.footnote)
                        }
                        
                        // Process/reprocess button
                        Button {
                            processContent()
                        } label: {
                            Label(note.structuredContent.isEmpty ? "Process with AI" : "Reprocess", systemImage: "wand.and.stars")
                                .font(.footnote)
                        }
                        
                        // Share button
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.footnote)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(selectedTheme.backgroundColor(for: colorScheme).opacity(0.3))
                    .cornerRadius(10)
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .background(selectedTheme.backgroundColor(for: colorScheme))
        .tint(selectedTheme.accentColor(for: colorScheme))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(selectedTheme.accentColor(for: colorScheme))
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // Set up edited content based on what's being shown
                        editedRawContent = note.rawContent
                        editedStructuredContent = note.structuredContent
                        editedTitle = note.title
                        editMode = showHistory ? .raw : .structured
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button {
                        showThemeSelector = true
                    } label: {
                        Label("Change Theme", systemImage: "paintpalette")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .foregroundColor(selectedTheme.accentColor(for: colorScheme))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            let content = showHistory ? note.rawContent : 
                        (note.structuredContent.isEmpty ? note.rawContent : note.structuredContent)
            let textToShare = "\(note.title)\n\n\(content)"
            
            #if os(iOS)
            ActivityViewController(itemsToShare: [textToShare])
            #endif
        }
        .sheet(isPresented: $showThemeSelector) {
            themePickerView
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
        .onAppear {
            // Load theme from user defaults if saved
            if let savedTheme = UserDefaults.standard.string(forKey: "freeDumpTheme"),
               let theme = NoteTheme(rawValue: savedTheme) {
                selectedTheme = theme
            }
        }
    }
    
    // Theme picker sheet
    private var themePickerView: some View {
        NavigationStack {
            List {
                ForEach(NoteTheme.allCases) { theme in
                    Button {
                        selectedTheme = theme
                        UserDefaults.standard.set(theme.rawValue, forKey: "freeDumpTheme")
                        showThemeSelector = false
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.backgroundColor(for: colorScheme))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray, lineWidth: 0.5)
                                )
                            
                            Text(theme.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showThemeSelector = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // Processing content view with streaming text
    private var processingContentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("AI is organizing your thoughts...")
                    .font(.subheadline)
                    .foregroundColor(selectedTheme.textColor(for: colorScheme).opacity(0.7))
                Spacer()
            }
            .padding(.bottom, 8)
            
            if !streamedContent.isEmpty {
                // Apply typewriter effect to streaming content
                Text(displayedStreamContent)
                    .font(themeFont)
                    .foregroundColor(selectedTheme.textColor(for: colorScheme))
            }
        }
        .padding(.horizontal)
    }
    
    // Structured content view with markdown
    private var structuredContentView: some View {
        let content = note.structuredContent
        
        if selectedTheme == .terminal {
            // Terminal style text with monospace font
            return ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content)
                        .font(.custom("Menlo", size: 14))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        } else if selectedTheme == .retro {
            // Retro style for vintage look
            return ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text(content)
                        .font(.custom("AmericanTypewriter", size: 16))
                        .foregroundColor(selectedTheme.textColor(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        } else {
            // Standard markdown for other themes
            return Markdown(content)
                .markdownTheme(.gitHub)
                .padding(.horizontal)
                .foregroundColor(selectedTheme.textColor(for: colorScheme))
                .font(themeFont)
        }
    }
    
    // Raw content view
    private var rawContentView: some View {
        Text(note.rawContent)
            .font(themeFont)
            .padding(.horizontal)
            .foregroundColor(selectedTheme.textColor(for: colorScheme))
    }
    
    // Helper computed property for theme-specific font
    private var themeFont: Font {
        if let fontName = selectedTheme.fontName() {
            return .custom(fontName, size: 16)
        } else {
            return .body
        }
    }
    
    // Get displayed content based on animation progress
    var displayedStreamContent: String {
        let content = streamedContent
        
        if appManager.chatAnimationStyle != "none" && animationProgress < 1 {
            let length = Int(Double(content.count) * animationProgress)
            return String(content.prefix(length))
        }
        
        return content
    }
    
    // View for editing note
    private var editingView: some View {
        VStack(spacing: 0) {
            // Segmented control to choose edit mode
            Picker("Edit Mode", selection: $editMode) {
                Text("Original").tag(EditMode.raw)
                Text("Processed").tag(EditMode.structured)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Title field
            TextField("Title", text: $editedTitle)
                .font(.title3)
                .fontWeight(.bold)
                .padding()
                .background(Color(.systemBackground))
            
            Divider()
            
            // Content field - shows either raw or structured content based on mode
            if editMode == .raw {
                // Raw content editor
                TextEditor(text: $editedRawContent)
                    .font(.body)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
            } else {
                // Structured content editor
                TextEditor(text: $editedStructuredContent)
                    .font(.body)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    isEditing = false
                }
                .foregroundColor(.red)
                
                Spacer()
                
                #if os(iOS)
                // Dictation button
                Button {
                    showDictation = true
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.blue)
                }
                #endif
                
                Spacer()
                
                Button {
                    // Save changes but don't process
                    saveEdits(processContent: false)
                } label: {
                    Text("Save")
                }
                
                Button {
                    // Save changes and process if editing raw content
                    saveEdits(processContent: editMode == .raw)
                } label: {
                    if editMode == .raw {
                        Text("Save & Process")
                            .bold()
                    } else {
                        Text("Save")
                            .bold()
                    }
                }
                .padding(.leading, 10)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .navigationBarHidden(true)
        #if os(iOS)
        .sheet(isPresented: $showDictation) {
            DictationView { dictatedText in
                if !dictatedText.isEmpty {
                    // Append to either raw or structured content based on edit mode
                    if editMode == .raw {
                        if editedRawContent.isEmpty {
                            editedRawContent = dictatedText
                        } else {
                            editedRawContent += "\n\n" + dictatedText
                        }
                    } else {
                        if editedStructuredContent.isEmpty {
                            editedStructuredContent = dictatedText
                        } else {
                            editedStructuredContent += "\n\n" + dictatedText
                        }
                    }
                }
                showDictation = false
            }
        }
        #endif
    }
    
    // Save edits made to the note
    private func saveEdits(processContent shouldProcess: Bool) {
        if editMode == .raw {
            note.rawContent = editedRawContent
        } else {
            note.structuredContent = editedStructuredContent
        }
        
        note.title = editedTitle
        isEditing = false
        
        if shouldProcess {
            processContent()
        }
    }
    
    // Process content with AI
    private func processContent() {
        guard !note.rawContent.isEmpty else { return }
        
        note.isProcessing = true
        streamedContent = ""
        animationProgress = 0
        
        Task {
            do {
                // Process content with streaming
                let structuredContent = try await processWithAIStream(rawContent: note.rawContent)
                
                // Extract title and tags
                let (title, tags) = extractTitleAndTags(from: structuredContent)
                
                // Update note with processed content
                DispatchQueue.main.async {
                    note.structuredContent = structuredContent
                    note.title = title.isEmpty ? note.title : title
                    note.tags = tags
                    note.modelName = appManager.currentModelName
                    note.isProcessing = false
                    streamedContent = ""
                }
            } catch {
                DispatchQueue.main.async {
                    note.isProcessing = false
                    streamedContent = ""
                }
            }
        }
    }
    
    // Process content with AI - with streaming capability
    private func processWithAIStream(rawContent: String) async throws -> String {
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
        
        // Use generateStream to get streaming response
        let stream = llm.generateStream(
            modelName: modelName,
            thread: tempThread,
            systemPrompt: "You are a helpful assistant that organizes text. Respond only with the improved text without adding any special markdown symbols, asterisks, or section markers."
        )
        
        var fullResponse = ""
        
        for try await chunk in stream {
            // Update the streamed content
            fullResponse += chunk
            DispatchQueue.main.async {
                streamedContent = fullResponse
                
                // Animate the text appearance
                withAnimation(.linear(duration: 0.5)) {
                    animationProgress = 1.0
                }
            }
        }
        
        // Clean up temporary thread
        modelContext.delete(systemMessage)
        modelContext.delete(userMessage)
        modelContext.delete(tempThread)
        
        return fullResponse
    }
    
    // Extract title and tags from processed content - simplified
    private func extractTitleAndTags(from content: String) -> (String, [String]) {
        var title = ""
        var tags: [String] = []
        
        // Get the first line as the title (or first few words if no line breaks)
        let lines = content.split(separator: "\n", maxSplits: 1)
        if let firstLine = lines.first {
            title = String(firstLine.prefix(50))
            if title.count == 50 && !title.hasSuffix(".") && !title.hasSuffix("!") && !title.hasSuffix("?") {
                title += "..."
            }
        }
        
        // Look for tags at the end - support both "TAGS:" and "Tags:" formats
        if let tagsLine = content.split(separator: "\n").last(where: { 
            $0.lowercased().contains("tags:") || $0.lowercased().contains("tag:") 
        }) {
            let components = tagsLine.components(separatedBy: ":")
            if components.count > 1 {
                let tagsText = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                tags = tagsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        
        return (title, tags)
    }
    
    // Format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
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
    DumpDetailView(note: DumpNote(
        rawContent: "This is a test note with some random thoughts.\nI need to remember to buy groceries tomorrow.\nAlso, I should finish that project by Friday.",
        structuredContent: "# Daily Tasks and Reminders\n\n## Groceries\n- Buy groceries tomorrow\n\n## Work\n- Finish project by Friday\n\nTAGS: tasks, reminders, groceries, work",
        title: "Daily Tasks and Reminders",
        tags: ["tasks", "reminders", "groceries", "work"]
    ))
    .environmentObject(AppManager())
    .modelContainer(for: DumpNote.self, inMemory: true)
    .environment(LLMEvaluator())
} 