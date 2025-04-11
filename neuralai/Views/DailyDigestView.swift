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
        VStack(spacing: 0) { // Reduce root spacing
            // --- Combined Top Bar with XP, Eyes, and Settings ---
            HStack(alignment: .center) {
                 // --- XP Display (Top Left) ---
                if appManager.showXpInUI {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(appManager.buddyLevel)")
                            .font(.caption)
                        ProgressView(value: Float(appManager.buddyXP), total: Float(appManager.xpForNextLevel))
                            .progressViewStyle(.linear)
                            .frame(width: 80)
                        Text("\(appManager.xpTowardsNextLevel)/\(appManager.xpForNextLevel) XP")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .frame(width: 80, alignment: .leading) // Ensure XP takes space
                } else {
                    // Add a spacer if XP is hidden to maintain balance
                    Spacer().frame(width: 80)
                }
                
                Spacer()
                
                // --- Eyes (Centered) ---
                AnimatedEyesView(
                    isGenerating: isGenerating,
                    isThinking: isGenerating
                )
                .frame(height: 50) // Match the height from ChatView

                Spacer()

                // --- Settings Button (Top Right) ---
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(appManager.appTintColor.getColor())
                }
                .frame(width: 80, alignment: .trailing) // Give settings button same width as XP for balance

            }
            .padding(.horizontal)
            // Removed .padding(.top, 10) - Adjust spacing below instead
            .frame(height: 60) // Keep a defined height for the top area
            .padding(.top, 5) // Add small padding to push down slightly from safe area

            // --- Digest Display Area ---
            ScrollView {
                  VStack(alignment: .center, spacing: 15) { // Center alignment for VStack
                      // --- Optional Discover Section --- 
                      if appManager.dailyDigestShowDiscover, let content = discoverContent { 
                          Text("Discover")
                               .font(.system(.headline, design: .monospaced)) // Monospaced Title
                          Markdown(content) // Use MarkdownUI
                              .markdownTheme(.basic)
                              .font(.body) // Use standard body font
                              // .multilineTextAlignment(.center) // Apply center alignment to Markdown text
                             Divider().padding(.vertical, 5)
                      }
                      
                      // Combined Summary Section
                      if let summary = digestSummary {
                          Text("Your \(selectedRange.rawValue) Digest")
                             .font(.system(.headline, design: .monospaced)) // Monospaced Title
                          Markdown(summary) // Use MarkdownUI
                              .markdownTheme(.basic)
                              .font(.body) // Use standard body font
                              // .multilineTextAlignment(.center) // Apply center alignment to Markdown text
                              // Removed frame modifier to allow centering
                      }
                      
                      // --- Placeholder/Loading --- 
                      let allEnabledSectionsNil = 
                          (!appManager.dailyDigestShowDiscover || discoverContent == nil) && 
                          digestSummary == nil
                          
                      if isGenerating && allEnabledSectionsNil {
                          ProgressView()
                               .frame(maxWidth: .infinity, alignment: .center)
                               .padding()
                      } else if !isGenerating && allEnabledSectionsNil {
                          Text("Tap 'Generate' for your \(selectedRange.rawValue) digest...")
                              .font(.system(.body, design: .monospaced))
                              .foregroundColor(.secondary)
                              .frame(maxWidth: .infinity, alignment: .center)
                              .padding()
                       }
                  }
                  .padding(.horizontal) // Add horizontal padding to the content VStack
                  .padding(.top, 10) // Add padding above content
                  .frame(maxWidth: .infinity) // Ensure VStack takes full width for centering
             }
             .foregroundStyle(Color.primary)
             .padding(.top, 10) // Add space between top bar and scroll content

            // --- Bottom Control Area (Picker + Button) --- 
            HStack(spacing: 15) {
                // --- Date Picker (Moved Here) ---
                Picker("Digest Range", selection: $selectedRange) {
                    ForEach(DigestRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                // Removed fixed width to allow natural sizing

                Spacer() // Pushes picker left and button right

                // --- Generate Button --- 
                 Button(action: { generateDigest(for: selectedRange) }) {
                    Text("Generate \(selectedRange.rawValue) Digest")
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(.systemGray6)))
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
            .padding(.horizontal) // Add horizontal padding to the HStack
            .padding(.vertical, 10) // Add vertical padding
            .frame(height: 50) // Give the bottom bar a defined height
            // --- End Bottom Control Area ---

         }
         // Removed horizontal padding from root VStack
         .background(Color(.systemBackground))
         .ignoresSafeArea(edges: [.bottom]) // Changed from [.top, .bottom] to allow top bar padding
         .foregroundColor(.primary)
         .onAppear {
             loadCachedDigestIfNeeded()
         }
         .sheet(isPresented: $showSettingsSheet) {
            // Present the appropriate settings view
            // Assuming SettingsView is the main container for settings
            SettingsView(currentThread: .constant(nil)) // Pass nil or relevant thread if needed
                .environmentObject(appManager)
                .environment(llm)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
         }
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
