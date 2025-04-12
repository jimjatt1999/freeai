import SwiftUI
import SwiftData
import MarkdownUI

// Enum to represent the digest time range options
enum DigestRange: String, CaseIterable, Identifiable {
    case day = "Today"
    case week = "Week"
    case month = "Month"
    
    var id: String { self.rawValue }
    
    var fetchParams: (range: Calendar.Component, value: Int) {
        switch self {
        case .day: return (.day, 1)
        case .week: return (.day, 7)
        case .month: return (.month, 1)
        }
    }
}

struct DailyDigestView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm

    // State for each section
    @State private var discoverContent: String? = nil // Renamed from randomFact
    @State private var digestSummary: String? = nil   // NEW: Stores the LLM summary
    
    // Overall state
    @State private var isGenerating: Bool = false
    @State private var selectedRange: DigestRange = .day // Default range

    // State to show Settings sheet
    @State private var showSettingsSheet = false

    var body: some View {
        NavigationView { // Add NavigationView here since it was removed from ContentView
            VStack(spacing: 0) { // Main container
                // --- Top Bar ---
                topBarView()
                    .padding(.horizontal)
                    .padding(.top, 5) // Reduce top padding to move navigation bar closer to top
                    .background(Color(.systemBackground)) // Keep background consistent

                // --- Scrollable Content ---
                ScrollView {
                    contentView()
                        .padding(.horizontal)
                        .padding(.vertical, 15) // Add vertical padding inside scroll view
                        .frame(maxWidth: .infinity) // Ensure content takes full width
                }
                .foregroundStyle(Color.primary)

                // --- Bottom Controls ---
                bottomControlsView()
                    .padding(.horizontal)
                    .padding(.vertical, 7) // Slightly reduce vertical padding
                    .padding(.bottom, 54) // SIGNIFICANTLY increased padding below controls

            }
            .background(Color(.systemBackground))
            .foregroundColor(.primary)
            .navigationBarHidden(true) // Hide navigation bar since we're using our own top bar
        }
        .onAppear {
            loadCachedDigestIfNeeded()
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheetView()
        }
    }

    // --- Helper View Builders ---

    @ViewBuilder
    private func topBarView() -> some View {
        HStack(alignment: .center, spacing: 0) { // Use spacing 0 and add spacers
            // XP Display (Conditional)
            if appManager.showXpInUI {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(appManager.buddyLevel)")
                        .font(.caption)
                    ProgressView(
                        value: max(0, min(Float(appManager.buddyXP), Float(appManager.xpForNextLevel))), 
                        total: max(1, Float(appManager.xpForNextLevel))
                    )
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                    Text("\(appManager.xpTowardsNextLevel)/\(appManager.xpForNextLevel) XP")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .frame(width: 100, alignment: .leading) // Give slightly more space if needed
            } else {
                Spacer().frame(width: 100) // Match width when hidden
            }

            Spacer() // Pushes Eyes to center

            // Eyes
            if appManager.showNeuraEyes {
                NeuraEyesView(isGenerating: isGenerating, isThinking: isGenerating)
                    .frame(height: 50) // Keep eyes height
            } else {
                // Placeholder with title when eyes are disabled
                Text("Digest")
                    .font(.headline)
                    .foregroundColor(appManager.appTintColor.getColor())
            }

            Spacer() // Pushes Settings to right

            // Settings Button
            Button {
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(appManager.appTintColor.getColor())
                    .frame(width: 44, height: 44) // Make button tap area larger
            }
            .frame(width: 100, alignment: .trailing) // Match width for balance
        }
        .frame(height: 60) // Maintain overall top bar height
        .padding(.bottom, 10) // Add padding below the top bar
    }

    @ViewBuilder
    private func contentView() -> some View {
        VStack(alignment: .leading, spacing: 20) { // Align content left, increase spacing
            // Discover Section
            if appManager.dailyDigestShowDiscover, let content = discoverContent {
                 if appManager.dailyDigestTerminalStyleEnabled {
                     TerminalStyleWrapper(
                          colorScheme: appManager.dailyDigestColorScheme,
                          showScanlines: appManager.dailyDigestScanlinesEnabled,
                          showFlicker: appManager.dailyDigestFlickerEnabled,
                          showPixelEffect: appManager.dailyDigestPixelEffectEnabled,
                          showWindowControls: appManager.dailyDigestWindowControlsEnabled,
                          windowControlStyle: appManager.dailyDigestWindowControlsStyle,
                          title: "Discover"
                    ) {
                        discoverMarkdownView(content)
                    }
                } else {
                    // Standard view without terminal style
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discover")
                            .font(.system(.headline, design: .monospaced))
                        discoverMarkdownView(content)
                    }
                }
                Divider()
            }

            // Digest Summary Section
            if let summary = digestSummary {
                if appManager.dailyDigestTerminalStyleEnabled {
                    TerminalStyleWrapper(
                        colorScheme: appManager.dailyDigestColorScheme,
                        showScanlines: appManager.dailyDigestScanlinesEnabled,
                        showFlicker: appManager.dailyDigestFlickerEnabled,
                        showPixelEffect: appManager.dailyDigestPixelEffectEnabled,
                        showWindowControls: appManager.dailyDigestWindowControlsEnabled,
                        windowControlStyle: appManager.dailyDigestWindowControlsStyle,
                        title: "Your \(selectedRange.rawValue) Digest"
                    ) {
                        summaryMarkdownView(summary)
                    }
                } else {
                     // Standard view without terminal style
                     VStack(alignment: .leading, spacing: 8) {
                         Text("Your \(selectedRange.rawValue) Digest")
                             .font(.system(.headline, design: .monospaced))
                         summaryMarkdownView(summary)
                     }
                }
            }

            // Placeholder / Loading State (Keep outside terminal style)
            let allEnabledSectionsNil =
                (!appManager.dailyDigestShowDiscover || discoverContent == nil) &&
                digestSummary == nil

            if isGenerating && allEnabledSectionsNil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center) // Center horizontally
                    .padding(.vertical, 50) // Add vertical padding
            } else if !isGenerating && allEnabledSectionsNil {
                Text("Tap 'Generate' for your \(selectedRange.rawValue) digest...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center) // Center horizontally
                    .padding(.vertical, 50) // Add vertical padding
            }
        }
    }

    // --- NEW: Helper functions for Markdown views (to apply terminal text color) ---
    @ViewBuilder
    private func discoverMarkdownView(_ content: String) -> some View {
        Markdown(content)
            .markdownTheme(.basic)
            .font(.body)
            .if(appManager.dailyDigestTerminalStyleEnabled) { view in
                // Apply text color only if terminal style is enabled
                view.foregroundColor(appManager.dailyDigestColorScheme.textColor)
            }
    }
    
    @ViewBuilder
    private func summaryMarkdownView(_ summary: String) -> some View {
        Markdown(summary)
            .markdownTheme(.basic)
            .font(.body)
            .if(appManager.dailyDigestTerminalStyleEnabled) { view in
                // Apply text color only if terminal style is enabled
                view.foregroundColor(appManager.dailyDigestColorScheme.textColor)
            }
    }
    // --- END NEW ---

    @ViewBuilder
    private func bottomControlsView() -> some View {
        HStack(spacing: 15) {
            Picker("Digest Range", selection: $selectedRange) {
                ForEach(DigestRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)
            // Give picker some minimum width but allow expansion
            .frame(minWidth: 100)

            Spacer() // Pushes button to the right

            Button(action: { generateDigest(for: selectedRange) }) {
                HStack { // Add icon to button
                    if isGenerating {
                        ProgressView().tint(.primary) // Show progress in button
                    } else {
                        // Image(systemName: "wand.and.stars") // REMOVED ICON
                    }
                    Text("Generate \(selectedRange.rawValue)") // Shorten text slightly
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color(.systemGray6))) // Use subtle background
            }
            .buttonStyle(.plain)
            .disabled(isGenerating)
            // Optional: Animate button state change
             .animation(.easeInOut, value: isGenerating)
        }
        .frame(height: 50) // Define height for bottom controls area
    }

    @ViewBuilder
    private func settingsSheetView() -> some View {
        // Don't wrap in NavigationView since SettingsView already has its own NavigationStack
        SettingsView(currentThread: .constant(nil)) // Pass nil or relevant thread if needed
            .environmentObject(appManager)
            .environment(llm)
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium, .large])
    }

    // --- Generate Digest Logic (Refactored) ---
    private func generateDigest(for range: DigestRange) {
        // Reset state
        isGenerating = true
        // Reset based on settings
        if appManager.dailyDigestShowDiscover { discoverContent = nil } // Use new setting/variable
        digestSummary = nil // Reset summary

        // Capture context and settings for Task
        let context = modelContext
        let currentRange = range // Capture selected range
        let showCalendar = appManager.dailyDigestShowCalendar
        let showReminders = appManager.dailyDigestShowReminders
        let showDiscover = appManager.dailyDigestShowDiscover // Use new setting
        let discoverTopicsRaw = appManager.dailyDigestDiscoverTopics // Use new setting
        let modelName = appManager.currentModelName

        Task {
            // Define common date variables outside conditionals
            let now = Date()
            let todayStart = Calendar.current.startOfDay(for: now)
            
            var contextForLLM = "" // String to hold data for LLM summary
            
            // --- 0. Fetch Discover Content (Optional & Conditional) ---
            // Fetch this first so it appears above the summary
            if showDiscover {
                if let modelName = modelName {
                    // Combine selected common and custom topics
                    let customTopics = discoverTopicsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    let allTopics = Array(appManager.selectedCommonDiscoverTopics) + customTopics // Combine Set and Array
                    
                    let selectedTopic = allTopics.isEmpty ? "anything interesting" : allTopics.randomElement()! // Force unwrap safe due to check
                    
                    let discoverPrompt = "Share a brief, interesting insight or fact about \(selectedTopic)."
                    let discoverThread = Thread()
                    discoverThread.messages.append(Message(role: .user, content: discoverPrompt))
                    let discoverSystemPrompt = "You share brief, interesting insights or facts on various topics."
                    
                    let fetchedContent = await llm.generate(
                        modelName: modelName,
                        thread: discoverThread,
                        systemPrompt: discoverSystemPrompt
                    )
                    if !fetchedContent.isEmpty {
                        await MainActor.run { discoverContent = fetchedContent }
                    }
                } else {
                    print("Cannot fetch Discover content: No model selected.")
                    await MainActor.run { discoverContent = "(Could not fetch Discover content: No model selected)" }
                }
                // No sleep needed here as it runs before the main summary fetch
            }
            
            // --- 1. Fetch Calendar (Conditional) ---
            if showCalendar {
                let params = currentRange.fetchParams
                // fetchCalendarEvents now handles permission requests internally
                let fetchedCalendarText = await appManager.fetchCalendarEvents(for: params.range, value: params.value)
                let finalCalendarText: String?
                
                if fetchedCalendarText.isEmpty || fetchedCalendarText.contains("No relevant events") || fetchedCalendarText.contains("not authorized") {
                    finalCalendarText = nil // Set to nil if no useful data
                } else {
                    // Remove the header added by the fetch function
                    finalCalendarText = fetchedCalendarText.replacingOccurrences(of: "CONTEXT: User's upcoming schedule:\n", with: "")
                }
                
                if let text = finalCalendarText {
                    contextForLLM += "\n\n## Calendar Events:\n" + text
                }
                try? await Task.sleep(nanoseconds: 300_000_000) // Slightly longer delay
            }

            // --- 2. Fetch Reminders (Conditional) ---
            if showReminders {
                // Determine end date based on selected range
                let rangeEndDate: Date?
                let rangeParams = currentRange.fetchParams
                if rangeParams.range == .day && rangeParams.value == 1 {
                    rangeEndDate = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) // End of Today
                } else {
                    rangeEndDate = Calendar.current.date(byAdding: rangeParams.range, value: rangeParams.value, to: todayStart)
                }
                
                var fetchedRemindersText = "No pending reminders found for \(currentRange.rawValue)."
                
                if let validEndDate = rangeEndDate { // Ensure we have a valid end date
                    // Refined predicate to avoid force-unwrap
                    let predicate = #Predicate<Reminder> { reminder in
                        if !reminder.isCompleted {
                            if let date = reminder.scheduledDate {
                                // Compare unwrapped date if it exists
                                return date < validEndDate
                            } else {
                                // Include if date is nil (Someday reminders)
                                return true
                            }
                        } else {
                            // Exclude completed reminders
                            return false
                        }
                    }
                    var descriptor = FetchDescriptor<Reminder>(predicate: predicate, sortBy: [SortDescriptor(\.scheduledDate)])
                    descriptor.fetchLimit = 50 // Limit reminders fetched
                    do {
                        let fetchedReminders = try context.fetch(descriptor)
                        if !fetchedReminders.isEmpty {
                            var reminderBuilder = ""
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .short
                            dateFormatter.timeStyle = .short
                            for reminder in fetchedReminders {
                                let dateStr = reminder.scheduledDate != nil ? dateFormatter.string(from: reminder.scheduledDate!) : "Someday"
                                
                                // Updated status logic to match ReminderRow
                                let status: String
                                if reminder.isCompleted {
                                    status = "Completed"
                                } else if let date = reminder.scheduledDate, date < now {
                                    status = "Overdue"
                                } else if let date = reminder.scheduledDate, Calendar.current.isDateInToday(date) {
                                    status = "Due Today"
                                } else {
                                    status = "Upcoming"
                                }
                                
                                reminderBuilder += "- \(reminder.taskDescription) (\(dateStr), Status: \(status))\n"
                            }
                            fetchedRemindersText = reminderBuilder.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } catch {
                        print("❌ Error fetching reminders for digest: \(error)") // Add specific error print
                        fetchedRemindersText = "Error fetching reminders."
                    }
                } else {
                    fetchedRemindersText = "Error calculating date range for reminders."
                }
                
                // Only add to context if useful reminders were found
                if !fetchedRemindersText.contains("No pending reminders") && !fetchedRemindersText.contains("Error fetching") {
                    contextForLLM += "\n\n## Pending Reminders:\n" + fetchedRemindersText
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }

            // --- 3. Generate LLM Summary (If Context Exists) ---
            if let model = modelName, !contextForLLM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Truncate context if too long
                let maxContextLength = 4000
                var truncatedContext = contextForLLM
                if truncatedContext.count > maxContextLength {
                    truncatedContext = String(truncatedContext.prefix(maxContextLength)) + "\n... (context truncated)"
                    print("Digest context truncated to \(maxContextLength) chars.")
                }

                // --- Personalize Prompt --- 
                var personalizedPrompt = "Summarize the following context for the user's \(currentRange.rawValue) digest. Be friendly and encouraging. Format the output using clean Markdown (e.g., use **bold** or *italics* for emphasis, not raw asterisks)."
                
                // Fetch user profile and add name if available
                let profileDescriptor = FetchDescriptor<UserProfile>()
                if let userProfile = (try? context.fetch(profileDescriptor))?.first, !userProfile.name.isEmpty {
                    personalizedPrompt += " The user's name is \(userProfile.name)."
                    print("Personalizing digest prompt for user: \(userProfile.name)")
                }
                
                personalizedPrompt += "\n\nContext:\n\(truncatedContext)" // Use truncated context
                // --- End Personalize Prompt ---
                
                let summaryThread = Thread()
                summaryThread.messages.append(Message(role: .user, content: personalizedPrompt)) // Use personalized prompt
                let summarySystemPrompt = "You are an AI assistant creating a personalized daily digest summary formatted in clean Markdown."
                
                let summaryResult = await llm.generate(
                    modelName: model,
                    thread: summaryThread,
                    systemPrompt: summarySystemPrompt
                )
                
                await MainActor.run {
                    digestSummary = summaryResult.isEmpty ? "Couldn't generate summary." : summaryResult
                }
            } else if contextForLLM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Handle case where toggles are on but no actual data was found
                await MainActor.run {
                    digestSummary = "No calendar events or reminders found for your selected range."
                }
            }
            
            // Cache the results after successful generation
            await MainActor.run {
                // Save content, use empty string if nil
                appManager.cachedDigestDiscoverContent = discoverContent ?? ""
                appManager.cachedDigestSummary = digestSummary ?? ""
                appManager.cachedDigestRangeRawValue = currentRange.rawValue
                // Store today's date as a timestamp (seconds since 1970)
                appManager.cachedDigestGenerationTimestamp = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
            }
            
            // --- Finish ---
            // Award XP for generating a digest
            appManager.awardXP(points: 5, trigger: "Digest Generated") // Increased to 5 XP
            
            await MainActor.run {
                isGenerating = false
            }
            print("Digest generation complete.")
        }
    }

    // --- NEW: Cache Loading Logic ---
    private func loadCachedDigestIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        // Check if cache timestamp is valid (not 0.0)
        let cachedTimestamp = appManager.cachedDigestGenerationTimestamp
        if cachedTimestamp != 0.0 {
            // Convert timestamp back to Date
            let cachedDate = Date(timeIntervalSince1970: cachedTimestamp)
            
            // Check if cached date is the same day as today
            if Calendar.current.isDate(cachedDate, inSameDayAs: today) {
                // Restore from cache only if strings aren't empty defaults
                let loadedDiscover = appManager.cachedDigestDiscoverContent
                let loadedSummary = appManager.cachedDigestSummary
                let loadedRangeValue = appManager.cachedDigestRangeRawValue

                if !loadedDiscover.isEmpty || !loadedSummary.isEmpty { // Check if at least one has content
                    discoverContent = loadedDiscover.isEmpty ? nil : loadedDiscover
                    digestSummary = loadedSummary.isEmpty ? nil : loadedSummary
                    if let cachedRange = DigestRange(rawValue: loadedRangeValue) {
                        selectedRange = cachedRange
                    } else {
                        selectedRange = .day // Fallback range
                    }
                    print("Loaded cached digest from today.")
                    return // Exit after loading cache
                }
            }
        }
        
        // If we reach here, cache is old or doesn't exist
        // Clear state to ensure blank slate
        discoverContent = nil
        digestSummary = nil
        // Keep selectedRange as default (.day)
        print("No valid cache found for today or cache is stale.")
        // Optionally trigger an automatic generation here if desired
        // generateDigest(for: selectedRange)
    }
    // --- END NEW ---
}

// --- MARK: Terminal Style Components (Added Here) ---

// Reusable Window Controls Header
struct WindowControlsHeaderView: View {
    let style: WindowControlStyle

    var body: some View {
        HStack(spacing: 8) {
            switch style {
            case .macOS:
                Circle().fill(.red).frame(width: 10, height: 10)
                Circle().fill(.yellow).frame(width: 10, height: 10)
                Circle().fill(.green).frame(width: 10, height: 10)
            case .windows:
                Image(systemName: "minus")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .background(Color.gray.opacity(0.2))

                Image(systemName: "square")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.gray.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .background(Color.gray.opacity(0.2))

                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 12, height: 12)
                    .background(Color.red.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// Reusable Scanlines Effect Overlay
struct ScanlinesEffectView: View {
    let backgroundColor: Color

    var body: some View {
        GeometryReader { geo in
            let lineHeight: CGFloat = 2.5
            let lineSpacing: CGFloat = 1.5
            let totalLines = Int(geo.size.height / (lineHeight + lineSpacing))

            VStack(spacing: lineSpacing) {
                ForEach(0..<totalLines, id: \.self) { _ in
                    Rectangle()
                        .fill(backgroundColor) // Use the background color for scanlines
                        .frame(height: lineHeight)
                        .opacity(0.15) // Keep opacity low
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .blendMode(.multiply)
            .allowsHitTesting(false)
            .clipped()
        }
    }
}

// Main Wrapper View for Terminal Styling
struct TerminalStyleWrapper<Content: View>: View {
    // Settings
    let colorScheme: TerminalColorScheme
    let showScanlines: Bool
    let showFlicker: Bool
    let showPixelEffect: Bool // NEW: Add pixel effect setting
    let showWindowControls: Bool
    let windowControlStyle: WindowControlStyle
    let title: String? // Optional title for window controls area

    // Content
    @ViewBuilder let content: Content

    // Internal State for Effects
    @State private var flickerOpacity: Double = 0.0
    let effectsTimer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    // Computed Colors
    private var textColor: Color { colorScheme.textColor }
    private var bgColor: Color { colorScheme.backgroundColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Optional Window Controls Header
            if showWindowControls {
                // Optionally add title next to controls if provided
                if let title = title, !title.isEmpty {
                     HStack {
                        WindowControlsHeaderView(style: windowControlStyle)
                        Text(title)
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundColor(textColor.opacity(0.8))
                            .padding(.leading, -4) // Adjust spacing
                            .lineLimit(1)
                        Spacer()
                    }
                } else {
                     WindowControlsHeaderView(style: windowControlStyle)
                 }
            }

            // Main Content Area
            content
                .foregroundColor(textColor) // Apply base text color to content
                .drawingGroup() // Enable high-performance rendering for effects
                .overlay {
                    // Apply Effects as Overlays
                    ZStack {
                        if showScanlines {
                            ScanlinesEffectView(backgroundColor: bgColor)
                        }
                        if showFlicker {
                            // Flicker Overlay
                            Color.white.opacity(flickerOpacity)
                                .blendMode(.screen)
                                .allowsHitTesting(false)
                                .clipped()
                        }
                         if showPixelEffect {
                             Rectangle()
                                 .fill(bgColor.opacity(0.6))
                                 .mask(PixelGridMaskView()) // Use pixel grid as mask
                                 .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.vertical, showWindowControls ? 4 : 12) // Adjust padding based on header
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading) // Always align left for digest
                .background(bgColor) // Apply background color
                .clipped() // Clip overlays to the bounds

        }
        // Apply modifiers to the VStack container
        .background(bgColor) // Ensure whole wrapper has background
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(textColor.opacity(0.5), lineWidth: 1)
        )
        .onReceive(effectsTimer) { _ in
            updateFlicker()
        }
    }

    // --- Effect Update Functions ---
    private func updateFlicker() {
        guard showFlicker else {
            if flickerOpacity != 0 { flickerOpacity = 0 }
            return
        }
        flickerOpacity = Double.random(in: 0.0...0.03)
    }
}

// --- NEW: Pixel Grid Mask View ---
struct PixelGridMaskView: View {
    let pixelSize: CGFloat = 3 // Adjust pixel size as needed

    var body: some View {
        GeometryReader { geometry in
            let cols = Int(geometry.size.width / pixelSize)
            let rows = Int(geometry.size.height / pixelSize)

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<cols {
                        // Draw small gaps between pixels by drawing slightly smaller squares
                        let rect = CGRect(x: CGFloat(col) * pixelSize + 0.5, // Add small offset for gap
                                          y: CGFloat(row) * pixelSize + 0.5,
                                          width: pixelSize - 1, // Make square smaller than grid cell
                                          height: pixelSize - 1)
                        context.fill(Path(rect), with: .color(.black)) // Use black for mask
                    }
                }
            }
        }
    }
}
// --- End NEW ---

// --- End MARK: Terminal Style Components ---

#Preview {
    // Create mock data for preview if needed
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // Ensure all models needed for the preview are included
    let container = try! ModelContainer(for: Reminder.self, configurations: config)

    // Add sample data
    let today = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    container.mainContext.insert(Reminder(taskDescription: "Preview Task Today", scheduledDate: today))
    container.mainContext.insert(Reminder(taskDescription: "Preview Task Overdue", scheduledDate: yesterday))

    // Return the view with necessary environment objects and model container
    // Wrap in a NavigationView or NavigationStack if the view uses navigation features internally
    return DailyDigestView()
        .environmentObject(AppManager()) // Provide mock or real AppManager
        .environment(LLMEvaluator())   // Provide mock or real LLMEvaluator
        .modelContainer(container)     // Provide the container with mock data
}
