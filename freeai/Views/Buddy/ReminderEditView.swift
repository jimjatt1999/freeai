import SwiftUI
import SwiftData
import UserNotifications // Needed for rescheduling

struct ReminderEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var appManager: AppManager // If needed for haptics etc.

    // Use @Bindable for direct modification of the Reminder object
    // This requires importing Observation framework if not implicitly available
    @Bindable var reminder: Reminder

    // Local state for the date picker component
    @State private var includeDate: Bool
    @State private var selectedDate: Date

    init(reminder: Reminder) {
        self.reminder = reminder
        // Initialize local state based on the passed reminder
        if let date = reminder.scheduledDate {
            _includeDate = State(initialValue: true)
            _selectedDate = State(initialValue: date)
        } else {
            _includeDate = State(initialValue: false)
            _selectedDate = State(initialValue: Date()) // Default to now if no date
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Task Description
                Section("Task") {
                    TextField("What needs to be done?", text: $reminder.taskDescription, axis: .vertical)
                        .lineLimit(3...)
                }

                // Date and Time
                Section("Date & Time") {
                    Toggle("Include Date & Time", isOn: $includeDate.animation())

                    if includeDate {
                        DatePicker("Due Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                             // Use .graphical on macOS/iPad for better experience, compact on iPhone
                            #if os(iOS)
                            .datePickerStyle(.graphical)
                            #else
                            .datePickerStyle(.graphical) // Or choose another style like .field
                            #endif
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { // Add cancel role
                        // Note: Changes made via @Bindable are immediate.
                        // A true cancel might require manually reverting changes if needed,
                        // or using temporary local state instead of @Bindable.
                        // For now, dismiss just closes the sheet.
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(reminder.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        // Update the reminder's date based on the toggle and picker
        if includeDate {
            // Only update if the date actually changed or was toggled on
            if reminder.scheduledDate != selectedDate || reminder.scheduledDate == nil {
                 reminder.scheduledDate = selectedDate
            }
        } else {
            reminder.scheduledDate = nil
        }

        // --- Reschedule/Cancel Notification ---
        // 1. Always remove any existing notification first
         UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])

        // 2. Schedule a new one *only* if a valid future date is now set
        if let newDate = reminder.scheduledDate, newDate > Date() {
            scheduleNotification(reminder: reminder)
        }
        // --- End Reschedule ---

        // Explicit save might be needed depending on context
        // but often @Bindable + modelContext handles it.
        // try? modelContext.save()

        appManager.playHaptic()
        print("Reminder updated: \(reminder.taskDescription)")
    }

    // Copy scheduleNotification here for now (Needs refactoring ideally)
    private func scheduleNotification(reminder: Reminder) {
        guard let scheduledDate = reminder.scheduledDate else { return }
        guard scheduledDate > Date() else { return } // Ensure future date

        let content = UNMutableNotificationContent()
        content.title = "FreeBuddy Reminder"
        content.body = reminder.taskDescription
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: scheduledDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error rescheduling notification: \(error.localizedDescription)") }
            else { print("Notification rescheduled successfully for reminder: \(reminder.id)") }
        }
    }
}

// Optional Preview for Edit View
/*
#Preview {
    // Need to create a dummy reminder in an in-memory container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Reminder.self, configurations: config)
    let sampleReminder = Reminder(taskDescription: "Sample Edit Task", scheduledDate: Date())
    container.mainContext.insert(sampleReminder)
    
    return ReminderEditView(reminder: sampleReminder)
        .modelContainer(container)
        .environmentObject(AppManager())
}
*/ 