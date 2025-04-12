import SwiftUI
import SwiftData
import Foundation
import UserNotifications
import Speech

// Struct to decode the LLM's JSON response
struct ReminderParseResult: Decodable {
    let task: String?
    let dateTime: String? // Expecting ISO 8601 format (YYYY-MM-DDTHH:mm:ss) or null
}

// --- Filter Enum ---
enum ReminderFilterType: String, CaseIterable, Identifiable {
    case today = "Today"
    case later = "Later"
    case completed = "Completed"
    var id: String { self.rawValue }
}
// --- End Filter Enum ---

struct FreeBuddyView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    // TODO: Add state for reminder input, reminder list, buddy level, etc.
    @State private var reminderInput: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isProcessing: Bool = false

    // --- State for User Feedback --- 
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    // --- End State for User Feedback ---

    // --- State for Level Up Quote ---
    @State private var showLevelUpQuote = false
    @State private var levelUpQuote = ""
    // --- End Level Up Quote State ---

    // --- State for Editing --- 
    @State private var reminderToEdit: Reminder? = nil
    // --- End State for Editing ---

    // --- Speech Recognition State ---
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) // Or your preferred locale
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var isRecording = false
    // --- End Speech Recognition State ---

    // --- Fetch Reminders (Simplest form - NO sorting again) --- 
    @Query var reminders: [Reminder]
    // --- End Fetch Reminders ---
    
    // --- Computed properties for Filtering Logic ---
    // These are now used directly by Sections
    private var overdueReminders: [Reminder] { 
         reminders.filter { $0.scheduledDate != nil && $0.scheduledDate! < Calendar.current.startOfDay(for: Date()) && !$0.isCompleted }
    }
    private var todayReminders: [Reminder] {
        reminders.filter { $0.scheduledDate != nil && Calendar.current.isDateInToday($0.scheduledDate!) && !$0.isCompleted }
    }
    private var laterReminders: [Reminder] {
        reminders.filter { $0.scheduledDate != nil && !Calendar.current.isDateInToday($0.scheduledDate!) && $0.scheduledDate! > Date() && !$0.isCompleted }
    }
    private var somedayReminders: [Reminder] { 
        reminders.filter { $0.scheduledDate == nil && !$0.isCompleted }
    }
    private var completedReminders: [Reminder] {
         reminders.filter { $0.isCompleted }
    }
    
    // --- Example Reminder Prompts ---
    let reminderExamples = [
        "Call mom on Sunday at 5pm",
        "Go to church this Sunday at 10am",
        "Buy groceries tomorrow",
        "Water plants every Tuesday 8am",
        "Doctor appointment on May 15 at 2pm"
    ]
    // --- End Example Reminder Prompts ---

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) { // Use spacing 0 for tighter control
                // --- Eyes & Level Display ---
                ZStack {
                    // Centered eyes that ignore other elements
                    if appManager.showNeuraEyes {
                        NeuraEyesView(
                            isGenerating: isProcessing,
                            isThinking: isProcessing,
                            isListening: isRecording
                        )
                    } else {
                        Text("Reminders")
                            .font(.headline)
                            .foregroundColor(appManager.appTintColor.getColor())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.bottom, 10) // Add bottom padding
                 // --- End Eyes & Level Display ---

                // --- Reminder List (With Sections) --- 
                List {
                    // Check if there are ANY reminders before showing sections
                    if reminders.isEmpty {
                         Text("No reminders yet. Add one below!")
                             .foregroundColor(.secondary)
                             .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                             .listRowSeparator(.hidden)
                    } else {
                        // --- Overdue Section ---
                        if !overdueReminders.isEmpty {
                            Section("Overdue") {
                                ForEach(overdueReminders) { reminder in
                                    ReminderRow(reminder: reminder, toggleAction: toggleCompletion, deleteAction: deleteReminder, editAction: { editReminder(reminder) })
                                        .id(reminder.id)
                                }
                            }
                        }
                         
                        // --- Today Section ---
                        if !todayReminders.isEmpty {
                            Section("Today") {
                                ForEach(todayReminders) { reminder in
                                    ReminderRow(reminder: reminder, toggleAction: toggleCompletion, deleteAction: deleteReminder, editAction: { editReminder(reminder) })
                                        .id(reminder.id)
                                }
                            }
                        }
                        
                        // --- Later Section ---
                        if !laterReminders.isEmpty {
                            Section("Later") {
                                ForEach(laterReminders) { reminder in
                                    ReminderRow(reminder: reminder, toggleAction: toggleCompletion, deleteAction: deleteReminder, editAction: { editReminder(reminder) })
                                        .id(reminder.id)
                                }
                            }
                        }
                        
                        // --- Someday Section ---
                        if !somedayReminders.isEmpty {
                            Section("Someday") {
                                ForEach(somedayReminders) { reminder in
                                    ReminderRow(reminder: reminder, toggleAction: toggleCompletion, deleteAction: deleteReminder, editAction: { editReminder(reminder) })
                                        .id(reminder.id)
                                }
                            }
                        }
                        
                        // --- Completed Section ---
                        if !completedReminders.isEmpty {
                            Section("Completed") {
                                ForEach(completedReminders) { reminder in
                                    ReminderRow(reminder: reminder, toggleAction: toggleCompletion, deleteAction: deleteReminder, editAction: { editReminder(reminder) })
                                        .id(reminder.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity) 
                .background(Color.clear.contentShape(Rectangle()).onTapGesture { isInputFocused = false })

                // --- Example Reminder Prompts ---
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(reminderExamples, id: \.self) { example in
                            Button {
                                reminderInput = example
                                isInputFocused = true
                            } label: {
                                Text(example)
                                    .font(.footnote)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.tertiarySystemBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(16)
                                    .lineLimit(1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 40)
                .padding(.bottom, 4)
                // --- End Example Reminder Prompts ---

                // --- Input Area ---
                HStack(spacing: 8) {
                    // Mic Button
                    Button {
                        if isRecording {
                            stopSpeechRecognition()
                        } else {
                            startSpeechRecognition()
                        }
                    } label: {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                            // Use tint color for active mic
                            .foregroundColor(isRecording ? .red : appManager.appTintColor.getColor())
                    }
                    .padding(.leading, 4)
                    
                    TextField("Remind me... (e.g., call mom tomorrow 5pm)", text: $reminderInput, axis: .vertical)
                        .focused($isInputFocused)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 6)
                        .onSubmit { processReminder() }
                    
                    // Show progress indicator when processing
                    if isProcessing {
                         ProgressView()
                             .tint(appManager.appTintColor.getColor()) // Tint the ProgressView
                             .padding(.trailing, 8)
                             .frame(width: 30, height: 30)
                     } else {
                        Button(action: processReminder) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                // Use tint color for enabled send button
                                .foregroundColor(reminderInput.isEmpty ? .secondary : appManager.appTintColor.getColor())
                        }
                        .disabled(reminderInput.isEmpty)
                        .padding(.trailing, 4)
                     }
                }
                .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 8))
                .background(
                    RoundedRectangle(cornerRadius: 24) // Consistent styling
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .padding() // Padding around the input box
                .padding(.bottom, 54) // SIGNIFICANTLY increase extra bottom padding

            }
            .navigationTitle("")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline) // Keep consistent title style
            #endif
            .toolbar {
                 // Toolbar items can be added later (e.g., maybe level indicator)
            }
            .onTapGesture {
                 // Dismiss keyboard on tap outside
                 isInputFocused = false
            }
            // --- Add Alert Modifier ---
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            // --- End Alert Modifier ---
            // --- Add Level Up Quote Alert ---
            .alert("Level Up!", isPresented: $showLevelUpQuote) {
                 Button("Nice!") { }
             } message: {
                 // Display the fetched quote
                 Text(levelUpQuote)
             }
             // --- End Level Up Quote Alert ---
            .onAppear {
                 // Request permission when view appears (can be moved elsewhere)
                 requestNotificationPermission()
             }
            // Add sheet modifier for editing
            .sheet(item: $reminderToEdit) { reminder in
                ReminderEditView(reminder: reminder)
                    .environmentObject(appManager)
                    .environment(\.modelContext, modelContext)
            }
        }
    }

    // --- Main Processing Function (Simplified) ---
    private func processReminder() {
        let textToProcess = reminderInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToProcess.isEmpty else { return } // No need for isProcessing check
        
        reminderInput = "" 
        isInputFocused = false
        appManager.playHaptic()
        
        // --- NSDataDetector Only --- 
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(textToProcess.startIndex..<textToProcess.endIndex, in: textToProcess)
        let matches = detector?.matches(in: textToProcess, options: [], range: range)
        
        var detectedDate: Date? = nil
        var taskDescription = textToProcess // Default to full text
        
        if let match = matches?.first, match.resultType == .date, let date = match.date {
            // Found a date
            detectedDate = date
            print("NSDataDetector found date: \(date)")
            if let rangeToRemove = Range(match.range, in: textToProcess) {
                 // Extract task by removing date phrase
                 taskDescription = textToProcess.replacingCharacters(in: rangeToRemove, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                 taskDescription = taskDescription.replacingOccurrences(of: #"^(on|at|by|for|due)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
                 taskDescription = taskDescription.replacingOccurrences(of: #"\s+(on|at|by|for|due)$"#, with: "", options: [.regularExpression, .caseInsensitive])
                 taskDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                 if taskDescription.isEmpty { taskDescription = "Reminder" } 
             }
        } else {
             // No date found, task is the full input text
             print("NSDataDetector did not find a date.")
        }
        
        print("Final Task: \(taskDescription), Date: \(detectedDate?.description ?? "None")")
        saveAndScheduleReminder(task: taskDescription, scheduledDate: detectedDate)
        
        // --- LLM PATH REMOVED --- 
    }
    
    // --- Helper Functions ---
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }

    private func scheduleNotification(reminder: Reminder) {
        // Safely unwrap the optional date
        guard let scheduledDate = reminder.scheduledDate else {
            print("Notification scheduling skipped: No date provided.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = " Reminder"
        content.body = reminder.taskDescription
        content.sound = .default

        // Ensure date is in the future
        guard scheduledDate > Date() else { // Use the unwrapped date
            print("Notification scheduling skipped: Date is in the past.")
            return
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: scheduledDate) // Use the unwrapped date
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled successfully for reminder: \(reminder.id)")
            }
        }
    }
    
    private func showUserAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }

    private func toggleCompletion(for reminder: Reminder) { 
        let oldCompletionState = reminder.isCompleted

        if !oldCompletionState { // Toggling from Incomplete to Complete
            // Check for recurrence
            if reminder.recurrence != .none, let currentDueDate = reminder.scheduledDate {
                var nextDueDate: Date? = nil
                var calendar = Calendar.current
                calendar.timeZone = TimeZone.current // Ensure correct timezone

                // Calculate next date based on rule
                switch reminder.recurrence ?? .none {
                case .daily:
                    nextDueDate = calendar.date(byAdding: .day, value: 1, to: currentDueDate)
                case .weekly:
                    nextDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDueDate)
                case .monthly:
                    nextDueDate = calendar.date(byAdding: .month, value: 1, to: currentDueDate)
                case .none:
                    break // Should not happen here, but good practice
                }

                // Ensure the next date is in the future relative to NOW, not just the old date
                // (e.g., if completing a daily reminder from yesterday, next is today)
                if let calculatedNextDate = nextDueDate, calculatedNextDate < Date() {
                     // If the calculated next date is still in the past, keep advancing
                     // until it's in the future (or handle edge cases differently)
                     // This simple logic just sets it to the next occurrence after today.
                     // More complex logic might be needed for specific scenarios.
                     var advancedDate = calculatedNextDate
                     while advancedDate < Date() {
                        var maybeNewDate: Date?
                         switch reminder.recurrence ?? .none {
                         case .daily: maybeNewDate = calendar.date(byAdding: .day, value: 1, to: advancedDate)
                         case .weekly: maybeNewDate = calendar.date(byAdding: .weekOfYear, value: 1, to: advancedDate)
                         case .monthly: maybeNewDate = calendar.date(byAdding: .month, value: 1, to: advancedDate)
                         case .none: maybeNewDate = nil; break // Stop loop if recurrence is none
                         }
                         // Safely unwrap and update, or break if calculation fails
                         if let newDate = maybeNewDate {
                            advancedDate = newDate
                         } else {
                            print("Error calculating next recurrence date for reminder: \(reminder.id). Breaking loop.")
                            break // Exit while loop if date calculation fails
                         }
                     }
                     nextDueDate = advancedDate
                }

                // Update date and keep incomplete
                reminder.scheduledDate = nextDueDate
                reminder.xpAwarded = false // Reset XP awarded status for recurring task
                print("Recurring reminder '\(reminder.taskDescription)' rescheduled to \(nextDueDate?.description ?? "error")")
                
                // Reschedule notification for the new date
                rescheduleNotification(for: reminder)

            } else {
                // Not recurring or no date, just mark as complete
                reminder.isCompleted = true
                cancelNotification(for: reminder) // Cancel notification if completed manually
            }

            // Award XP only when completing (not un-completing)
            if !reminder.xpAwarded { // Check if XP was already awarded
                let points = 10 // Award 10 XP for completing a task
                appManager.awardXP(points: points, trigger: "Reminder Completed")
                reminder.xpAwarded = true
                // checkForLevelUp() // Check for level up after awarding XP
            }

        } else { // Toggling from Complete to Incomplete
            reminder.isCompleted = false
            reminder.xpAwarded = false // Reset XP if marked incomplete
            // Reschedule notification if it now has a future date
            rescheduleNotification(for: reminder)
        }
        
        appManager.playHaptic()
    }
    
    private func deleteReminder(reminder: Reminder) {
        // Also cancel the scheduled notification if it exists
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        print("Removed pending notification (if any) for reminder: \(reminder.id)")
        
        modelContext.delete(reminder)
        do {
            try modelContext.save()
            print("Deleted reminder: \(reminder.id)")
            appManager.playHaptic()
        } catch {
            print("Error deleting reminder: \(error)")
            showUserAlert(title: "Error", message: "Could not delete the reminder.")
        }
    }

    private func saveAndScheduleReminder(task: String, scheduledDate: Date?) {
        // Ensure task isn't empty after potential extraction
        guard !task.isEmpty else {
             showUserAlert(title: "Error", message: "Cannot save an empty reminder.")
             return
        }
        
        let newReminder = Reminder(taskDescription: task, scheduledDate: scheduledDate)
        modelContext.insert(newReminder)
        
        do {
            try modelContext.save()
            print("Reminder saved: \(newReminder.taskDescription) scheduled: \(newReminder.scheduledDate?.description ?? "nil")")
            
            // Use safe unwrapping and comparison for scheduling check
            if let validDate = scheduledDate, validDate > Date() {
                scheduleNotification(reminder: newReminder) // Pass the valid reminder object
                // Toast notification removed
            } else if scheduledDate != nil { // Date exists but is past or now
                 // Past date notification removed
            } else { // scheduledDate is nil
                // No date notification removed
            }
            // Removed showUserAlert for success
            
            // Award XP for creating a reminder
            appManager.awardXP(points: 2, trigger: "Reminder Created")
            appManager.playHaptic()
            
        } catch {
            print("Error saving reminder to SwiftData: \(error)")
            showUserAlert(title: "Error", message: "Could not save the reminder.")
        }
    }

    // --- Speech Recognition Helpers ---
    private func startSpeechRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isRecording = false
            print("Stopped recording via button")
        } else {
            SFSpeechRecognizer.requestAuthorization { authStatus in // Removed [weak self]
                OperationQueue.main.addOperation {
                    switch authStatus {
                    case .authorized:
                        print("Speech permission authorized.")
                        do {
                            try self.startRecording() // Use self directly
                            self.isRecording = true
                            print("Started recording")
                        } catch {
                            print("Recording failed to start: \(error)")
                            self.isRecording = false
                            self.showUserAlert(title: "Error", message: "Could not start voice input: \(error.localizedDescription)")
                        }
                    case .denied, .restricted, .notDetermined:
                        print("Speech permission not authorized.")
                        self.isRecording = false
                         self.showUserAlert(title: "Permission Denied", message: "Please enable Speech Recognition permission in Settings to use voice input.")
                    @unknown default:
                        fatalError("Unknown speech recognition authorization status.")
                    }
                }
            }
        }
    }

    private func startRecording() throws {
        // Cancel previous task if any
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create recognition request") }
        recognitionRequest.shouldReportPartialResults = true

        // Get input node
        let inputNode = audioEngine.inputNode
        // Throws error if no input available
        _ = inputNode.outputFormat(forBus: 0)
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in // Removed [weak self]
            var isFinal = false

            if let result = result {
                self.reminderInput = result.bestTranscription.formattedString // Use self directly
                isFinal = result.isFinal
                print("Partial transcription: \(self.reminderInput)")
            }

            if error != nil || isFinal {
                print("Recognition finished (error: \(error != nil), isFinal: \(isFinal))")
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
                
                // Deactivate audio session only when truly done
                try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }

        // Configure audio engine input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        // Start engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Ensure input field is focused when starting
        self.isInputFocused = true // Use self directly
    }

    private func stopSpeechRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        print("Stopped recording via button")
    }
    // --- End Speech Recognition Helpers ---

    // --- Add Edit Helper ---
    private func editReminder(_ reminder: Reminder) {
        reminderToEdit = reminder
    }
    // --- End Edit Helper ---

    // --- Level Up Logic ---
    private func checkForLevelUp(previousXP: Int, currentXP: Int) {
        let previousLevel = (previousXP / 100) + 1
        let currentLevel = (currentXP / 100) + 1
        
        if currentLevel > previousLevel {
            print("Level Up! Reached Level \(currentLevel)")
            fetchAndShowLevelUpQuote(level: currentLevel)
        }
    }
    
    private func fetchAndShowLevelUpQuote(level: Int) {
        // Placeholder for fetching a quote. Replace with a real API or local list.
        let quotes = [
            "The journey of a thousand miles begins with one step.",
            "Knowing yourself is the beginning of all wisdom.",
            "The only true wisdom is in knowing you know nothing.",
            "The unexamined life is not worth living.",
            "Whereof one cannot speak, thereof one must be silent.",
            "Happiness is the highest good.",
            "Man is the measure of all things.",
            "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
            "To be is to be perceived.",
            "Entities should not be multiplied without necessity."
            // Add many more quotes!
        ]
        
        // Simple selection logic (can be improved)
        let quoteIndex = (level - 1) % quotes.count 
        levelUpQuote = quotes[quoteIndex]
        showLevelUpQuote = true
        appManager.playHaptic() // Extra feedback for level up
    }
    // --- End Level Up Logic ---

    // Helper specifically for rescheduling recurring/incomplete tasks
    private func rescheduleNotification(for reminder: Reminder) {
        // Always remove existing first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        // Schedule if incomplete and has a future date
        if !reminder.isCompleted, let date = reminder.scheduledDate, date > Date() {
            scheduleNotification(reminder: reminder)
        }
    }

    private func cancelNotification(for reminder: Reminder) {
         UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
         print("Cancelled notification for reminder: \(reminder.id)")
    }
}

// --- Add Reminder Model (Placeholder) ---
// Needs to be created in Data.swift or similar
/*
@Model
final class Reminder {
    var id: UUID
    var taskDescription: String
    var scheduledDate: Date
    var isCompleted: Bool
    var creationDate: Date

    init(id: UUID = UUID(), taskDescription: String, scheduledDate: Date, isCompleted: Bool = false, creationDate: Date = Date()) {
        self.id = id
        self.taskDescription = taskDescription
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
        self.creationDate = creationDate
    }
}
*/
// --- End Reminder Model ---

// --- IMPORTANT: Info.plist Keys Required ---
// Remember to add these keys to your project's Info.plist:
// - Privacy - Speech Recognition Usage Description (NSSpeechRecognitionUsageDescription)
// - Privacy - Microphone Usage Description (NSMicrophoneUsageDescription)
// --- End Info.plist Reminder ---

// --- Reminder Row Subview ---
struct ReminderRow: View {
    @EnvironmentObject var appManager: AppManager
    let reminder: Reminder
    let toggleAction: (Reminder) -> Void
    let deleteAction: (Reminder) -> Void
    let editAction: () -> Void

    var isOverdue: Bool {
        guard let date = reminder.scheduledDate, !reminder.isCompleted else { return false }
        return date < Date() // Compare with current time, not just start of day
    }
    
    var isDueToday: Bool {
        guard let date = reminder.scheduledDate, !reminder.isCompleted, !isOverdue else { return false }
        return Calendar.current.isDateInToday(date)
    }
    
    // Computed property to check which tag to show
    var reminderTag: (show: Bool, text: String, color: Color) {
        if reminder.isCompleted {
            return (show: false, text: "", color: .clear)
        } else if isOverdue {
            return (show: true, text: "overdue", color: .red)
        } else if isDueToday {
            return (show: true, text: "due", color: .secondary)
        } else {
            return (show: false, text: "", color: .clear)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Toggle Button (Square)
            Button {
                toggleAction(reminder)
            } label: {
                 let iconName = reminder.isCompleted ? "checkmark.square.fill" : "square"
                 // Use tint color for completed state
                 let iconColor = reminder.isCompleted ? appManager.appTintColor.getColor() : (isOverdue ? Color.red : Color.secondary)
                 Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.title2)
                    .padding(4) 
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) { 
                Text(reminder.taskDescription)
                    .strikethrough(reminder.isCompleted, color: .secondary)
                    .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                
                // HStack for date and separate edit button
                HStack(spacing: 6) { // Increased spacing slightly
                    if let date = reminder.scheduledDate {
                        // Only show date/time without "Overdue" text
                        Text("\(date, style: .date) \(date, style: .time)")
                            .font(.caption)
                            .foregroundColor(isOverdue ? .red : .secondary)
                    } else {
                         Text("No date set") // Revert from "Add Date"
                            .font(.caption)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                    
                    // Separate Edit Button (Calendar Icon)
                    Button {
                        editAction() // Call the edit action closure
                    } label: {
                         Image(systemName: "calendar.circle") // Simple calendar icon
                             .foregroundColor(.accentColor) // Use accent color
                             .font(.caption) // Match font size
                    }
                    .buttonStyle(.plain)
                    
                    // --- Enhanced Tag Logic ---
                    if reminderTag.show {
                        Text(reminderTag.text)
                            .font(.system(.caption2, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(reminderTag.color.opacity(0.15))
                            .foregroundColor(reminderTag.color)
                            .clipShape(Capsule())
                            .padding(.leading, 4) // Add some spacing
                    }
                    // --- End Enhanced Tag Logic ---
                }
            }
            Spacer()
            
            // Improve delete button with larger tap target
            Button {
                deleteAction(reminder)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.7))
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44) // Larger hit area
                    .contentShape(Rectangle()) // Ensure entire frame is tappable
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
        .onLongPressGesture {
            editAction() // Keep long press for edit on the whole row
        }
    }
}
// --- End Reminder Row Subview ---

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Reminder.self, configurations: config)
    
    FreeBuddyView()
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
        .modelContainer(container)
        .onAppear {
            let today = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let future = Calendar.current.date(byAdding: .day, value: 3, to: today)!
            
            // Adjusted examples for optional date
            let exampleReminder1 = Reminder(taskDescription: "Buy groceries", scheduledDate: tomorrow)
            let exampleReminder2 = Reminder(taskDescription: "Call mom - Someday", scheduledDate: nil) // No date
            let exampleReminder3 = Reminder(taskDescription: "Past task - Completed", scheduledDate: yesterday, isCompleted: true)
            let exampleReminder4 = Reminder(taskDescription: "Overdue task", scheduledDate: yesterday)
            let exampleReminder5 = Reminder(taskDescription: "Task for Today", scheduledDate: today)
            let exampleReminder6 = Reminder(taskDescription: "Future Task", scheduledDate: future)
            
            container.mainContext.insert(exampleReminder1)
            container.mainContext.insert(exampleReminder2)
            container.mainContext.insert(exampleReminder3)
            container.mainContext.insert(exampleReminder4)
            container.mainContext.insert(exampleReminder5)
            container.mainContext.insert(exampleReminder6)
        }
} 