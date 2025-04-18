//
//  FreeDumpView.swift
//  free ai
//
//  Created by AI Assistant on 5/20/24.
//

import SwiftUI
import SwiftData
import MarkdownUI
import AVKit // Import AVKit for audio playback

// Add NoteTypeFilter Enum
enum NoteTypeFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case audio = "Audio"
}

struct NotesView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Query private var dumpNotes: [DumpNote]
    
    @Binding var showNotes: Bool
    @Binding var currentThread: Thread?
    
    @State private var showNewTextNoteSheet = false
    @State private var showNewAudioNoteSheet = false
    @State private var isFabLongPressing = false // State for animation
    @State private var searchText = ""
    @State private var selectedNote: DumpNote?
    @State private var isProcessing = false
    @State private var selectedCategoryFilter: String? = nil
    @State private var noteTypeFilter: NoteTypeFilter = .all // Add state for type filter
    @State private var showDeleteAlert = false
    @State private var noteToDelete: DumpNote? = nil
    
    // Add colorScheme environment variable
    @Environment(\.colorScheme) var colorScheme
    
    // Fix: Add explicit empty initializer for Preview accessibility
    init(showNotes: Binding<Bool>, currentThread: Binding<Thread?>) {
        _showNotes = showNotes
        _currentThread = currentThread
        // @Query property `dumpNotes` is initialized automatically by SwiftData
    }
    
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
                let today = Date()
                let yearForWeek = calendar.component(.yearForWeekOfYear, from: today)
                let weekOfYear = calendar.component(.weekOfYear, from: today)
                
                categoryFilteredPinned = textFilteredPinned.filter { note in
                    let noteYearForWeek = calendar.component(.yearForWeekOfYear, from: note.timestamp)
                    let noteWeekOfYear = calendar.component(.weekOfYear, from: note.timestamp)
                    return noteYearForWeek == yearForWeek && noteWeekOfYear == weekOfYear
                }
                
                categoryFilteredUnpinned = textFilteredUnpinned.filter { note in
                    let noteYearForWeek = calendar.component(.yearForWeekOfYear, from: note.timestamp)
                    let noteWeekOfYear = calendar.component(.weekOfYear, from: note.timestamp)
                    return noteYearForWeek == yearForWeek && noteWeekOfYear == weekOfYear
                }
            } else if filter == "this-month" {
                // This month filter
                let calendar = Calendar.current
                let currentMonth = calendar.component(.month, from: Date())
                let currentYear = calendar.component(.year, from: Date())
                
                categoryFilteredPinned = textFilteredPinned.filter { note in
                    let noteMonth = calendar.component(.month, from: note.timestamp)
                    let noteYear = calendar.component(.year, from: note.timestamp)
                    return noteMonth == currentMonth && noteYear == currentYear
                }
                
                categoryFilteredUnpinned = textFilteredUnpinned.filter { note in
                    let noteMonth = calendar.component(.month, from: note.timestamp)
                    let noteYear = calendar.component(.year, from: note.timestamp)
                    return noteMonth == currentMonth && noteYear == currentYear
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
    
    // --- Computed properties for Display (Derived from filteredNotes) --- 
    private var pinnedNotesForDisplay: [DumpNote] {
        filteredNotes.filter { $0.isPinned }
    }
    
    private var otherNotesForDisplay: [DumpNote] {
        filteredNotes.filter { !$0.isPinned }
    }
    
    // Helper function for type filtering
    private func filterByType(_ note: DumpNote) -> Bool {
        switch noteTypeFilter {
            case .all: return true
            case .text: return note.audioFilename == nil
            case .audio: return note.audioFilename != nil
        }
    }
    // --- End Computed Properties ---
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header - Removed ScrollView wrapper
                ZStack {
                    // Places settings button in the top-right
                    HStack {
                        Spacer()
                    }
                    .padding()
                    
                    // Exactly centered eyes or title
                    if appManager.showNeuraEyes {
                         NeuraEyesView(isGenerating: false) // No easy generating state here
                             .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else {
                         Text("Notes")
                             .font(.title)
                             .fontWeight(.bold)
                    }
                }
                .padding(.bottom, 10) // Add padding below the header

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
                            // --- Add Type Filters --- 
                            typeFilterChip(label: "All", filter: .all)
                            typeFilterChip(label: "Text", filter: .text)
                            typeFilterChip(label: "Audio", filter: .audio)
                            Divider().padding(.horizontal, 4)
                            // --- End Type Filters ---
                            
                            // Date filters
                            filterChip(label: "Today", filterValue: "today")
                            filterChip(label: "This Week", filterValue: "this-week")
                            filterChip(label: "This Month", filterValue: "this-month")
                            
                            // Category filters
                            ForEach(availableCategories, id: \.self) { category in
                                filterChip(label: category.capitalized, filterValue: category)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 35)
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
                            } else if filter == "this-month" {
                                Text("Showing \(filteredNotes.count) notes from this month")
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
                                    .foregroundColor(appManager.appTintColor.getColor())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Main content grid
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) { 
                            // Only show notes if the filter result is not empty
                            if !filteredNotes.isEmpty {
                                // Pinned section
                                if !pinnedNotesForDisplay.isEmpty {
                                    Text("PINNED")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading)
                                        
                                    LazyVGrid(columns: gridColumns, spacing: 16) {
                                        ForEach(pinnedNotesForDisplay) { note in
                                            NoteCardView(note: note)
                                                .onTapGesture { selectedNote = note }
                                                .contextMenu {
                                                    Button { 
                                                        note.isPinned.toggle() 
                                                        try? modelContext.save()
                                                    } label: {
                                                        Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                                                    }
                                                    
                                                    Button { selectedNote = note } label: {
                                                        Label("Edit", systemImage: "pencil")
                                                    }

                                                    Divider()
                                                    
                                                    Button(role: .destructive) {
                                                        noteToDelete = note
                                                        showDeleteAlert = true
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Others section
                                if !otherNotesForDisplay.isEmpty {
                                    // Add separator only if pinned notes also exist
                                    if !pinnedNotesForDisplay.isEmpty {
                                        Divider().padding(.horizontal)
                                    }
                                    
                                    Text(pinnedNotesForDisplay.isEmpty ? "NOTES" : "OTHERS") // Adjust title
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading)
                                        
                                    LazyVGrid(columns: gridColumns, spacing: 16) {
                                        ForEach(otherNotesForDisplay) { note in
                                            NoteCardView(note: note)
                                                .onTapGesture { selectedNote = note }
                                                .contextMenu {
                                                    Button { 
                                                        note.isPinned.toggle() 
                                                        try? modelContext.save()
                                                    } label: {
                                                        Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                                                    }
                                                    
                                                    Button { selectedNote = note } label: {
                                                        Label("Edit", systemImage: "pencil")
                                                    }
                                                    
                                                    Divider()

                                                    Button(role: .destructive) {
                                                        noteToDelete = note
                                                        showDeleteAlert = true
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } else { // Show "No notes match" only if a filter is active or search text exists
                                if !searchText.isEmpty || selectedCategoryFilter != nil {
                                    VStack {
                                        Spacer(minLength: 100)
                                        Text("No notes match your filter.")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                // Note: The case for "No notes yet." is handled by the initial `if dumpNotes.isEmpty` check earlier.
                            }
                        }
                        .padding(.vertical) // Keep vertical padding for inner content
                    }
                    .padding(.bottom, 60) // Add padding to the ScrollView itself
                }
            }
            .navigationBarHidden(true)
            // Add FAB overlay with Tap and Long Press
            .overlay(alignment: .bottomTrailing) { 
                fabButton
                    .padding(.bottom, 55) // SIGNIFICANTLY increased padding to lift FAB
            }
            // Sheet for Text Notes
            .sheet(isPresented: $showNewTextNoteSheet) { 
                DumpInputView { note in
                    if let note = note {
                        selectedNote = note // Select on completion
                    }
                    showNewTextNoteSheet = false // Dismiss
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            // Sheet for Audio Notes (NEW)
            .sheet(isPresented: $showNewAudioNoteSheet) { 
                AudioInputView { note in // Present the new view
                     if let note = note {
                         selectedNote = note // Select on completion
                     }
                     showNewAudioNoteSheet = false // Dismiss
                 }
                 .presentationDetents([.fraction(0.45), .medium]) // Increased fraction slightly and added medium
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
        .onAppear {
            // No need to assign filteredNotes here, computed property handles it
            // filteredNotes = dumpNotes
            createSampleNotesIfNeeded() // Call the new function
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
                showNewTextNoteSheet = true
            } label: {
                Text("Create Note")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(appManager.appTintColor.getColor()))
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
    
    // --- Filter Chip Helper View ---
    private func filterChip(label: String, filterValue: String?) -> some View {
        // --- Add isSelected definition --- 
        let isSelected = selectedCategoryFilter == filterValue
        // --- End isSelected definition ---
        
        return Button {
            withAnimation {
                if selectedCategoryFilter == filterValue {
                    selectedCategoryFilter = nil
                } else {
                    selectedCategoryFilter = filterValue
                }
            }
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? selectedChipBackgroundColor : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? selectedChipForegroundColor : .primary)
        }
        .buttonStyle(.plain)
    }
    // --- End Filter Chip Helper View ---
    
    // --- Helper computed properties for filterChip colors --- 
    private var selectedChipBackgroundColor: Color {
        // --- Add return --- 
        return colorScheme == .dark ? Color.gray : appManager.appTintColor.getColor()
    }
    
    private var selectedChipForegroundColor: Color {
         // --- Add return --- 
        return colorScheme == .dark ? Color.white : Color.white // Keep white text for both light/dark selected
    }
    // --- End Helper computed properties ---
    
    // --- NEW: Grid Columns Definition ---
    private var gridColumns: [GridItem] {
        // Adjust number of columns based on horizontal size class
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [GridItem(.adaptive(minimum: 200), spacing: 16)]
        } else {
            // On phone, check horizontal size class
            if horizontalSizeClass == .regular {
                return [GridItem(.adaptive(minimum: 200), spacing: 16)] // Wider layout for landscape/split view
            } else {
                return [GridItem(.flexible(minimum: 150), spacing: 16), GridItem(.flexible(minimum: 150), spacing: 16)] // 2 columns for compact width
            }
        }
        #elseif os(macOS)
        // More flexible columns on macOS
        return [GridItem(.adaptive(minimum: 200), spacing: 16)]
        #else // visionOS etc.
        return [GridItem(.adaptive(minimum: 200), spacing: 16)]
        #endif
    }
    
    #if os(iOS)
    // Access horizontal size class for adaptive columns on iPhone
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    #endif
    // --- End Grid Columns Definition ---
    
    // --- NEW: Note Card Item View ---
    private func noteCardItem(_ note: DumpNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.headline)
                    .lineLimit(2) // Allow slightly more space for title
                
                Spacer()
                
                if note.isPinned as? Bool ?? false {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            Text(note.structuredContent.isEmpty ? note.rawContent : note.structuredContent)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(5) // Show more content preview
                .frame(maxWidth: .infinity, alignment: .leading) // Ensure text takes width
            
            Spacer() // Push tags to bottom
            
            if !note.tags.isEmpty {
                // Simplified tag display for card
                HStack {
                    ForEach(note.tags.prefix(3), id: \.self) { tag in // Show max 3 tags
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                            .lineLimit(1)
                    }
                    if note.tags.count > 3 {
                        Text("+\(note.tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground)) // Card background
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    // --- End Note Card Item View ---
    
    // --- Updated FAB View with Animation --- 
    private var fabButton: some View {
        // --- Calculate FAB color based on colorScheme --- 
        let fabColor = colorScheme == .dark ? Color.gray : appManager.appTintColor.getColor()
        // --- End FAB color calculation ---
        
        return Image(systemName: isFabLongPressing ? "waveform" : "plus") // Change icon during press
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(.white)
            .padding()
            .background(
                Circle()
                    .fill(fabColor) // Use calculated color
                    // Optional: Pulse effect during press
                    .scaleEffect(isFabLongPressing ? 1.15 : 1.0)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            .padding() // Padding around the FAB
            .onTapGesture { // Keep simple tap
                print("FAB Tapped - Show Text Note")
                showNewAudioNoteSheet = false 
                showNewTextNoteSheet = true 
            }
            .onLongPressGesture(minimumDuration: 0.4, perform: { // Actions on press START
                isFabLongPressing = true
                appManager.playHaptic() 
                print("FAB Long Press Started")
            }, onPressingChanged: { isPressing in // Actions on press END/CANCEL
                 if !isPressing { // When finger is lifted
                     print("FAB Long Press Ended - Show Audio Note")
                     showNewTextNoteSheet = false
                     showNewAudioNoteSheet = true
                     isFabLongPressing = false // Reset state AFTER showing sheet
                 }
             })
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFabLongPressing) // Animate changes
    }
    // --- End FAB View --- 
    
    // --- NEW: Type Filter Chip Helper --- 
    private func typeFilterChip(label: String, filter: NoteTypeFilter) -> some View {
        // --- Calculate selection state --- 
        let isSelected = noteTypeFilter == filter
        // --- End selection state --- 
        
        return Button {
            withAnimation {
                noteTypeFilter = filter
            }
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? selectedChipBackgroundColor : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? selectedChipForegroundColor : .primary)
        }
        .buttonStyle(.plain)
    }
    // --- End Type Filter Chip Helper ---
    
    // --- Private Functions --- 
    private func deleteNote(_ note: DumpNote) {
        modelContext.delete(note)
    }

    // --- NEW: Create Sample Notes --- 
    private func createSampleNotesIfNeeded() {
        // Check if notes already exist
        guard dumpNotes.isEmpty else { return }
        
        // Sample Note 1: App Overview
        let appOverviewContent = """
        # Welcome to Neura! Your Private AI Assistant

        Neura is designed to be your helpful companion, running entirely on your device for maximum privacy.

        ## Key Features:

        - **Chat:** Have private conversations with Neura. Your data never leaves your device.
        - **Context:** Add context to your chats! Select notes, include recent reminders, or add upcoming calendar events so Neura has relevant information.
        - **Document Upload:** Need to understand a document? Upload PDF or TXT files, and Neura can summarize them for you (tap the '+' in Chat).
        - **Reminders:** Set reminders using natural language in the Reminders tab.
        - **Daily Digest:** Get a personalized summary of your day, including calendar events and reminders (check the Home tab).
        - **Notes (This Tab!):** Jot down thoughts, ideas, or anything you need to remember. Use text or record audio.
        """ // Use dashes for lists
        let appOverviewNote = DumpNote(
            rawContent: appOverviewContent,
            title: "Welcome to Neura!",
            tags: ["welcome", "features"],
            colorTag: "blue" // Give it a color
        )
        modelContext.insert(appOverviewNote)
        
        // Sample Note 2: Using Notes
        let notesFeatureContent = """
        # How to Use Notes

        This is your space for capturing thoughts quickly.

        ## Creating Notes:

        - **Text:** Tap the '+' button to create a new text note.
        - **Audio:** Tap and **hold** the '+' button to start recording an audio note. Your speech will be automatically transcribed when you save!

        ## Processing Styles:

        When saving a text note, you can choose an AI processing style:

        - **Save Raw:** Saves your note exactly as you typed it.
        - **Simple Restructure:** AI organizes the text for better readability.
        - **Grammar Fix:** AI corrects grammar and spelling.
        - **Journal Entry:** AI formats the text as a journal entry.
        - **Detailed Summary:** AI creates a structured summary.

        You can set the default style in Notes Settings (gear icon). You can also reprocess notes later by editing them.

        ## Other Features:

        - **Tags:** Add tags to organize your notes.
        - **Color:** Assign colors to notes for visual cues.
        - **Pin:** Pin important notes to the top.
        """ // Use dashes for lists
        let notesFeatureNote = DumpNote(
            rawContent: notesFeatureContent,
            title: "Using the Notes Feature",
            tags: ["notes", "guide", "audio", "processing"],
            colorTag: "green" // Give it a color
        )
        modelContext.insert(notesFeatureNote)

        // --- ADD NEW SAMPLE NOTES --- 

        // Sample Note 3: Neura Eyes
        let neuraEyesContent = """
        # Meet Neura's Eyes!

        Those expressive eyes aren't just for show! They provide visual feedback and add a touch of personality.

        ## What They Do:
        - **Idle:** Look around randomly, blink.
        - **Thinking/Generating:** Show an animation (thinking indicator or glow) while processing your requests.
        - **Listening:** (Subtle animation when implemented)
        - **Tap:** React when you tap them (try it!).

        ## Customization:
        Head over to **Settings > Neura Eyes** to:
        - Change their **Shape** (Circle, Oval, Square).
        - Pick **Outline** and **Iris Colors**.
        - Adjust **Background Color** (or set to Adaptive).
        - Change **Iris Size** and **Stroke Width**.
        - Select the **Tap Action**.
        - Choose the **Generation Animation** (Thinking Indicator or Glow).
        - Toggle the **Border** on/off.
        """
        let neuraEyesNote = DumpNote(
            rawContent: neuraEyesContent,
            title: "Customizing Neura Eyes",
            tags: ["guide", "settings", "eyes", "customization"],
            colorTag: "purple"
        )
        modelContext.insert(neuraEyesNote)

        // Sample Note 4: Chat & Themes
        let chatThemesContent = """
        # Chatting with Neura & Fun Themes

        The Chat tab is your main space for interacting with Neura.

        ## Chat Features:
        - **Context:** Use the '+' button to add context from Notes, Reminders, Calendar, or uploaded Documents.
        - **Privacy:** All conversations happen locally.

        ## Interface Styles (Settings > Chat):
        Want a different look? Try the **Terminal Interface Style**!
        - **Enable:** Toggle it on in Chat settings.
        - **Themes:** Choose from various color schemes like Classic Green, Amber, Matrix, Futuristic, or even a retro **Game Boy Screen**!
        - **Effects:** Add scanlines, flicker, and window controls for extra nostalgia.
        
        *(Note: Daily Digest on the Home tab also has its own separate Terminal Style settings)*
        """
        let chatThemesNote = DumpNote(
            rawContent: chatThemesContent,
            title: "Chat Features & Themes",
            tags: ["guide", "chat", "settings", "themes", "terminal"],
            colorTag: "orange"
        )
        modelContext.insert(chatThemesNote)

        // Sample Note 5: Gamification
        let gamificationContent = """
        # Level Up with Neura! (Gamification)
        
        Neura includes a simple XP (Experience Points) system to make interacting a bit more fun.
        
        ## Earning XP:
        You earn points for actions like:
        - Chatting with Neura.
        - Completing reminders.
        - Saving notes.
        - Generating the Daily Digest.
        
        ## Levels:
        Every 100 XP, you gain a level! It's just for fun, a way to track your engagement.
        
        ## Settings (Settings > Gamification):
        - **Enable/Disable:** Turn the XP system on or off entirely.
        - **Show in UI:** Choose whether to display your Level and XP progress bar at the top of some screens (like Home).
        - **Reset:** Reset your XP and level back to zero.
        """
        let gamificationNote = DumpNote(
            rawContent: gamificationContent,
            title: "Gamification: Earn XP!",
            tags: ["guide", "settings", "gamification", "xp"],
            colorTag: "yellow"
        )
        modelContext.insert(gamificationNote)
        // --- END ADD NEW SAMPLE NOTES --- 

        print("Created sample notes.")
    }
    // --- END NEW ---
}

#Preview {
    // Ensure the required bindings are provided correctly
    @State var showNotes = true
    @State var thread: Thread? = nil
    
    // Make sure initializer matches the one in NotesView
    return NotesView(showNotes: $showNotes, currentThread: $thread) 
        .environmentObject(AppManager())
        .modelContainer(for: DumpNote.self, inMemory: true)
        .environment(LLMEvaluator())
}

// --- Rename ContentCard View to NoteCardView --- 
struct NoteCardView: View { // Renamed struct
    @Environment(\.modelContext) var modelContext // Needed to save pin changes
    let note: DumpNote
    
    // --- NEW: Audio Playback State ---
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0 // 0.0 to 1.0
    @State private var progressTimer: Timer? = nil
    // --- End Audio Playback State ---
    
    // Define a fixed height for consistency
    private let cardHeight: CGFloat = 180 

    // Map color tag string to Color
    private var cardBackgroundColor: Color {
        switch note.colorTag?.lowercased() {
            case "red": return Color.red.opacity(0.2)
            case "blue": return Color.blue.opacity(0.2)
            case "green": return Color.green.opacity(0.2)
            case "yellow": return Color.yellow.opacity(0.2)
            case "purple": return Color.purple.opacity(0.2)
            // Add more colors or hex parsing later
            default: return Color(.secondarySystemBackground)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { // Increased spacing from 8 to 10
            // --- Link Preview (Top, if available) --- 
            if let imageURLString = note.linkImageURL, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        EmptyView() // Don't show broken image icon
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.1)) // Placeholder
                    }
                }
                .frame(height: cardHeight * 0.4) // Adjust image height ratio
                .clipped() // Clip the image within the card bounds
            }
            
            // Use a separate VStack for text content + Spacer
            VStack(alignment: .leading, spacing: 4) { 
                // Title (if exists)
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(2)
                        .padding(.top, 6) // Added top padding to push title down
                }
                
                // Content (Show structured if available, else raw)
                // Reduce line limit if image is shown
                let contentLineLimit = (note.linkImageURL != nil) ? 2 : 4
                let contentToShow = note.structuredContent.isEmpty ? note.rawContent : note.structuredContent
                Text(contentToShow)
                    .font(.subheadline)
                    .lineLimit(contentLineLimit)
                    .padding(.top, note.title.isEmpty ? 0 : 4) // Adjust top padding
                    
                Spacer(minLength: 0) // Pushes content up within this VStack
                
                // --- Link Title & Domain (Bottom, if available) ---
                if let linkTitle = note.linkTitle, let linkURLString = note.linkURL, let url = URL(string: linkURLString) {
                    VStack(alignment: .leading, spacing: 2) {
                         Text(linkTitle)
                             .font(.caption.weight(.medium))
                             .lineLimit(1)
                         Text(url.host ?? url.absoluteString)
                             .font(.caption2)
                             .foregroundColor(.secondary)
                             .lineLimit(1)
                    }
                    .padding(.top, 6)
                }
            }
            .padding([.horizontal, .bottom], 12) // Padding for text content
            .padding(.top, note.linkImageURL != nil ? 8 : 12) // Adjust top based on image
            
            // --- NEW: Audio Playback Controls --- 
            if let filename = note.audioFilename {
                Divider().padding(.horizontal, 10)
                HStack {
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 10)
                    
                    // Simple Progress Bar (Optional)
                     GeometryReader { geometry in
                         ZStack(alignment: .leading) {
                             Rectangle()
                                 .fill(Color.gray.opacity(0.3))
                                 .frame(height: 4)
                             Rectangle()
                                 .fill(Color.accentColor)
                                 .frame(width: geometry.size.width * playbackProgress, height: 4)
                         }
                         .clipShape(Capsule())
                         .frame(height: 10)
                         .gesture(DragGesture(minimumDistance: 0)
                            .onChanged({ value in seekAudio(to: value.location.x / geometry.size.width) })
                         ) // Allow seeking
                     }
                     .frame(height: 10)
                    
                    Spacer()
                    // Optionally display duration/elapsed time
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6) // Reduced vertical padding from 8 to 6
            }
            // --- End Audio Playback Controls ---
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        .onDisappear(perform: stopAudio) // Stop playback when view disappears
    }
    
    // --- NEW: Audio Playback Functions --- 
    private func togglePlayback() {
        if isPlaying {
            stopAudio()
        } else {
            playAudio()
        }
    }

    private func getAudioFileURL(filename: String) -> URL? {
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentPath.appendingPathComponent(filename)
    }

    private func playAudio() {
        guard let filename = note.audioFilename, 
              let url = getAudioFileURL(filename: filename) else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = makeCoordinator()
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            startProgressTimer()
        } catch {
            print("Error playing audio: \(error)")
            stopAudio() // Clean up on error
        }
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        stopProgressTimer()
        playbackProgress = 0 // Reset progress
        // Deactivate session (optional - might interfere with other audio)
        // try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func seekAudio(to progress: Double) {
        guard let player = audioPlayer else { return }
        let clampedProgress = max(0, min(1, progress)) // Ensure 0-1 range
        let time = player.duration * clampedProgress
        player.currentTime = time
        playbackProgress = clampedProgress // Update UI immediately
    }
    
    // Timer for progress bar
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = audioPlayer, player.isPlaying else {
                stopProgressTimer()
                return
            }
            playbackProgress = player.currentTime / player.duration
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // Delegate handling (needed for didFinishPlaying)
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AVAudioPlayerDelegate {
        var parent: NoteCardView

        init(_ parent: NoteCardView) {
            self.parent = parent
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            parent.stopAudio()
            print("Audio finished playing")
        }
    }
    // --- End Audio Playback Functions ---
}
// --- End NoteCardView --- 
