//
//  FreeDumpSettingsView.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI
import SwiftData

struct FreeDumpSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Query private var dumpNotes: [DumpNote]
    
    @State private var showDeleteConfirmation = false
    @State private var formattingStyle: String = UserDefaults.standard.string(forKey: "freeDumpFormattingStyle") ?? "Save Raw"
    @State private var customTag: String = ""
    @State private var userTags: [String] = []
    @State private var showExportErrorAlert = false
    @State private var exportErrorMessage = ""
    
    // Available formatting presets - ensure consistency
    private let formattingPresets = [
        "Save Raw": "No AI processing is applied.",
        "Simple Restructure": "Basic restructuring with simple formatting.",
        "Grammar Fix": "Focus on correcting grammar and spelling.",
        "Journal Entry": "Format as a reflective journal entry.",
        "Detailed Summary": "Comprehensive organization with detailed sections."
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                noteProcessingStyleSection
                
                // Custom tags section
                customTagsSection
                
                // Model selection section
                modelSelectionSection
                
                // Content management section
                contentManagementSection
                
                // About section
                aboutSection
            }
            .navigationTitle("Notes Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear All Notes", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllNotes()
                }
            } message: {
                Text("This will permanently delete all your notes. This action cannot be undone.")
            }
            .alert("Export Error", isPresented: $showExportErrorAlert) {
                Button("OK") { }
            } message: {
                Text(exportErrorMessage)
            }
            .onAppear {
                // Collect all tags from notes and from UserDefaults
                var allTags = Set<String>()
                
                // Add tags from UserDefaults
                if let savedTags = UserDefaults.standard.stringArray(forKey: "freeDumpUserTags") {
                    savedTags.forEach { allTags.insert($0) }
                }
                
                // Add tags from all notes
                for note in dumpNotes {
                    for tag in note.tags {
                        allTags.insert(tag)
                    }
                }
                
                // Update userTags and save to UserDefaults
                userTags = Array(allTags).sorted()
                UserDefaults.standard.set(userTags, forKey: "freeDumpUserTags")
            }
            .onChange(of: formattingStyle) { _, newValue in
                print("Formatting style changed to: \(newValue)") // DEBUG
                UserDefaults.standard.set(newValue, forKey: "freeDumpFormattingStyle")
                print("Saved '\(newValue)' to UserDefaults for key 'freeDumpFormattingStyle'") // DEBUG
            }
            .onChange(of: userTags) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "freeDumpUserTags")
            }
        }
    }
    
    // Extracted Section Views
    private var noteProcessingStyleSection: some View {
        Section(header: Text("DEFAULT NOTE PROCESSING STYLE")) {
            Picker("Style", selection: $formattingStyle) {
                ForEach(Array(formattingPresets.keys).sorted(), id: \.self) { preset in
                    Text(preset).tag(preset)
                }
            }
            .pickerStyle(.navigationLink)
            
            // Show description of selected formatting style
            if let description = formattingPresets[formattingStyle] {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var customTagsSection: some View {
        Section(header: Text("CREATE AND MANAGE TAGS")) {
            HStack {
                TextField("New tag", text: $customTag)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: {
                    if !customTag.isEmpty && !userTags.contains(customTag) {
                        userTags.append(customTag)
                        customTag = ""
                        // Save tags immediately to UserDefaults
                        UserDefaults.standard.set(userTags, forKey: "freeDumpUserTags")
                    }
                }) {
                    Text("Add")
                        .fontWeight(.medium)
                }
                .disabled(customTag.isEmpty)
            }
            
            if !userTags.isEmpty {
                Text("Your tags:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(userTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.footnote)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                
                                Button(action: {
                                    userTags.removeAll { $0 == tag }
                                    // Save immediately after deleting
                                    UserDefaults.standard.set(userTags, forKey: "freeDumpUserTags")
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.footnote)
                                }
                            }
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("Add custom tags that you often use in your notes. These tags will automatically appear when creating or editing notes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var modelSelectionSection: some View {
        Section(header: Text("MODEL")) {
            NavigationLink(destination: ModelsSettingsView()) {
                Label {
                    Text("Model")
                        .fixedSize()
                } icon: {
                    Image(systemName: "cpu")
                }
                .badge(appManager.modelDisplayName(appManager.currentModelName ?? ""))
            }
            
            // Explanation text
            Text("Select a model to process your notes. More powerful models may provide better organization but require more memory.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var contentManagementSection: some View {
        Section(header: Text("CONTENT MANAGEMENT")) {
            if dumpNotes.count > 0 {
                Text("\(dumpNotes.count) notes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Enhanced export options
                Menu {
                    Button(action: { exportAllNotes(format: .txt) }) {
                        Label("Export as Text Files (.zip)", systemImage: "doc.text")
                    }
                    
                    Button(action: { exportAllNotes(format: .json) }) {
                        Label("Export as JSON", systemImage: "arrow.up.doc")
                    }
                } label: {
                    Label("Export All Notes", systemImage: "square.and.arrow.up")
                }
                .disabled(dumpNotes.isEmpty)
                
                // Clear all notes option
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Clear All Notes", systemImage: "trash")
                }
            } else {
                Text("No notes yet")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }
    
    // Enum for export formats
    enum ExportFormat {
        case txt
        case json
    }
    
    // Refactored export notes function
    private func exportAllNotes(format: ExportFormat) {
        guard !dumpNotes.isEmpty else { return }
        
        // Create temp directory URL
        let tempDir = FileManager.default.temporaryDirectory
        var fileToShareURL: URL?
        var exportError: Error? = nil
        
        do {
            if format == .txt {
                // --- Create a SINGLE TXT file --- 
                let txtFileURL = tempDir.appendingPathComponent("NeuraNotesExport.txt")
                try? FileManager.default.removeItem(at: txtFileURL) // Remove if exists
                
                var combinedContent = "" // Start with an empty string
                for note in dumpNotes {
                    combinedContent += "Title: \(note.title.isEmpty ? "Untitled" : note.title)\n"
                    combinedContent += "Date: \(formatDate(note.timestamp))\n"
                    if !note.tags.isEmpty {
                        combinedContent += "Tags: \(note.tags.joined(separator: ", "))\n"
                    }
                    combinedContent += "\n"
                    combinedContent += "\(note.structuredContent.isEmpty ? note.rawContent : note.structuredContent)\n"
                    combinedContent += "\n---\n\n" // Add a separator
                }
                
                // Write the combined string to the single file
                try combinedContent.write(to: txtFileURL, atomically: true, encoding: .utf8)
                fileToShareURL = txtFileURL
                print("Successfully created combined TXT export file at: \(txtFileURL)")
                // --- END SINGLE TXT file creation ---

            } else { // JSON export
                let jsonURL = tempDir.appendingPathComponent("NeuraNotesExport.json")
                try? FileManager.default.removeItem(at: jsonURL) // Remove if exists

                // Convert notes to a dictionary (Existing logic)
                let notesData = dumpNotes.map { note -> [String: Any] in
                    [
                        "id": note.id.uuidString,
                        "title": note.title,
                        "rawContent": note.rawContent,
                        "structuredContent": note.structuredContent,
                        "timestamp": formatDate(note.timestamp), // Using existing formatter
                        "tags": note.tags,
                        "colorTag": note.colorTag ?? "",
                        "isPinned": note.isPinned,
                        "audioFilename": note.audioFilename ?? "",
                        "transcription": note.transcription ?? "",
                        "linkURL": note.linkURL ?? "",
                        "linkTitle": note.linkTitle ?? "",
                        "linkImageURL": note.linkImageURL ?? ""
                    ]
                }

                // Serialize and write JSON (Add specific error handling)
                let jsonData = try JSONSerialization.data(withJSONObject: notesData, options: .prettyPrinted)
                try jsonData.write(to: jsonURL)
                fileToShareURL = jsonURL
                print("Successfully created JSON export file at: \(jsonURL)")
            }
            
        } catch {
            print("Error creating export file: \(error)")
            exportError = error
        }
        
        // --- Present Share Sheet --- 
        if let url = fileToShareURL, exportError == nil {
            do { // Add do-catch for presentation
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                // Find the appropriate presenting view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, 
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    throw NSError(domain: "UIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller."])
                }
                
                // Handle iPad popover presentation
                if let popoverController = activityVC.popoverPresentationController {
                    popoverController.sourceView = rootViewController.view // Or specify a more specific source view
                    popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = [] // No arrow for centered presentation
                }
                
                // Find the most appropriate controller to present from
                var presenter = rootViewController
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                
                presenter.present(activityVC, animated: true)
                print("Presented share sheet for: \(url)")
                
            } catch {
                print("Error presenting share sheet: \(error)")
                exportError = error // Set error if presentation fails
            }
        }
        
        // --- Show Alert on Error --- 
        if let error = exportError {
            exportErrorMessage = "Failed to export notes: \(error.localizedDescription)"
            showExportErrorAlert = true
        }
    }
    
    // Helper to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var aboutSection: some View {
        Section(header: Text("About Notes")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                
                Text("Notes helps you organize your thoughts with AI. Just dump your unstructured notes, and the AI will help structure them into a coherent format with headings, bullet points, and tags.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // Delete all notes
    private func deleteAllNotes() {
        for note in dumpNotes {
            modelContext.delete(note)
        }
    }
}

#Preview {
    FreeDumpSettingsView()
        .environmentObject(AppManager())
        .modelContainer(for: DumpNote.self, inMemory: true)
        .environment(LLMEvaluator())
} 