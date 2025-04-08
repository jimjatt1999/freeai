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
                // Formatting style section
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
                
                // Custom tags section
                Section(header: Text("MANAGE TAGS")) {
                    HStack {
                        TextField("New tag", text: $customTag)
                        
                        Button(action: {
                            if !customTag.isEmpty && !userTags.contains(customTag) {
                                userTags.append(customTag)
                                customTag = ""
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
                        Text("Add custom tags that you often use in your notes. You can manually add these to notes after creating them.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Model selection section
                Section(header: Text("MODEL")) {
                    NavigationLink(destination: ModelsSettingsView(isForFreeMode: false)) {
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
                
                // Content management section
                Section(header: Text("CONTENT MANAGEMENT")) {
                    if dumpNotes.count > 0 {
                        Text("\(dumpNotes.count) notes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Export all notes option
                        Button {
                            // Future implementation
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
                
                // About section
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
                if let savedTags = UserDefaults.standard.stringArray(forKey: "freeDumpUserTags") {
                    userTags = savedTags
                }
            }
            .onChange(of: formattingStyle) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "freeDumpFormattingStyle")
            }
            .onChange(of: userTags) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "freeDumpUserTags")
            }
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