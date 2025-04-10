//
//  Data.swift
//  free ai
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
@preconcurrency import SwiftData
import LinkPresentation

// --- NEW: Terminal Style Settings (Moved outside AppManager) ---
enum TerminalColorScheme: String, CaseIterable, Identifiable {
    case green = "Classic Green"
    case amber = "Amber"
    case dosBlue = "IBM DOS Blue"
    case matrix = "Matrix"
    case vintagePaper = "Vintage Paper"
    case futuristic = "Futuristic"
    case windows95 = "Windows 95"
    
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

class AppManager: ObservableObject {
    @AppStorage("systemPrompt") var systemPrompt = "you are a helpful assistant"
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
    @Published var showAnimatedEyes: Bool = true
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
    
    // --- Eye Tap Action Setting ---
    @AppStorage("eyeTapAction") var eyeTapAction: EyeTapActionType = .blink // Default to blink
    // --- End Eye Tap Action Setting ---
    
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
    // --- End Buddy Gamification ---
    
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
    @AppStorage("chatInterfaceStyleEnabled") var chatInterfaceStyleEnabled: Bool = true // Master Toggle
    @AppStorage("terminalColorScheme") var terminalColorScheme: TerminalColorScheme = .green
    @AppStorage("terminalScanlinesEnabled") var terminalScanlinesEnabled: Bool = true
    @AppStorage("terminalFlickerEnabled") var terminalFlickerEnabled: Bool = true
    @AppStorage("terminalJitterEnabled") var terminalJitterEnabled: Bool = false
    @AppStorage("terminalStaticEnabled") var terminalStaticEnabled: Bool = false
    @AppStorage("terminalBloomEnabled") var terminalBloomEnabled: Bool = false
    @AppStorage("terminalWindowControlsEnabled") var terminalWindowControlsEnabled: Bool = false // Window Buttons Toggle
    @AppStorage("terminalWindowControlsStyle") var terminalWindowControlsStyle: WindowControlStyle = .macOS // Window Button Style
    // --- End Terminal Style Properties ---
    
    init() {
        loadInstalledModelsFromUserDefaults()
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
    
    func addInstalledModel(_ model: String) {
        if !installedModels.contains(model) {
            installedModels.append(model)
        }
    }
    
    func modelDisplayName(_ modelName: String) -> String {
        // Custom display names for more legitimate branding
        if modelName.contains("Llama-3.2-1B") {
            return "Free 1B"
        } else if modelName.contains("Llama-3.2-3B") {
            return "Free 3B"
        } else {
            // Default fallback for any other models
            return modelName.replacingOccurrences(of: "mlx-community/", with: "")
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

// --- Context Type Enum (Moved from ChatView) ---
enum ContextType { case notes, reminders }
// --- End Context Type Enum ---

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

    init(id: UUID = UUID(), taskDescription: String, scheduledDate: Date?, isCompleted: Bool = false, creationDate: Date = Date(), xpAwarded: Bool = false) {
        self.id = id
        self.taskDescription = taskDescription
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
        self.creationDate = creationDate
        self.xpAwarded = xpAwarded
    }
}
// --- End Reminder Model ---
