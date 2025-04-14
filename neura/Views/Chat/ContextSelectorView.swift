//
//  ContextSelectorView.swift
//  free ai
//
//  Created by [Your Name or Placeholder] on [Date]
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

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

// --- NEW: Document Processing State ---
internal enum DocumentProcessingState: Equatable {
    case idle
    case loading
    case chunking
    case summarizing
    case finalizing
    case complete
    case error(String)
    
    static func == (lhs: DocumentProcessingState, rhs: DocumentProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.chunking, .chunking),
             (.summarizing, .summarizing),
             (.finalizing, .finalizing),
             (.complete, .complete):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
// --- END NEW ---

// Shimmering Text Modifier
struct ShimmeringText: ViewModifier {
    @State private var phase: CGFloat = 0
    var speed: Double = 0.5 // Control shimmer speed
    var delay: Double = 0 // Control delay between loops

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: phase - 0.5),
                        .init(color: Color.black.opacity(0.4), location: phase),
                        .init(color: .clear, location: phase + 0.5)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: speed)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    phase = 1.0
                }
            }
    }
}

struct ContextSelectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appManager: AppManager // To access tint color etc.
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL
    @Environment(LLMEvaluator.self) var llm // Add LLM service
    
    // Reference to parent view
    // var parent: AnyObject? // REMOVE THIS

    // Bindings to update ChatView state
    @Binding var activeContextDescription: String?
    @Binding var selectedNoteIDs: Set<UUID>
    @Binding var useContextType: ChatContextType? // Use global enum
    // --- Add Binding for Calendar Params --- 
    @Binding var calendarFetchParams: (range: Calendar.Component, value: Int)?
    @Binding var documentSummaryBinding: String // ADD THIS
    // --- End Add Binding --- 

    // State for this view
    @State private var selectionMode: ContextSelectionMode = .chooseType
    @State private var notes: [DumpNote] = [] // Fetched notes
    @State private var initiallySelectedNoteIDs: Set<UUID> = [] // Track initial state for cancel
    @State private var showCopyConfirmation = false // State for copy confirmation
    @State private var isCancelled = false // State for cancellation
    @State private var dotCount = 0 // State for animated dots
    
    let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    // --- NEW: Document Upload State ---
    @State private var isDocumentPickerPresented = false
    @State private var documentProcessingState: DocumentProcessingState = .idle
    @State private var documentTitle: String = ""
    @State private var documentSummary: String = ""
    @State private var processingProgress: Double = 0.0
    // --- END NEW ---

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
    private enum ContextSelectionMode { 
        case chooseType, selectNotes, chooseCalendarRange, processDocument 
    }

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
                // --- NEW: Document Processing Case ---
                case .processDocument:
                    documentProcessingView
                // --- END NEW ---
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadData)
            // --- NEW: Present Document Picker ---
            .sheet(isPresented: $isDocumentPickerPresented) {
                DocumentPicker(processState: $documentProcessingState, 
                               documentTitle: $documentTitle,
                               documentSummary: $documentSummary,
                               progress: $processingProgress,
                               isCancelled: $isCancelled)
            }
            // --- END NEW ---
            #if !os(visionOS)
            .tint(appManager.appTintColor.getColor()) // Apply tint
            #endif
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                leadingToolbarButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                trailingToolbarButton
            }
        }
        .overlay(
            Group {
                if documentProcessingState != .idle {
                    documentProcessingOverlay
                }
            }
        )
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
                
                // --- NEW: Document Upload Button ---
                Button {
                    // Present document picker
                    isDocumentPickerPresented = true
                    selectionMode = .processDocument
                } label: {
                    Label("Upload Document", systemImage: "doc.fill")
                }
                // --- END NEW ---
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
        // --- NEW: Attach toolbar directly to the note selection view ---
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    prepareAndDismiss(type: .notes)
                }
                .disabled(selectedNoteIDs.isEmpty) // Disable if no notes selected
            }
        }
        // --- END NEW ---
    }

    // --- NEW: Document Processing View ---
    private var documentProcessingView: some View {
        VStack(spacing: 20) {
            switch documentProcessingState {
            case .idle:
                VStack {
                    Text("Select a document to upload")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Button("Choose Document") {
                        isDocumentPickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Supports: PDF, TXT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
            case .loading, .chunking, .summarizing, .finalizing:
                VStack {
                    ProgressView(value: processingProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 250)
                        .padding(.bottom, 8)

                    // Single animated status line
                    Text(processingStateMessage + animatedDots)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .id(processingStateMessage + animatedDots)
                    
                    // Cancel Button
                    Button("Cancel", role: .destructive) {
                        cancelProcessing()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                }
                .transition(.opacity) // Add transition for smoother appearance
                .onReceive(dotTimer) { _ in
                    // Only update if in a processing state
                    if case .loading = documentProcessingState { dotCount += 1 }
                    else if case .chunking = documentProcessingState { dotCount += 1 }
                    else if case .summarizing = documentProcessingState { dotCount += 1 }
                    else if case .finalizing = documentProcessingState { dotCount += 1 }
                }
                
            case .complete:
                VStack(alignment: .leading) {
                    Text("Title: \(documentTitle)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                        .fixedSize(horizontal: false, vertical: true)


                    ScrollView {
                        Text( (try? AttributedString(markdown: documentSummary)) ?? AttributedString(documentSummary) )
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            .padding(.bottom)
                    }

                    Spacer()

                    // Buttons side-by-side
                    HStack {
                        Button {
                            UIPasteboard.general.string = documentSummary
                            withAnimation {
                                showCopyConfirmation = true
                            }
                            // Hide after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showCopyConfirmation = false
                                }
                            }
                        } label: {
                            Label("Copy Summary", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Use Document as Context") {
                            prepareAndDismissWithDocument()
                        }
                        // Custom Styling for prominent button
                        .buttonStyle(.bordered) // Use bordered as base
                        .background(appManager.appTintColor.getColor()) // Apply tint color background
                        .foregroundColor(Color(.systemBackground)) // Use background color for text (adapts to light/dark)
                        .cornerRadius(8) // Match bordered style corner radius
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                }
                .overlay(
                    // Copy confirmation overlay
                    Group {
                        if showCopyConfirmation {
                            Text("Summary Copied!")
                                .font(.caption)
                                .padding(8)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .offset(y: -50) // Position above buttons
                        }
                    }
                )
                
            case .error(let message):
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding(.bottom)
                    
                    Text("Error Processing Document")
                        .font(.headline)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Try Again") {
                        isDocumentPickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
            }
        }
        .padding()
        .onAppear {
            // Start animation if we're processing
            if case .loading = documentProcessingState, documentTitle.isEmpty {
                // If no document is selected yet, show picker
                isDocumentPickerPresented = true
            }
        }
    }
    
    // Helper computed properties for document processing UI
    private var processingStateMessage: String {
        switch documentProcessingState {
        case .loading:
            return "Preparing your document..."
        case .chunking:
            return "Organizing thoughts..."
        case .summarizing:
            return "Distilling the essence..."
        case .finalizing:
            return "Adding the final touches..."
        default:
            return "Neura is working..."
        }
    }

    // Animated dots for loading states
    private var animatedDots: String {
        let baseCount = dotCount % 3
        let dots = String(repeating: ".", count: baseCount + 1)
        return dots
    }

    // MARK: - Toolbar Logic

    private var navigationTitle: String {
        switch selectionMode {
        case .chooseType: "Add Context"
        case .selectNotes: "Select Notes (\(selectedNoteIDs.count))"
        // --- Add Calendar Range Title --- 
        case .chooseCalendarRange: "Select Range"
        // --- End Calendar Range Title --- 
        case .processDocument: "Process Document"
        }
    }

    @ViewBuilder
    private var leadingToolbarButton: some View {
        switch selectionMode {
        case .chooseType:
            Button("Cancel") { dismiss() }
        // --- Add Calendar Range Back Button --- 
        case .selectNotes, .chooseCalendarRange, .processDocument:
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
            EmptyView() // Done button is handled by the list view's toolbar now
        case .chooseCalendarRange:
            EmptyView() // No trailing button needed when selecting range
        case .processDocument:
            EmptyView() // No trailing button needed when processing document
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
        if selectedNoteIDs.isEmpty && useContextType != ChatContextType.notes {
             selectionMode = .chooseType
        } else if !selectedNoteIDs.isEmpty && useContextType == ChatContextType.notes {
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

    private func prepareAndDismiss(type: ChatContextType, rangeOption: CalendarRangeOption? = nil) {
        useContextType = type
        switch type {
        case .reminders:
            print("Preparing Reminder Context...")
            activeContextDescription = "Active Reminders" // More descriptive
            selectedNoteIDs = [] // Ensure notes are cleared if reminders chosen
            calendarFetchParams = nil // Clear calendar params
        case .notes:
            if selectedNoteIDs.isEmpty {
                activeContextDescription = nil // Should not happen due to Done button disable logic
                useContextType = nil
            } else if selectedNoteIDs.count == 1 {
                // Find the note title if possible
                if let selectedNote = notes.first(where: { selectedNoteIDs.contains($0.id) }) {
                    let title = selectedNote.title.isEmpty ? "Untitled note" : selectedNote.title
                    activeContextDescription = title.prefix(20).description // Limit length
                } else {
                    activeContextDescription = "1 Note"
                }
            } else {
                activeContextDescription = "\(selectedNoteIDs.count) Notes"
            }
            calendarFetchParams = nil // Clear calendar params
        case .calendar:
            guard let option = rangeOption else { 
                // This shouldn't happen if called correctly from chooseCalendarRangeView
                print("Error: Calendar context chosen without specifying range.")
                dismiss()
                return 
            }
            activeContextDescription = option.displayName // Just use the display name
            calendarFetchParams = option.fetchParams // Set the fetch params
            print("Calendar context set - range: \(option.fetchParams.range), value: \(option.fetchParams.value)")
            selectedNoteIDs = [] // Ensure notes are cleared
        case .document:
            prepareAndDismissWithDocument()
        }
        dismiss()
    }

    private func cancelProcessing() {
        print("Cancellation requested.")
        isCancelled = true 
        documentProcessingState = .idle // Reset state
        documentTitle = "" // Clear potentially partial data
        documentSummary = "" 
        documentSummaryBinding = "" // Clear binding
        processingProgress = 0.0
        dismiss() // Close the view
    }

    private func prepareAndDismissWithDocument() {
        // Pass document context back to ChatView
        useContextType = ChatContextType.document
        activeContextDescription = documentTitle.isEmpty ? "Untitled Document" : documentTitle
        selectedNoteIDs = []
        calendarFetchParams = nil
        
        // Update document bindings if available
        documentSummaryBinding = documentSummary
        
        // Reset processing state but keep summary and title
        documentProcessingState = .idle
        processingProgress = 0.0
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

    // --- NEW ---
    private var documentProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack {
                documentProcessingView
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    .padding(.horizontal)
                    .shadow(radius: 8)
            }
        }
    }
    // --- END NEW ---
}
