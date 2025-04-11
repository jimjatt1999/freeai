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
                    .background(Color(.systemBackground).shadow(radius: 1, y: -1)) // Add subtle shadow

            }
            .background(Color(.systemBackground))
            .foregroundColor(.primary)
            .navigationBarHidden(true) // Hide navigation bar since we're using our own top bar
            .edgesIgnoringSafeArea(.bottom) // Ignore bottom safe area for the bottom controls
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
            AnimatedEyesView(isGenerating: isGenerating, isThinking: isGenerating)
                .frame(height: 50) // Keep eyes height

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
    }

    @ViewBuilder
    private func contentView() -> some View {
        VStack(alignment: .leading, spacing: 20) { // Align content left, increase spacing
            // Discover Section
            if appManager.dailyDigestShowDiscover, let content = discoverContent {
                VStack(alignment: .leading, spacing: 8) { // Group title and content
                    Text("Discover")
                        .font(.system(.headline, design: .monospaced))
                    Markdown(content)
                        .markdownTheme(.basic)
                        .font(.body)
                }
                Divider()
            }

            // Digest Summary Section
            if let summary = digestSummary {
                 VStack(alignment: .leading, spacing: 8) { // Group title and content
                     Text("Your \(selectedRange.rawValue) Digest")
                         .font(.system(.headline, design: .monospaced))
                     Markdown(summary)
                         .markdownTheme(.basic)
                         .font(.body)
                 }
            }

            // Placeholder / Loading State
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
                        Image(systemName: "wand.and.stars")
                    }
                    Text("Generate \(selectedRange.rawValue)") // Shorten text slightly
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color(.systemGray5))) // Slightly darker capsule
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

                let summaryPrompt = "Summarize the following context for the user's \(currentRange.rawValue) digest. Be friendly and encouraging. Format the output using clean Markdown (e.g., use **bold** or *italics* for emphasis, not raw asterisks). \n\nContext:\n\(truncatedContext)" // Use truncated context
                let summaryThread = Thread()
                summaryThread.messages.append(Message(role: .user, content: summaryPrompt))
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
