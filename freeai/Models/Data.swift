//
//  Data.swift
//  free ai
//
//  Created by Jordan Singer on 10/5/24.
//

import SwiftUI
import SwiftData

class AppManager: ObservableObject {
    @AppStorage("systemPrompt") var systemPrompt = "you are a helpful assistant"
    @AppStorage("appTintColor") var appTintColor: AppTintColor = .monochrome
    @AppStorage("appFontDesign") var appFontDesign: AppFontDesign = .standard
    @AppStorage("appFontSize") var appFontSize: AppFontSize = .medium
    @AppStorage("appFontWidth") var appFontWidth: AppFontWidth = .standard
    @AppStorage("currentModelName") var currentModelName: String?
    @AppStorage("shouldPlayHaptics") var shouldPlayHaptics = true
    @AppStorage("numberOfVisits") var numberOfVisits = 0
    @AppStorage("numberOfVisitsOfLastRequest") var numberOfVisitsOfLastRequest = 0
    @AppStorage("freeModeTopic") var freeModeTopic: String = ""
    @AppStorage("freeModePreferences") var freeModePreferences: String = ""
    @AppStorage("freeModeModelName") var freeModeModelName: String?
    @AppStorage("topicsCombinationMode") var topicsCombinationMode: String = "single" // Options: single, pair, triple
    @AppStorage("contentLengthMode") var contentLengthMode: String = "medium" // Options: minimalist, brief, medium, detailed
    @AppStorage("chatAnimationStyle") var chatAnimationStyle: String = "fade" // Options: fade, bounce, typewriter, terminal, minimalist, retro, futuristic, handwritten, comic, none
    @AppStorage("freestyleCardStyle") var freestyleCardStyle: String = "minimalist" // Options: fade, bounce, typewriter, terminal, minimalist, retro, futuristic, handwritten, comic, none
    
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
        return modelName.replacingOccurrences(of: "mlx-community/", with: "").lowercased()
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
