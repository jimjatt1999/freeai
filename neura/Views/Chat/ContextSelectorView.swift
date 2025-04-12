//
//  ContextSelectorView.swift
//  free ai
//
//  Created by [Your Name or Placeholder] on [Date]
//

import SwiftUI
import SwiftData

// --- NEW: Calendar Range Enum ---
enum CalendarRangeOption: Identifiable, CaseIterable {
    case today, week, month
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .today: "Today"
        case .week: "Next 7 Days"
        case .month: "This Month"
        }
    }
    
    var fetchParams: (range: Calendar.Component, value: Int) {
        switch self {
        case .today: return (.day, 1)
        case .week: return (.day, 7)
        case .month: return (.month, 1)
        }
    }
}
// --- END NEW ---

struct ContextSelectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appManager: AppManager // To access tint color etc.

    // Bindings to update ChatView state
    @Binding var activeContextDescription: String?
    @Binding var selectedNoteIDs: Set<UUID>
    @Binding var useContextType: ContextType? // Use global enum
    // --- Add Binding for Calendar Params --- 
    @Binding var calendarFetchParams: (range: Calendar.Component, value: Int)?
    // --- End Add Binding --- 

    // State for this view
    @State private var selectionMode: ContextSelectionMode = .chooseType
    @State private var notes: [DumpNote] = [] // Fetched notes
    @State private var initiallySelectedNoteIDs: Set<UUID> = [] // Track initial state for cancel

    // --- Filter State ---
    @State private var selectedDateFilter: DateFilterType = .all
    @State private var selectedTagFilter: String? = nil
    @State private var availableTags: [String] = []

    private enum DateFilterType: String, CaseIterable, Identifiable {
        case all = "All Time"
        case today = "Today"
        case last7Days = "Last 7 Days"
        var id: String { self.rawValue }
    }
    // --- End Filter State ---

    // Extend selection modes
    private enum ContextSelectionMode { case chooseType, selectNotes, chooseCalendarRange }

    // Fetch descriptor for notes (sorted by timestamp)
    private var notesFetchDescriptor: FetchDescriptor<DumpNote> {
        var descriptor = FetchDescriptor<DumpNote>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        // Could add search/filter here later if needed
        return descriptor
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch selectionMode {
                case .chooseType:
                    chooseContextTypeView
                case .selectNotes:
                    noteSelectionListView
                // --- Add Calendar Range Case --- 
                case .chooseCalendarRange:
                    chooseCalendarRangeView
                // --- End Calendar Range Case --- 
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarButton
                }
            }
            .onAppear(perform: loadData)
            #if !os(visionOS)
            .tint(appManager.appTintColor.getColor()) // Apply tint
            #endif
        }
    }

    // MARK: - Subviews

    private var chooseContextTypeView: some View {
        List {
            Section("Choose Context Type") {
                Button {
                    prepareAndDismiss(type: .reminders)
                } label: {
                    Label("Add Reminder Context", systemImage: "list.bullet.clipboard")
                }
                
                // --- Add Calendar Button --- 
                Button {
                    // Switch to calendar range selection mode
                    selectionMode = .chooseCalendarRange
                    // prepareAndDismiss(type: .calendar) // Old behavior removed
                } label: {
                    Label("Add Calendar Context", systemImage: "calendar")
                }
                .disabled(!appManager.calendarAccessEnabled)
                
                Button {
                    initiallySelectedNoteIDs = selectedNoteIDs // Store initial state
                    selectionMode = .selectNotes // Switch to note selection
                } label: {
                    Label("Select Notes for Context", systemImage: "note.text")
                }
            }
        }
    }

    // --- NEW: View for Calendar Range Selection --- 
    private var chooseCalendarRangeView: some View {
        List {
            Section("Select Calendar Range") {
                ForEach(CalendarRangeOption.allCases) { option in
                     Button {
                         prepareAndDismiss(type: .calendar, rangeOption: option)
                     } label: {
                         Text(option.displayName)
                     }
                }
            }
        }
    }
    // --- END NEW ---

    private var noteSelectionListView: some View {
        VStack(spacing: 0) {
            // --- Filter Controls ---
            HStack {
                Picker("Date", selection: $selectedDateFilter) {
                    ForEach(DateFilterType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if !availableTags.isEmpty {
                    Menu {
                        Button("All Tags") { selectedTagFilter = nil }
                        Divider()
                        ForEach(availableTags, id: \.self) { tag in
                            Button(tag) { selectedTagFilter = tag }
                        }
                    } label: {
                        Text(selectedTagFilter ?? "All Tags")
                            .lineLimit(1)
                        Image(systemName: "tag")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
            // --- End Filter Controls ---

            List(filteredNotes) { note in // Use computed property
                HStack {
                    VStack(alignment: .leading) {
                        let formattedDate = shortDateFormatter.string(from: note.timestamp)
                        Text(note.title.isEmpty ? "Note @ \(formattedDate)" : note.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(note.rawContent)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: selectedNoteIDs.contains(note.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedNoteIDs.contains(note.id) ? appManager.appTintColor.getColor() : .secondary)
                        .font(.title2)
                }
                .contentShape(Rectangle()) // Make entire row tappable
                .onTapGesture {
                    toggleNoteSelection(note.id)
                }
            }
            .listStyle(.plain) // Cleaner list style
        }
    }

    // MARK: - Toolbar Logic

    private var navigationTitle: String {
        switch selectionMode {
        case .chooseType: "Add Context"
        case .selectNotes: "Select Notes (\(selectedNoteIDs.count))"
        // --- Add Calendar Range Title --- 
        case .chooseCalendarRange: "Select Range"
        // --- End Calendar Range Title --- 
        }
    }

    @ViewBuilder
    private var leadingToolbarButton: some View {
        switch selectionMode {
        case .chooseType:
            Button("Cancel") { dismiss() }
        // --- Add Calendar Range Back Button --- 
        case .selectNotes, .chooseCalendarRange:
            Button { // Back to type selection
                // selectedNoteIDs = initiallySelectedNoteIDs // Only needed for notes
                selectionMode = .chooseType
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
        // --- End Calendar Range Back Button --- 
        }
    }

    @ViewBuilder
    private var trailingToolbarButton: some View {
        switch selectionMode {
        case .chooseType:
            EmptyView() // No trailing button needed here
        case .selectNotes:
            Button("Done") {
                prepareAndDismiss(type: .notes)
            }
            .disabled(selectedNoteIDs.isEmpty) // Disable if no notes selected
        // --- Add Calendar Range Case --- 
        case .chooseCalendarRange:
            EmptyView() // No trailing button needed when selecting range
        // --- End Calendar Range Case --- 
        }
    }

    // MARK: - Helper Functions

    private func loadData() {
        // Fetch notes when view appears (or specifically when switching to .selectNotes)
        do {
            notes = try modelContext.fetch(notesFetchDescriptor)
        } catch {
            print("Error fetching notes for context selection: \(error)")
            notes = []
        }
        // Extract available tags from fetched notes
        let allTags = notes.flatMap { $0.tags }
        availableTags = Array(Set(allTags)).sorted() // Get unique sorted tags
        // Reset selection mode on reappear unless notes are already selected
        if selectedNoteIDs.isEmpty && useContextType != .notes {
             selectionMode = .chooseType
        } else if !selectedNoteIDs.isEmpty && useContextType == .notes {
            selectionMode = .selectNotes // Stay in note selection if notes were previously selected
        }
         else {
            selectionMode = .chooseType
        }
    }

    private func toggleNoteSelection(_ noteID: UUID) {
        if selectedNoteIDs.contains(noteID) {
            selectedNoteIDs.remove(noteID)
        } else {
            selectedNoteIDs.insert(noteID)
        }
    }

    private func prepareAndDismiss(type: ContextType, rangeOption: CalendarRangeOption? = nil) {
        useContextType = type
        switch type {
        case .reminders:
            activeContextDescription = "Reminders" // Simple description
            selectedNoteIDs = [] // Ensure notes are cleared if reminders chosen
        case .notes:
            if selectedNoteIDs.isEmpty {
                activeContextDescription = nil // Should not happen due to Done button disable logic
                useContextType = nil
            } else if selectedNoteIDs.count == 1 {
                activeContextDescription = "1 Note"
            } else {
                activeContextDescription = "\(selectedNoteIDs.count) Notes"
            }
        case .calendar:
            guard let option = rangeOption else { 
                // This shouldn't happen if called correctly from chooseCalendarRangeView
                print("Error: Calendar context chosen without specifying range.")
                dismiss()
                return 
            }
            activeContextDescription = "Calendar (\(option.displayName))"
            calendarFetchParams = option.fetchParams // Set the fetch params
            selectedNoteIDs = [] // Ensure notes are cleared
        }
        dismiss()
    }

    // Date formatter for note titles without a specific title
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    // --- Computed Filtered Notes ---
    private var filteredNotes: [DumpNote] {
        var currentlyFiltered = notes

        // Apply Date Filter
        switch selectedDateFilter {
        case .today:
            let startOfToday = Calendar.current.startOfDay(for: Date())
            currentlyFiltered = currentlyFiltered.filter { $0.timestamp >= startOfToday }
        case .last7Days:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let startOfSevenDaysAgo = Calendar.current.startOfDay(for: sevenDaysAgo)
            currentlyFiltered = currentlyFiltered.filter { $0.timestamp >= startOfSevenDaysAgo }
        case .all:
            break // No date filtering needed
        }

        // Apply Tag Filter
        if let tag = selectedTagFilter {
            currentlyFiltered = currentlyFiltered.filter { $0.tags.contains(tag) }
        }

        return currentlyFiltered
    }
}

// --- Preview ---
//#Preview {
//    // Need to provide bindings and environment objects for preview
//    // This might require a wrapper view
//    ContextSelectorView(
//        activeContextDescription: .constant(nil),
//        selectedNoteIDs: .constant(Set()),
//        useContextType: .constant(nil)
//    )
//    .environmentObject(AppManager()) // Add mock AppManager if needed
//    // Add mock modelContext for preview if necessary
//} 