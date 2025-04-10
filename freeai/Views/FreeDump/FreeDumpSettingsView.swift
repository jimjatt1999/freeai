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
    @State private var formattingStyle: String = "Simple"
    @State private var customTag: String = ""
    @State private var userTags: [String] = []
    
    // Available formatting presets - simplified
    private let formattingPresets = [
        "Simple": "Basic restructuring with simple formatting",
        "Grammar Fix": "Focus on correcting grammar and spelling",
        "Detailed": "Comprehensive organization with detailed sections",
        "Journal": "Format as a reflective journal entry"
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
                
                // Add "Made by" section at the bottom with version number
                Section {
                    HStack {
                        Text("Made by Jimi Olaoya")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("v\(Bundle.main.releaseVersionNumber ?? "1.0")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("FreeDump Settings")
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
            .onAppear {
                // Load saved values
                formattingStyle = UserDefaults.standard.string(forKey: "freeDumpFormattingStyle") ?? "Simple"
                
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
                UserDefaults.standard.set(newValue, forKey: "freeDumpFormattingStyle")
            }
            .onChange(of: userTags) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "freeDumpUserTags")
            }
        }
    }
    
    // Extracted Section Views
    private var noteProcessingStyleSection: some View {
        Section(header: Text("NOTE PROCESSING STYLE")) {
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
    
    // Fixed export notes function
    private func exportAllNotes(format: ExportFormat) {
        guard !dumpNotes.isEmpty else { return }
        
        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
        var archiveURL: URL?
        
        do {
            if format == .txt {
                // Create a directory for the files
                let notesDir = tempDir.appendingPathComponent("FreeAINotes")
                try? FileManager.default.removeItem(at: notesDir) // Remove if exists
                try FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true, attributes: nil)
                
                // Create a text file for each note
                for note in dumpNotes {
                    let title = note.title.isEmpty ? "Untitled" : note.title
                    let safeName = title.replacingOccurrences(of: "/", with: "-")
                                        .replacingOccurrences(of: "\\", with: "-")
                    let fileName = "\(safeName)-\(note.id.uuidString.prefix(8)).txt"
                    let fileURL = notesDir.appendingPathComponent(fileName)
                    
                    // Format the note content
                    var content = "Title: \(note.title)\n"
                    content += "Date: \(formatDate(note.timestamp))\n"
                    if !note.tags.isEmpty {
                        content += "Tags: \(note.tags.joined(separator: ", "))\n"
                    }
                    content += "\n\(note.structuredContent.isEmpty ? note.rawContent : note.structuredContent)"
                    
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                }
                
                // Create zip archive
                let zipURL = tempDir.appendingPathComponent("FreeAINotes.zip")
                try? FileManager.default.removeItem(at: zipURL) // Remove if exists
                
                // Share directly the folder instead of zip for now
                archiveURL = notesDir
            } else {
                // JSON export
                let jsonURL = tempDir.appendingPathComponent("FreeAINotes.json")
                try? FileManager.default.removeItem(at: jsonURL) // Remove if exists
                
                // Convert notes to a dictionary
                let notesData = dumpNotes.map { note -> [String: Any] in
                    [
                        "id": note.id.uuidString,
                        "title": note.title,
                        "rawContent": note.rawContent,
                        "structuredContent": note.structuredContent,
                        "timestamp": formatDate(note.timestamp),
                        "tags": note.tags
                    ]
                }
                
                // Serialize to JSON
                let jsonData = try JSONSerialization.data(withJSONObject: notesData, options: .prettyPrinted)
                try jsonData.write(to: jsonURL)
                
                archiveURL = jsonURL
            }
            
            // Share the file
            if let url = archiveURL {
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                // Present the activity view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let controller = windowScene.windows.first?.rootViewController {
                    controller.present(activityVC, animated: true)
                }
            }
        } catch {
            print("Error exporting notes: \(error)")
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
        Section(header: Text("ABOUT")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("FreeDump")
                    .font(.headline)
                
                Text("FreeDump helps you organize your thoughts with AI. Just dump your unstructured notes, and the AI will help structure them into a coherent format with headings, bullet points, and tags.")
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