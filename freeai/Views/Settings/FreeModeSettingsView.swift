//
//  FreeModeSettingsView.swift
//  free ai
//
//  Created by Jordan Singer on 4/8/24.
//

import SwiftUI
import SwiftData

struct FreeModeSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Query private var contentCards: [ContentCard]
    @State private var showingSavedCards = false
    
    @State private var topicInput: String = ""
    @State private var preferencesInput: String = ""
    @State private var showDeleteConfirmation = false
    @State private var topicsCombinationMode: String = "single"
    @State private var contentLengthMode: String = "medium"
    
    // Wide range of popular topics for quick selection
    let popularTopics = [
        "Science", "History", "Technology", "Art", "Philosophy", 
        "Psychology", "Space", "Nature", "Food", "Travel",
        "Music", "Literature", "Sports", "Health", "Politics",
        "Economics", "Religion", "Culture", "Animals", "Environment",
        "Architecture", "Photography", "Fashion", "Film", "Gaming"
    ]
    
    var body: some View {
        Form {
            // Topic section
            Section(header: Text("TOPICS OF INTEREST")) {
                TextField("e.g., science, philosophy, art", text: $topicInput)
                    .onChange(of: topicInput) { _, newValue in
                        appManager.freeModeTopic = newValue
                    }
                
                // Topic quick selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(popularTopics, id: \.self) { topic in
                            TopicButton(topic: topic, isSelected: topicInput.lowercased().contains(topic.lowercased())) {
                                if topicInput.isEmpty {
                                    topicInput = topic
                                } else if !topicInput.lowercased().contains(topic.lowercased()) {
                                    // Add topic if not already included
                                    topicInput = topicInput + ", " + topic
                                } else {
                                    // Remove topic if already included (deselection)
                                    let topics = topicInput.components(separatedBy: ", ")
                                    let filteredTopics = topics.filter { !$0.lowercased().contains(topic.lowercased()) }
                                    topicInput = filteredTopics.joined(separator: ", ")
                                    
                                    // Clean up any trailing commas or extra spaces
                                    topicInput = topicInput.trimmingCharacters(in: .whitespaces)
                                    if topicInput.hasSuffix(",") {
                                        topicInput.removeLast()
                                        topicInput = topicInput.trimmingCharacters(in: .whitespaces)
                                    }
                                }
                                appManager.freeModeTopic = topicInput
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Content Style section
            Section(header: Text("CONTENT STYLE")) {
                Picker("Style", selection: $preferencesInput) {
                    Text("Surprising Facts").tag("Provide surprising and lesser-known facts that challenge common assumptions.")
                    Text("Mind-blowing Ideas").tag("Focus on thought-provoking ideas that expand perspective.")
                    Text("Historical Insights").tag("Share fascinating historical insights and connections.")
                    Text("Future Trends").tag("Discuss emerging trends and future possibilities.")
                    Text("Creative Prompts").tag("Offer creative thought experiments and mental frameworks.")
                    Text("Gen Z Style").tag("Express complex ideas using Gen Z slang, internet humor, and abbreviated language patterns.")
                    Text("ELI5").tag("Explain Like I'm 5 - break down complex topics into ultra-simple terms anyone could understand.")
                    Text("Contrarian View").tag("Present a thoughtful counterpoint to the mainstream view on this topic.")
                    Text("Analogies & Metaphors").tag("Explain the topic through creative analogies and metaphors to make it more relatable.")
                }
                .pickerStyle(.navigationLink)
                .onChange(of: preferencesInput) { _, newValue in
                    appManager.freeModePreferences = newValue
                }
            }
            
            // Topic combination section
            Section(header: Text("TOPIC COMBINATION")) {
                Picker("Mode", selection: $topicsCombinationMode) {
                    Text("Focus on Single Topic").tag("single")
                    Text("Combine Two Topics").tag("pair")
                    Text("Combine Three Topics").tag("triple")
                }
                .pickerStyle(.navigationLink)
                .onChange(of: topicsCombinationMode) { _, newValue in
                    appManager.topicsCombinationMode = newValue
                }
            }
            
            // Content length section
            Section(header: Text("CONTENT LENGTH")) {
                Picker("Length", selection: $contentLengthMode) {
                    Text("Minimalist").tag("minimalist")
                    Text("Brief").tag("brief")
                    Text("Medium").tag("medium")
                    Text("Detailed").tag("detailed")
                }
                .pickerStyle(.navigationLink)
                .onChange(of: contentLengthMode) { _, newValue in
                    appManager.contentLengthMode = newValue
                }
            }
            
            // Card design section
            Section(header: Text("CARD INTERFACE DESIGN")) {
                Picker("Style", selection: $appManager.freestyleCardStyle) {
                    Text("Minimalist").tag("minimalist")
                    Text("Terminal").tag("terminal")
                    Text("Retro").tag("retro")
                    Text("Futuristic").tag("futuristic")
                    Text("Handwritten").tag("handwritten")
                    Text("Comic").tag("comic")
                    Text("None").tag("none")
                }
                .pickerStyle(.navigationLink)
                
                Text("Note: Animation styles (Fade, Bounce, Typewriter) are only available in Chat where text is streamed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Model section
            Section(header: Text("MODEL")) {
                NavigationLink(destination: ModelsSettingsView(isForFreeMode: true)) {
                    Label {
                        Text("Model")
                            .fixedSize()
                    } icon: {
                        Image(systemName: "square.text.square")
                    }
                    .badge(appManager.modelDisplayName(appManager.freeModeModelName ?? appManager.currentModelName ?? ""))
                }
            }
            
            // Content management
            Section(header: Text("CONTENT MANAGEMENT")) {
                if contentCards.count > 0 {
                    NavigationLink(destination: savedCardsView) {
                        Label("Saved Items", systemImage: "bookmark")
                            .badge(contentCards.filter { $0.isSaved }.count)
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Clear All Content", systemImage: "trash")
                    }
                } else {
                    Text("No content generated yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Freestyle")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // Load saved values
            topicInput = appManager.freeModeTopic
            preferencesInput = appManager.freeModePreferences
            topicsCombinationMode = appManager.topicsCombinationMode
            contentLengthMode = appManager.contentLengthMode
            
            // Set default content style if empty
            if preferencesInput.isEmpty {
                preferencesInput = "Provide surprising and lesser-known facts that challenge common assumptions."
                appManager.freeModePreferences = preferencesInput
            }
        }
        .alert("Clear All Content?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllContent()
            }
        } message: {
            Text("This will permanently delete all content cards. This action cannot be undone.")
        }
    }
    
    private var savedCardsView: some View {
        List {
            ForEach(contentCards.filter { $0.isSaved }.sorted(by: { $0.timestamp > $1.timestamp })) { card in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(card.topic)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(timeAgo(from: card.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(card.content)
                        .lineLimit(3)
                    
                    if let modelName = card.modelName {
                        HStack {
                            Spacer()
                            Text(appManager.modelDisplayName(modelName))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(card)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        card.isSaved.toggle()
                    } label: {
                        Label("Unsave", systemImage: "bookmark.slash")
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Saved Content")
    }
    
    private func deleteAllContent() {
        for card in contentCards {
            modelContext.delete(card)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        FreeModeSettingsView()
            .environmentObject(AppManager())
            .environment(LLMEvaluator())
    }
}

// Topic button for quick selection
struct TopicButton: View {
    let topic: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(topic)
                    .font(.footnote)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
} 