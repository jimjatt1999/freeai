//
//  Data.swift
//  free ai
//
//

import SwiftUI
@preconcurrency import SwiftData
import LinkPresentation
import EventKit

// --- NEW: Terminal Style Settings (Moved outside AppManager) ---
enum TerminalColorScheme: String, CaseIterable, Identifiable {
    case green = "Classic Green"
    case amber = "Amber"
    case dosBlue = "IBM DOS Blue"
    case matrix = "Matrix"
    case vintagePaper = "Vintage Paper"
    case futuristic = "Futuristic"
    case windows95 = "Windows 95"
    case gameBoy = "Game Boy Screen" // NEW: Game Boy theme
    
    var id: String { self.rawValue }
    
    // Define colors for each scheme
    var textColor: Color {
        switch self {
        case .green: return .green
        case .amber: return .orange
        case .dosBlue: return Color(red: 0.7, green: 0.7, blue: 1.0) // Light blue/white
        case .matrix: return Color(red: 0.1, green: 1.0, blue: 0.1) // Bright Green
        case .vintagePaper: return Color(hue: 0.1, saturation: 0.6, brightness: 0.3) // Dark Sepia
        case .futuristic: return .cyan // Bright Cyan
        case .windows95: return .black
        case .gameBoy: return Color(red: 0.18, green: 0.31, blue: 0.18) // Dark Green
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .green, .amber: return .black.opacity(0.9)
        case .dosBlue: return Color(red: 0, green: 0, blue: 0.6) // Dark blue
        case .matrix: return .black // , .hacker removed
        case .vintagePaper: return Color(hue: 0.1, saturation: 0.05, brightness: 0.95) // Light Beige
        case .futuristic: return Color(red: 0.05, green: 0.05, blue: 0.15) // Very Dark Blue/Black
        case .windows95: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gameBoy: return Color(red: 0.61, green: 0.73, blue: 0.06) // Light Greenish-Gray
        }
    }
    
    var promptUserColor: Color {
        switch self {
        case .green: return .cyan
        case .amber: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case .dosBlue: return .yellow
        case .matrix: return Color(red: 0.4, green: 1.0, blue: 0.4) // Match text for Matrix
        case .vintagePaper: return Color(hue: 0.1, saturation: 0.7, brightness: 0.2) // Darker Brown
        case .futuristic: return Color(red: 0.8, green: 0.8, blue: 1.0) // Lighter Electric Blue
        case .windows95: return .black
        case .gameBoy: return Color(red: 0.18, green: 0.31, blue: 0.18) // Dark Green (Same as text for GB)
        }
    }
    
    // AI prompt color can often match text color, but can be customized
    var promptAiColor: Color {
        switch self {
            case .futuristic: return Color(red: 0.6, green: 1.0, blue: 1.0) // Slightly different cyan/teal for AI
            case .windows95: return .black
            // Default to text color for most
            default: return textColor
        }
    }
}
// --- End Terminal Style Settings ---

// --- NEW: Window Control Style Enum ---
enum WindowControlStyle: String, CaseIterable, Identifiable {
    case macOS = "macOS"
    case windows = "Windows"
    var id: String { self.rawValue }
}
// --- End Window Control Style Enum ---

// --- NEW: Generation Animation Style Enum ---
enum GenerationAnimationStyle: String, CaseIterable, Identifiable {
    case thinking = "Thinking Indicator"
    case glow = "Pulsating Glow"
    case random = "Random" // Keep random as an option
    var id: String { self.rawValue }
}
// --- END NEW ---

// --- NEW: Reminder Recurrence Enum ---
enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    // case yearly = "Yearly" // Add if needed
    var id: String { self.rawValue }
}
// --- END NEW ---

class AppManager: ObservableObject {
    // @AppStorage("systemPrompt") var systemPrompt = "you are a helpful assistant" // Removed system prompt setting
    @AppStorage("appTintColor") var appTintColor: AppTintColor = .monochrome
    // --- Set Default Font Design to Monospaced --- 
    @AppStorage("appFontDesign") var appFontDesign: AppFontDesign = .monospaced
    // --- End Default Font Change ---
    @AppStorage("appFontSize") var appFontSize: AppFontSize = .medium
    @AppStorage("appFontWidth") var appFontWidth: AppFontWidth = .standard
    @AppStorage("currentModelName") var currentModelName: String?
    @AppStorage("shouldPlayHaptics") var shouldPlayHaptics = true
    @AppStorage("numberOfVisits") var numberOfVisits = 0
    @AppStorage("numberOfVisitsOfLastRequest") var numberOfVisitsOfLastRequest = 0
    
    // --- Add Toggle State for Eyes --- 
    @Published var showNeuraEyes: Bool = true
    // --- End Toggle State ---
    
    // --- Chat Mode State (Moved from ChatView) ---
    @Published var selectedChatMode: ChatMode = .chat
    // --- End Chat Mode State ---
    
    // --- Eye Customization Settings ---
    @AppStorage("eyeShape") var eyeShape: EyeShapeType = .circle
    @AppStorage("eyeOutlineColor") var eyeOutlineColor: AppTintColor = .monochrome
    @AppStorage("eyeBackgroundColor") var eyeBackgroundColor: EyeBackgroundColorType = .white
    @AppStorage("eyeIrisColor") var eyeIrisColor: AppTintColor = .monochrome // Default to monochrome (often black/white)
    @AppStorage("eyeIrisSize") var eyeIrisSize: EyeIrisSizeType = .medium
    @AppStorage("eyeStrokeWidth") var eyeStrokeWidth: EyeStrokeWidthType = .medium
    // --- End Eye Customization Settings ---
    
    // --- NEW: Generation Animation Setting ---
    @AppStorage("generationAnimationStyle") var generationAnimationStyle: GenerationAnimationStyle = .thinking
    // --- END NEW ---
    
    // --- Eye Tap Action Setting ---
    @AppStorage("eyeTapAction") var eyeTapAction: EyeTapActionType = .predefined
    // --- End Eye Tap Action Setting ---
    
    // --- NEW: Setting to show/hide the border around Neura Eyes --- 
    @AppStorage("showNeuraEyesBorder") var showNeuraEyesBorder: Bool = true
    // --- End NEW ---
    
    // --- Buddy Gamification ---
    @AppStorage("buddyXP") var buddyXP: Int = 0
    
    var buddyLevel: Int {
        // Simple level calculation: Level up every 100 XP
        // Level 1: 0-99 XP, Level 2: 100-199 XP, etc.
        // Add 1 because level should start at 1, not 0.
        return (buddyXP / 100) + 1 
    }
    
    var xpTowardsNextLevel: Int {
        // XP accumulated within the current level
        return buddyXP % 100
    }
    
    var xpForNextLevel: Int {
        // Total XP needed to reach the *start* of the next level
        // return buddyLevel * 100 // This is XP needed for *current* level start
        // XP needed for the *next* level is 100
        return 100 // Simple fixed 100 XP per level for now
    }
    
    // --- NEW: Gamification Settings ---
    @AppStorage("xpSystemEnabled") var xpSystemEnabled: Bool = true
    @AppStorage("showXpInUI") var showXpInUI: Bool = true
    // --- END NEW ---
    
    // --- Store Current User Name --- 
    @Published var currentUserName: String? = nil
    // --- End Store Current User Name ---
    
    // --- NEW: Transient State for Note Color Pulse ---
    @Published var transientNoteColorTag: String? = nil
    // --- End Transient State ---
    
    var userInterfaceIdiom: LayoutType {
        #if os(visionOS)
        return .vision
        #elseif os(macOS)
        return .mac
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #else
        return .unknown
        #endif
    }

    enum LayoutType {
        case mac, phone, pad, vision, unknown
    }
        
    private let installedModelsKey = "installedModels"
        
    @Published var installedModels: [String] = [] {
        didSet {
            saveInstalledModelsToUserDefaults()
        }
    }
    
    // --- Terminal Style Properties (References the enum defined outside) ---
    @AppStorage("chatInterfaceStyleEnabled") var chatInterfaceStyleEnabled: Bool = false // Master Toggle, default to false
    @AppStorage("terminalColorScheme") var terminalColorScheme: TerminalColorScheme = .green
    @AppStorage("terminalScanlinesEnabled") var terminalScanlinesEnabled: Bool = true
    @AppStorage("terminalFlickerEnabled") var terminalFlickerEnabled: Bool = true
    @AppStorage("terminalJitterEnabled") var terminalJitterEnabled: Bool = false
    @AppStorage("terminalStaticEnabled") var terminalStaticEnabled: Bool = false
    @AppStorage("terminalBloomEnabled") var terminalBloomEnabled: Bool = false
    @AppStorage("terminalWindowControlsEnabled") var terminalWindowControlsEnabled: Bool = false // Window Buttons Toggle
    @AppStorage("terminalWindowControlsStyle") var terminalWindowControlsStyle: WindowControlStyle = .macOS // Window Button Style
    // --- End Terminal Style Properties ---
    
    // --- NEW: Calendar Integration State ---
    @AppStorage("calendarAccessEnabled") var calendarAccessEnabled: Bool = true // Set default to true
    
    // --- NEW: Data Structures for Topic Management ---
    let commonDiscoverTopics: [String] = [
        "Science", "History", "Technology", "Art", "Nature", "Space", "Philosophy", "Psychology", "Literature", "Music"
    ]
    
    @Published var selectedCommonDiscoverTopics: Set<String> = [] { // Use @Published to update UI
        didSet {
            saveSelectedCommonTopics()
        }
    }
    // --- END NEW ---
    
    // --- NEW: Daily Digest Settings ---
    @AppStorage("dailyDigestShowDiscover") var dailyDigestShowDiscover: Bool = true
    @AppStorage("dailyDigestDiscoverTopics") var dailyDigestDiscoverTopics: String = "science,history,random"
    // --- Add Section Toggles ---
    @AppStorage("dailyDigestShowCalendar") var dailyDigestShowCalendar: Bool = true
    @AppStorage("dailyDigestShowReminders") var dailyDigestShowReminders: Bool = true
    // --- End Section Toggles ---
    // --- END Daily Digest Settings ---
    
    // --- NEW: Daily Digest Cache ---
    @AppStorage("cachedDigestDiscoverContent") var cachedDigestDiscoverContent: String = "" // Default to empty string
    @AppStorage("cachedDigestSummary") var cachedDigestSummary: String = "" // Default to empty string
    @AppStorage("cachedDigestRangeRawValue") var cachedDigestRangeRawValue: String = "" // Default to empty string
    @AppStorage("cachedDigestGenerationTimestamp") var cachedDigestGenerationTimestamp: TimeInterval = 0.0 // Default to 0.0
    // --- END NEW: Daily Digest Cache ---
    
    // --- NEW: Terminal Style Properties (For Daily Digest View) ---
    @AppStorage("dailyDigestTerminalStyleEnabled") var dailyDigestTerminalStyleEnabled: Bool = false // Default OFF
    @AppStorage("dailyDigestColorScheme") var dailyDigestColorScheme: TerminalColorScheme = .green
    @AppStorage("dailyDigestScanlinesEnabled") var dailyDigestScanlinesEnabled: Bool = true
    @AppStorage("dailyDigestFlickerEnabled") var dailyDigestFlickerEnabled: Bool = true
    @AppStorage("dailyDigestJitterEnabled") var dailyDigestJitterEnabled: Bool = false
    @AppStorage("dailyDigestStaticEnabled") var dailyDigestStaticEnabled: Bool = false
    @AppStorage("dailyDigestWindowControlsEnabled") var dailyDigestWindowControlsEnabled: Bool = false
    @AppStorage("dailyDigestWindowControlsStyle") var dailyDigestWindowControlsStyle: WindowControlStyle = .macOS
    @AppStorage("dailyDigestPixelEffectEnabled") var dailyDigestPixelEffectEnabled: Bool = false // NEW: Pixel Effect Toggle
    // --- END NEW ---
    
    init() {
        loadInstalledModelsFromUserDefaults()
        loadSelectedCommonTopics() // Load selected topics on init
    }
    
    func incrementNumberOfVisits() {
        numberOfVisits += 1
        print("app visits: \(numberOfVisits)")
    }
    
    // Function to save the array to UserDefaults as JSON
    private func saveInstalledModelsToUserDefaults() {
        if let jsonData = try? JSONEncoder().encode(installedModels) {
            UserDefaults.standard.set(jsonData, forKey: installedModelsKey)
        }
    }
    
    // Function to load the array from UserDefaults
    private func loadInstalledModelsFromUserDefaults() {
        if let jsonData = UserDefaults.standard.data(forKey: installedModelsKey),
           let decodedArray = try? JSONDecoder().decode([String].self, from: jsonData) {
            self.installedModels = decodedArray
        } else {
            self.installedModels = [] // Default to an empty array if there's no data
        }
    }
    
    func playHaptic() {
        if shouldPlayHaptics {
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
            #endif
        }
    }
    
    // --- NEW: Persistence for Selected Common Topics ---
    private func saveSelectedCommonTopics() {
        // Save the set as an array in UserDefaults
        UserDefaults.standard.set(Array(selectedCommonDiscoverTopics), forKey: "selectedCommonDiscoverTopics")
    }
    
    private func loadSelectedCommonTopics() {
        // Load the array and convert back to a set
        if let loadedArray = UserDefaults.standard.array(forKey: "selectedCommonDiscoverTopics") as? [String] {
            self.selectedCommonDiscoverTopics = Set(loadedArray)
        } else {
            // Default selection if nothing is saved (e.g., first run)
            self.selectedCommonDiscoverTopics = Set(["Science", "History", "Technology"]) 
        }
    }
    // --- END NEW ---
    
    // --- NEW: Award XP Function ---
    func awardXP(points: Int, trigger: String) {
        // Only award if the system is enabled
        guard xpSystemEnabled, points > 0 else { 
            if !xpSystemEnabled { print("XP System Disabled - No XP awarded for \(trigger).") }
            return 
        }
        
        let oldXP = buddyXP
        buddyXP += points
        print("🏆 Awarded \(points) XP for \(trigger)! Total: \(buddyXP)")
        playHaptic() // Provide feedback
        
        // Check for level up (can be moved to a separate function if needed)
        let previousLevel = (oldXP / 100) + 1
        let currentLevel = (buddyXP / 100) + 1
        if currentLevel > previousLevel {
            // TODO: Trigger level up notification/quote display
            // This part currently happens in RemindersView, might need refactoring
            // for a centralized level-up handler.
            print("🎉 Level Up! Reached Level \(currentLevel)")
        }
    }
    // --- END NEW ---
    
    // --- NEW: Reset XP Function ---
    func resetXP() {
        buddyXP = 0
        print("XP Reset to 0.")
        playHaptic()
    }
    // --- END NEW ---
    
    func addInstalledModel(_ model: String) {
        if !installedModels.contains(model) {
            installedModels.append(model)
        }
    }
    
    func modelDisplayName(_ internalName: String) -> String {
        switch internalName {
        case "mlx-community/Llama-3.2-1B-Instruct-4bit":
            // Rename "Free 1B" to "Core 1B"
            return "Core 1B" // Originally: "Free 1B"
        case "mlx-community/Llama-3.2-3B-Instruct-4bit":
            // Rename "Free 3B" to "Core 3B"
            return "Core 3B" // Originally: "Free 3B"
        default:
            return internalName // Fallback to internal name
        }
    }
    
    func getMoonPhaseIcon() -> String {
        // Get current date
        let currentDate = Date()
        
        // Define a base date (known new moon date)
        let baseDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 6))!
        
        // Difference in days between the current date and the base date
        let daysSinceBaseDate = Calendar.current.dateComponents([.day], from: baseDate, to: currentDate).day!
        
        // Moon phase repeats approximately every 29.53 days
        let moonCycleLength = 29.53
        let daysIntoCycle = Double(daysSinceBaseDate).truncatingRemainder(dividingBy: moonCycleLength)
        
        // Determine the phase based on how far into the cycle we are
        switch daysIntoCycle {
        case 0..<1.8457:
            return "moonphase.new.moon" // New Moon
        case 1.8457..<5.536:
            return "moonphase.waxing.crescent" // Waxing Crescent
        case 5.536..<9.228:
            return "moonphase.first.quarter" // First Quarter
        case 9.228..<12.919:
            return "moonphase.waxing.gibbous" // Waxing Gibbous
        case 12.919..<16.610:
            return "moonphase.full.moon" // Full Moon
        case 16.610..<20.302:
            return "moonphase.waning.gibbous" // Waning Gibbous
        case 20.302..<23.993:
            return "moonphase.last.quarter" // Last Quarter
        case 23.993..<27.684:
            return "moonphase.waning.crescent" // Waning Crescent
        default:
            return "moonphase.new.moon" // New Moon (fallback)
        }
    }
}

// --- Chat Mode Enum (Moved from ChatView) ---
enum ChatMode: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case freeDump = "FreeDump"
    case reminders = "Reminders"
    var id: String { self.rawValue }
}
// --- End Chat Mode Enum ---

enum Role: String, Codable {
    case assistant
    case user
    case system
}

@Model
class Message {
    @Attribute(.unique) var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var generatingTime: TimeInterval?
    
    @Relationship(inverse: \Thread.messages) var thread: Thread?
    
    init(role: Role, content: String, thread: Thread? = nil, generatingTime: TimeInterval? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.thread = thread
        self.generatingTime = generatingTime
    }
}

@Model
final class Thread: Sendable {
    @Attribute(.unique) var id: UUID
    var title: String?
    var timestamp: Date
    
    @Relationship var messages: [Message] = []
    
    var sortedMessages: [Message] {
        return messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    init() {
        self.id = UUID()
        self.timestamp = Date()
    }
}

@Model
final class ContentCard: Sendable {
    @Attribute(.unique) var id: UUID
    var content: String
    var topic: String
    var timestamp: Date
    var isSaved: Bool
    var modelName: String?
    
    init(content: String, topic: String, modelName: String? = nil) {
        self.id = UUID()
        self.content = content
        self.topic = topic
        self.timestamp = Date()
        self.isSaved = false
        self.modelName = modelName
    }
}

enum AppTintColor: String, CaseIterable {
    case monochrome, blue, brown, gray, green, indigo, mint, orange, pink, purple, red, teal, yellow
    
    func getColor() -> Color {
        switch self {
        case .monochrome:
            .primary
        case .blue:
            .blue
        case .red:
            .red
        case .green:
            .green
        case .yellow:
            .yellow
        case .brown:
            .brown
        case .gray:
            .gray
        case .indigo:
            .indigo
        case .mint:
            .mint
        case .orange:
            .orange
        case .pink:
            .pink
        case .purple:
            .purple
        case .teal:
            .teal
        }
    }
}

enum AppFontDesign: String, CaseIterable {
    case standard, monospaced, rounded, serif
    
    func getFontDesign() -> Font.Design {
        switch self {
        case .standard:
            .default
        case .monospaced:
            .monospaced
        case .rounded:
            .rounded
        case .serif:
            .serif
        }
    }
}

enum AppFontWidth: String, CaseIterable {
    case compressed, condensed, expanded, standard
    
    func getFontWidth() -> Font.Width {
        switch self {
        case .compressed:
            .compressed
        case .condensed:
            .condensed
        case .expanded:
            .expanded
        case .standard:
            .standard
        }
    }
}

enum AppFontSize: String, CaseIterable {
    case xsmall, small, medium, large, xlarge
    
    func getFontSize() -> DynamicTypeSize {
        switch self {
        case .xsmall:
            .xSmall
        case .small:
            .small
        case .medium:
            .medium
        case .large:
            .large
        case .xlarge:
            .xLarge
        }
    }
}

@Model
class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var occupation: String
    var traits: [String]
    var interests: String
    var customInstructions: String
    var timestamp: Date
    
    init(name: String = "", occupation: String = "", traits: [String] = [], interests: String = "",
         customInstructions: String = "You are a helpful assistant.") {
        self.id = UUID()
        self.name = name
        self.occupation = occupation
        self.traits = traits
        self.interests = interests
        self.customInstructions = customInstructions
        self.timestamp = Date()
        print("Created new UserProfile")
        
        // Save the customization state to user defaults
        let userDefaults = UserDefaults.standard
        let hasCustomization = !name.isEmpty || !occupation.isEmpty || !traits.isEmpty || !interests.isEmpty || customInstructions != "You are a helpful assistant."
        userDefaults.set(hasCustomization, forKey: "customizationEnabled")
    }
    
    func getAvailableTraits() -> [String] {
        return ["Chatty", "Witty", "Straight shooting", "Encouraging", "Analytical", "Creative", "Concise"]
    }
    
    func hasCustomization() -> Bool {
        return !name.isEmpty || !occupation.isEmpty || !traits.isEmpty || !interests.isEmpty || customInstructions != "You are a helpful assistant."
    }
    
    func updateCustomizationEnabled(enabled: Bool, name: String = "", occupation: String = "", traits: [String] = [], interests: String = "", customInstructions: String = "You are a helpful assistant.") {
        if enabled {
            self.name = name
            self.occupation = occupation
            self.traits = traits
            self.interests = interests
            self.customInstructions = customInstructions
        } else {
            self.name = ""
            self.occupation = ""
            self.traits = []
            self.interests = ""
            self.customInstructions = "You are a helpful assistant."
        }
        UserDefaults.standard.set(enabled, forKey: "customizationEnabled")
    }
}

extension AppManager {
    func createAugmentedSystemPrompt(originalPrompt: String, userProfile: UserProfile?) -> String {
        guard let userProfile = userProfile else { return originalPrompt }
        
        var augmentedPrompt = userProfile.customInstructions
        
        // Add user information
        if !userProfile.name.isEmpty {
            augmentedPrompt += "\n\nThe user's name is \(userProfile.name)."
        }
        
        if !userProfile.occupation.isEmpty {
            augmentedPrompt += " They work as \(userProfile.occupation)."
        }
        
        // Add traits if available
        if !userProfile.traits.isEmpty {
            augmentedPrompt += "\n\nWhen responding, be "
            augmentedPrompt += userProfile.traits.joined(separator: ", ")
            augmentedPrompt += "."
        }
        
        // Add interests if available
        if !userProfile.interests.isEmpty {
            augmentedPrompt += "\n\nThe user has mentioned these interests: \(userProfile.interests)"
        }
        
        return augmentedPrompt
    }
}

@Model
class DumpNote {
    var id: UUID
    var rawContent: String
    var structuredContent: String
    var title: String
    var tags: [String]
    var timestamp: Date
    var modelName: String?
    var isProcessing: Bool
    var isPinned: Bool
    
    // --- New Properties for Google Keep features ---
    var colorTag: String? // Store hex color string or a predefined key
    var linkURL: String?
    var linkTitle: String?
    var linkImageURL: String?
    // --- End New Properties ---
    
    // --- NEW: Audio Note Properties ---
    var audioFilename: String? // Store filename relative to Documents dir
    var transcription: String?
    // --- End Audio Note Properties ---
    
    init(rawContent: String, structuredContent: String = "", title: String = "", tags: [String] = [], modelName: String? = nil, isPinned: Bool = false, colorTag: String? = nil, audioFilename: String? = nil, transcription: String? = nil) {
        self.id = UUID()
        self.rawContent = rawContent
        self.structuredContent = structuredContent
        self.title = title
        self.tags = tags
        self.timestamp = Date()
        self.modelName = modelName
        self.isProcessing = false
        self.isPinned = isPinned
        self.colorTag = colorTag
        // Link properties will be populated later by a separate process
        self.audioFilename = audioFilename // Initialize audio filename
        self.transcription = transcription // Initialize transcription
    }
}

// --- Link Metadata Fetcher --- 
class LinkMetadataFetcher {
    // Function to detect the first URL in a string
    static func detectURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        // Find the first match that is a valid URL
        for match in matches ?? [] {
            if let url = match.url {
                return url
            }
        }
        return nil
    }

    // Function to fetch metadata for a given URL
    @MainActor // Ensure metadata updates happen on the main thread
    static func fetchMetadata(for url: URL) async -> (title: String?, imageURL: String?) {
        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            var fetchedImageURL: String? = nil

            // Try to get an image provider and save it temporarily to get a URL
            if let imageProvider = metadata.imageProvider {
                 let tempImageURL = await saveImageTemporarily(imageProvider: imageProvider)
                 fetchedImageURL = tempImageURL?.absoluteString
             }

            return (metadata.title, fetchedImageURL)
        } catch {
            print("Error fetching link metadata for \(url): \(error)")
            return (nil, nil)
        }
    }
    
    // Helper to save image from NSItemProvider to a temporary file
    private static func saveImageTemporarily(imageProvider: NSItemProvider) async -> URL? {
        guard imageProvider.hasItemConformingToTypeIdentifier("public.image") else { return nil }
        
        do {
            let item = try await imageProvider.loadItem(forTypeIdentifier: "public.image", options: nil)
            
            var imageData: Data? = nil
            if let data = item as? Data {
                imageData = data
            } else if let image = item as? UIImage {
                imageData = image.pngData() // Or jpegData
            } else if let imageURL = item as? URL,
                      let dataFromURL = try? Data(contentsOf: imageURL) {
                imageData = dataFromURL
            }
            
            guard let finalImageData = imageData else { return nil }
            
            // Create a unique temporary file URL
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".png" // Assume png for simplicity
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            // Write the data
            try finalImageData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error processing image provider: \(error)")
            return nil
        }
    }
}
// --- End Link Metadata Fetcher ---

// --- Eye Customization Enums ---

enum EyeShapeType: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case oval = "Oval"
    case square = "Square"
    var id: String { self.rawValue }
}

enum EyeBackgroundColorType: String, CaseIterable, Identifiable {
    case white = "White"
    case black = "Black"
    case adaptive = "Adaptive"
    var id: String { self.rawValue }
}

enum EyeIrisSizeType: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    var id: String { self.rawValue }
}

enum EyeStrokeWidthType: String, CaseIterable, Identifiable {
    case thin = "Thin"
    case medium = "Medium"
    case thick = "Thick"
    var id: String { self.rawValue }
}

// --- End Eye Customization Enums ---

// --- Eye Tap Action Enum ---
enum EyeTapActionType: String, CaseIterable, Identifiable {
    case none = "None"
    case blink = "Blink"
    case predefined = "Message" // Simple predefined messages
    var id: String { self.rawValue }
}
// --- End Eye Tap Action Enum ---

// --- Reminder Model ---
@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var taskDescription: String
    var scheduledDate: Date?
    var isCompleted: Bool
    var creationDate: Date
    var xpAwarded: Bool
    var recurrence: RecurrenceRule?
    
    init(id: UUID = UUID(), taskDescription: String, scheduledDate: Date?, isCompleted: Bool = false, creationDate: Date = Date(), xpAwarded: Bool = false, recurrence: RecurrenceRule? = nil) {
        self.id = id
        self.taskDescription = taskDescription
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
        self.creationDate = creationDate
        self.xpAwarded = xpAwarded
        self.recurrence = recurrence
    }
}
// --- End Reminder Model ---

// --- NEW: Calendar Event Fetching Logic --- 
extension AppManager {
    // Helper function to format events for the context string
    private func formatEvent(_ event: EKEvent, relativeTo date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short // Only show time

        // Use relative date formatting for today/tomorrow
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true

        let title = event.title ?? "Untitled Event"
        let start = formatter.string(from: event.startDate)
        var eventString = "- \(title) on \(start)" // Changed 'at' to 'on' for clarity with relative dates
        if let location = event.location, !location.isEmpty {
             eventString += " (Location: \(location))"
         }
        return eventString + "\n"
    }


    func fetchCalendarEvents(for range: Calendar.Component = .month, value: Int = 1) async -> String { // Default to 1 month
        // First check and request permission if needed
        if await requestCalendarAccessIfNeeded() == false {
            return "Calendar access is required for this feature. Please grant access in Settings app."
        }
        
        let eventStore = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)

        guard status == .fullAccess || status == .writeOnly else {
            print("Calendar access not authorized during fetch attempt.")
            return "Calendar access not authorized. Please enable in Settings app." // Return informative message
        }

        // Define date ranges
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        guard let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart),
              let nextWeekEnd = Calendar.current.date(byAdding: .day, value: 7, to: todayStart),
              let rangeEnd = Calendar.current.date(byAdding: range, value: value, to: todayStart) else { // Use the specified range
            return ""
        }

        // Fetch events for the entire range
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: todayStart, end: rangeEnd, calendars: calendars)
        let allEvents = eventStore.events(matching: predicate).sorted(by: { $0.startDate < $1.startDate })

        // Filter events into time buckets
        let todayEvents = allEvents.filter { $0.startDate >= todayStart && $0.startDate < todayEnd }
        let thisWeekEvents = allEvents.filter { $0.startDate >= todayEnd && $0.startDate < nextWeekEnd } // Events after today but within 7 days
        let laterEvents = allEvents.filter { $0.startDate >= nextWeekEnd && $0.startDate < rangeEnd } // Events after 7 days

        var contextSections: [String] = []

        // Format Today's Events
        if !todayEvents.isEmpty {
            var section = "## Today's Schedule\n"
            todayEvents.prefix(20).forEach { section += formatEvent($0, relativeTo: now) } // Limit to 20
            contextSections.append(section)
        }

        // Format Next 7 Days Events
        if !thisWeekEvents.isEmpty {
            var section = "## Next 7 Days (After Today)\n"
            thisWeekEvents.prefix(20).forEach { section += formatEvent($0, relativeTo: now) } // Limit to 20
            contextSections.append(section)
        }

        // Format Later Events (Rest of the Range)
        if !laterEvents.isEmpty {
            // Simplified title for the default month fetch range
            let laterTitle = "Rest of the Month"
            var section = "## \(laterTitle) (After Next 7 Days)\n"
            laterEvents.prefix(20).forEach { section += formatEvent($0, relativeTo: now) } // Limit to 20
            contextSections.append(section)
        }

        guard !contextSections.isEmpty else { return "No relevant events found in the upcoming schedule." }

        return "CONTEXT: User's upcoming schedule:\n" + contextSections.joined(separator: "\n") // Add newline between sections
    }
    
    // Helper method to request calendar access when needed
    func requestCalendarAccessIfNeeded() async -> Bool {
        let eventStore = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .notDetermined:
            // First time using a calendar feature - request access
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                DispatchQueue.main.async {
                    self.calendarAccessEnabled = granted
                    print("Calendar access request result: \(granted ? "granted" : "denied")")
                }
                return granted
            } catch {
                print("Error requesting calendar access: \(error)")
                DispatchQueue.main.async {
                    self.calendarAccessEnabled = false
                }
                return false
            }
        case .restricted, .denied:
            print("Calendar access is restricted or denied.")
            DispatchQueue.main.async {
                self.calendarAccessEnabled = false
            }
            return false
        case .fullAccess, .writeOnly:
            print("Calendar access already authorized.")
            DispatchQueue.main.async {
                self.calendarAccessEnabled = true
            }
            return true
        @unknown default:
            print("Unknown calendar authorization status.")
            DispatchQueue.main.async {
                self.calendarAccessEnabled = false
            }
            return false
        }
    }
    
    // --- NEW: Reminder Fetching for Digest ---
    func fetchRelevantReminders() async -> String {
        // Note: This requires access to the ModelContext, which AppManager doesn't 
        // have directly. This logic might be better placed in the View or passed 
        // the ModelContext.
        // For now, let's return a placeholder. We'll need to refactor this.
        print("Placeholder: fetchRelevantReminders() called. Needs ModelContext.")
        // TODO: Implement actual fetching using ModelContext
        // Example structure:
        // let now = Date()
        // let todayStart = Calendar.current.startOfDay(for: now)
        // guard let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) else { return "" }
        // let predicate = #Predicate<Reminder> { reminder in
        //     !reminder.isCompleted && (reminder.scheduledDate == nil || reminder.scheduledDate! < todayEnd)
        // }
        // let descriptor = FetchDescriptor<Reminder>(predicate: predicate, sortBy: [SortDescriptor(\.scheduledDate)])
        // let fetchedReminders = try? modelContext.fetch(descriptor) ... etc.
        return "\n## Pending/Overdue Reminders\n- Reminder fetching needs ModelContext implementation.\n"
    }
    // --- END NEW ---
    
    // --- NEW: Recent Notes Fetching for Digest ---
    func fetchYesterdaysNoteTitles() async -> String {
        // Similar to reminders, this needs ModelContext.
        print("Placeholder: fetchYesterdaysNoteTitles() called. Needs ModelContext.")
        // TODO: Implement actual fetching using ModelContext
        // Example structure:
        // guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return "" }
        // let predicate = #Predicate<DumpNote> { $0.timestamp >= yesterday }
        // let descriptor = FetchDescriptor<DumpNote>(predicate: predicate, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        // let fetchedNotes = try? modelContext.fetch(descriptor)
        // let titles = fetchedNotes?.map { $0.title.isEmpty ? "Untitled Note" : $0.title } ... etc.
        return "\n## Notes Created Yesterday\n- Note fetching needs ModelContext implementation.\n"
    }
    // --- END NEW ---
}
// --- END Calendar/Digest Fetching Logic ---

// --- NEW: Digest Theme Enum ---
enum DigestTheme: String, CaseIterable, Identifiable {
    case system = "System Default"
    case gameScreen = "Game Screen"
    // Add more themes later if desired
    
    var id: String { self.rawValue }
}
// --- END NEW ---
