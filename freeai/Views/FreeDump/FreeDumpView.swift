//
//  FreeDumpView.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI
import SwiftData
import MarkdownUI

struct FreeDumpView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Query private var dumpNotes: [DumpNote]
    
    @Binding var showFreeDump: Bool
    @Binding var currentThread: Thread?
    
    @State private var showSettings = false
    @State private var showNewNote = false
    @State private var searchText = ""
    @State private var selectedNote: DumpNote?
    @State private var isProcessing = false
    @State private var selectedCategoryFilter: String? = nil
    @State private var showDeleteAlert = false
    @State private var noteToDelete: DumpNote? = nil
    
    // Filter notes based on search text and category
    private var filteredNotes: [DumpNote] {
        // First separate pinned and unpinned notes
        let pinnedNotes = dumpNotes.filter { note in
            // Explicitly cast to Bool to fix potential pinning issues
            let isPinned = note.isPinned as? Bool ?? false
            return isPinned
        }
        
        let unpinnedNotes = dumpNotes.filter { note in
            // Explicitly cast to Bool to fix potential pinning issues
            let isPinned = note.isPinned as? Bool ?? false
            return !isPinned
        }
        
        // Filter by text
        let textFilteredPinned: [DumpNote]
        if searchText.isEmpty {
            textFilteredPinned = pinnedNotes.sorted { $0.timestamp > $1.timestamp }
        } else {
            textFilteredPinned = pinnedNotes.filter { note in
                note.title.lowercased().contains(searchText.lowercased()) ||
                note.rawContent.lowercased().contains(searchText.lowercased()) ||
                note.structuredContent.lowercased().contains(searchText.lowercased()) ||
                note.tags.contains { $0.lowercased().contains(searchText.lowercased()) }
            }.sorted { $0.timestamp > $1.timestamp }
        }
        
        let textFilteredUnpinned: [DumpNote]
        if searchText.isEmpty {
            textFilteredUnpinned = unpinnedNotes.sorted { $0.timestamp > $1.timestamp }
        } else {
            textFilteredUnpinned = unpinnedNotes.filter { note in
                note.title.lowercased().contains(searchText.lowercased()) ||
                note.rawContent.lowercased().contains(searchText.lowercased()) ||
                note.structuredContent.lowercased().contains(searchText.lowercased()) ||
                note.tags.contains { $0.lowercased().contains(searchText.lowercased()) }
            }.sorted { $0.timestamp > $1.timestamp }
        }
        
        // Apply category or date filter if selected
        let categoryFilteredPinned: [DumpNote]
        let categoryFilteredUnpinned: [DumpNote]
        
        if let filter = selectedCategoryFilter {
            // Date filters
            if filter == "today" {
                // Today filter
                categoryFilteredPinned = textFilteredPinned.filter { note in
                    Calendar.current.isDateInToday(note.timestamp)
                }
                
                categoryFilteredUnpinned = textFilteredUnpinned.filter { note in
                    Calendar.current.isDateInToday(note.timestamp)
                }
            } else if filter == "this-week" {
                // This week filter
                let calendar = Calendar.current
                categoryFilteredPinned = textFilteredPinned.filter { note in
                    let components = calendar.dateComponents([.weekOfYear], from: note.timestamp, to: Date())
                    return components.weekOfYear == 0
                }
                
                categoryFilteredUnpinned = textFilteredUnpinned.filter { note in
                    let components = calendar.dateComponents([.weekOfYear], from: note.timestamp, to: Date())
                    return components.weekOfYear == 0
                }
            } else {
                // Tag filter
                categoryFilteredPinned = textFilteredPinned.filter { note in
                    note.tags.contains(where: { $0.lowercased() == filter.lowercased() })
                }
                
                categoryFilteredUnpinned = textFilteredUnpinned.filter { note in
                    note.tags.contains(where: { $0.lowercased() == filter.lowercased() })
                }
            }
        } else {
            categoryFilteredPinned = textFilteredPinned
            categoryFilteredUnpinned = textFilteredUnpinned
        }
        
        // Combine pinned notes (on top) and unpinned notes
        return categoryFilteredPinned + categoryFilteredUnpinned
    }
    
    // Get all unique categories from notes
    private var availableCategories: [String] {
        var categories = Set<String>()
        for note in dumpNotes {
            for tag in note.tags {
                categories.insert(tag.lowercased())
            }
        }
        return Array(categories).sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header - Removed ScrollView wrapper
                HStack {
                    Spacer()

                    // Conditionally show Title or Eyes in Center
                    if appManager.showAnimatedEyes {
                         AnimatedEyesView(isGenerating: false) // No easy generating state here
                             .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else {
                         Text("free dump")
                             .font(.title)
                             .fontWeight(.bold)
                    }

                    Spacer()

                    // Settings button remains trailing
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                }
                .padding() // Keep padding on the HStack

                if dumpNotes.isEmpty {
                    // Empty state
                    emptyStateView
                        .frame(maxHeight: .infinity) // Ensure empty state fills space
                } else {
                    // Search bar
                    searchBar
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    
                    // Category filter chips and date filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // All filter
                            Button {
                                withAnimation {
                                    selectedCategoryFilter = nil
                                }
                            } label: {
                                Text("All")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategoryFilter == nil ? 
                                                  Color.blue : Color(.systemGray5))
                                    )
                                    .foregroundColor(selectedCategoryFilter == nil ? 
                                                  .white : .primary)
                            }
                            
                            // Date filters
                            Group {
                                Button {
                                    withAnimation {
                                        selectedCategoryFilter = "today"
                                    }
                                } label: {
                                    Text("Today")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategoryFilter == "today" ? 
                                                      Color.blue : Color(.systemGray5))
                                        )
                                        .foregroundColor(selectedCategoryFilter == "today" ? 
                                                      .white : .primary)
                                }
                                
                                Button {
                                    withAnimation {
                                        selectedCategoryFilter = "this-week"
                                    }
                                } label: {
                                    Text("This Week")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategoryFilter == "this-week" ? 
                                                      Color.blue : Color(.systemGray5))
                                        )
                                        .foregroundColor(selectedCategoryFilter == "this-week" ? 
                                                      .white : .primary)
                                }
                            }
                            
                            // Category filters
                            ForEach(availableCategories, id: \.self) { category in
                                Button {
                                    withAnimation {
                                        if selectedCategoryFilter == category {
                                            selectedCategoryFilter = nil
                                        } else {
                                            selectedCategoryFilter = category
                                        }
                                    }
                                } label: {
                                    Text(category.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategoryFilter == category ? 
                                                      Color.blue : Color(.systemGray5))
                                        )
                                        .foregroundColor(selectedCategoryFilter == category ? 
                                                      .white : .primary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 12)
                    
                    // Show filtered count if filtering
                    if let filter = selectedCategoryFilter {
                        HStack {
                            if filter == "today" {
                                Text("Showing \(filteredNotes.count) notes from today")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if filter == "this-week" {
                                Text("Showing \(filteredNotes.count) notes from this week")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Showing \(filteredNotes.count) notes tagged \"\(filter)\"")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    selectedCategoryFilter = nil
                                }
                            } label: {
                                Text("Clear filter")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Notes list
                    List {
                        ForEach(filteredNotes) { note in
                            Button {
                                selectedNote = note
                            } label: {
                                noteListItem(note)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button {
                                    // Toggle pin status with fixed Boolean handling
                                    let isPinned = note.isPinned as? Bool ?? false
                                    note.isPinned = !isPinned
                                } label: {
                                    let isPinned = note.isPinned as? Bool ?? false
                                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                                
                                Button(role: .destructive) {
                                    modelContext.delete(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    // Toggle pin status with fixed Boolean handling
                                    let isPinned = note.isPinned as? Bool ?? false
                                    note.isPinned = !isPinned
                                } label: {
                                    let isPinned = note.isPinned as? Bool ?? false
                                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                                }
                                
                                Button(role: .destructive) {
                                    noteToDelete = note
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .overlay(
                // New note button
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            showNewNote = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 24, weight: .semibold))
                                .padding()
                                .background(Circle().fill(Color.blue))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                        }
                        .padding()
                    }
                }
            )
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                // Settings sheet
                FreeDumpSettingsView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNewNote) {
                // New note sheet
                DumpInputView { note in
                    if let note = note {
                        modelContext.insert(note)
                        selectedNote = note
                    }
                    showNewNote = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedNote) { note in
                // Note detail sheet
                DumpDetailView(note: note)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Delete Note", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { 
                    noteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        modelContext.delete(note)
                    }
                    noteToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this note?")
            }
        }
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "square.and.pencil.circle")
                .font(.system(size: 72))
                .foregroundColor(.gray)
            
            Text("No notes yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap the button below to create your first note.\nAI will help organize your thoughts.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button {
                showNewNote = true
            } label: {
                Text("Create Note")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.blue))
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // Search bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search notes...", text: $searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // Note list item
    private func noteListItem(_ note: DumpNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if note.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 4)
                }
                
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Date display
                Text(formattedDate(note.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Preview of content
            Text(note.structuredContent.isEmpty ? note.rawContent : note.structuredContent)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Tags
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(note.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // Format date
    private func formattedDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// Preview provider
#Preview {
    FreeDumpView(showFreeDump: .constant(true), currentThread: .constant(nil))
        .environmentObject(AppManager())
        .modelContainer(for: DumpNote.self, inMemory: true)
        .environment(LLMEvaluator())
} 