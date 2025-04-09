//
//  FreeModeView.swift
//  free ai
//
//

import SwiftUI
import SwiftData
import MarkdownUI
import MLXLMCommon

struct FreeModeView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Environment(LLMEvaluator.self) var llm
    @Query private var contentCards: [ContentCard]
    
    @State private var showTopicInput = false
    @State private var showModelPicker = false
    @State private var isGenerating = false
    @State private var topicInput = ""
    @State private var preferencesInput = "Provide surprising and lesser-known facts that challenge common assumptions."
    @State private var showingSavedCards = false
    @State private var showCustomPromptSheet = false
    @State private var customPrompt = ""
    @State private var useSelectedTopics = true
    @State private var useCustomPromptOverride = false
    @Binding var showChat: Bool
    @Binding var currentThread: Thread?
    
    // Wide range of popular topics for quick selection
    let popularTopics = [
        "Science", "History", "Technology", "Art", "Philosophy", 
        "Psychology", "Space", "Nature", "Food", "Travel",
        "Music", "Literature", "Sports", "Health", "Politics",
        "Economics", "Religion", "Culture", "Animals", "Environment",
        "Architecture", "Photography", "Fashion", "Film", "Gaming"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with lowercased name - always at top
                HStack {
                    Button {
                        showChat = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    Text("freestyle")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        // Saved/All toggle
                        Button {
                            appManager.playHaptic()
                            showingSavedCards.toggle()
                        } label: {
                            Image(systemName: showingSavedCards ? "bookmark.fill" : "bookmark")
                                .foregroundColor(.blue)
                        }
                        
                        // Settings
                        NavigationLink(destination: FreeModeSettingsView()) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18))
                        }
                    }
                }
                .padding()
                
                // Content area - fill remaining space with a ZStack that positions empty state correctly
                ZStack {
                    if contentCards.isEmpty {
                        ScrollView {
                            emptyStateView
                                .frame(minHeight: UIScreen.main.bounds.height * 0.7) // Ensure proper spacing
                        }
                    } else {
                        contentListView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Floating action button
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        generateButton
                            .padding()
                    }
                }
            )
            .navigationBarHidden(true)
            .sheet(isPresented: $showTopicInput) {
                topicInputView
            }
            .sheet(isPresented: $showModelPicker) {
                modelPickerView
            }
            .sheet(isPresented: $showCustomPromptSheet) {
                customPromptView
            }
            .toolbar {
                // Model picker in toolbar
                ToolbarItem(placement: .principal) {
                    modelPickerButton
                }
            }
            .onAppear {
                // Set initial values from AppManager
                topicInput = appManager.freeModeTopic
                preferencesInput = appManager.freeModePreferences
                
                // Set default model if needed
                if appManager.freeModeModelName == nil && appManager.currentModelName != nil {
                    appManager.freeModeModelName = appManager.currentModelName
                }
            }
        }
    }
    
    // Empty state view when no cards are available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.text.square")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.7))
            
            Text("Welcome to freestyle")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Explore interesting content based on your topics of interest.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button {
                appManager.playHaptic()
                showTopicInput = true
            } label: {
                Text("Set Your Preferences")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.top)
        }
        .padding()
    }
    
    // Content list view showing generated cards
    private var contentListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                // Filter status indicator
                if showingSavedCards {
                    HStack {
                        Spacer()
                        Text("Showing Saved Cards")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2)
                            )
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                
                // Cards list
                LazyVStack(spacing: 16) {
                    ForEach(showingSavedCards 
                            ? contentCards.filter({ $0.isSaved }).sorted(by: { $0.timestamp > $1.timestamp })
                            : contentCards.sorted(by: { $0.timestamp > $1.timestamp })) { card in
                        ContentCardView(contentCard: card, showChat: $showChat, currentThread: $currentThread)
                            .environmentObject(appManager)
                            .environment(\.modelContext, modelContext)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
    
    // Generate button to create new content
    private var generateButton: some View {
        Button {
            appManager.playHaptic()
            if topicInput.isEmpty && preferencesInput.isEmpty {
                showTopicInput = true
            } else {
                generateContent()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: "square.text.square.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(isGenerating)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    appManager.playHaptic()
                    customPrompt = ""
                    showCustomPromptSheet = true
                }
        )
    }
    
    // Model picker button
    private var modelPickerButton: some View {
        Button {
            appManager.playHaptic()
            showModelPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Text(String(appManager.modelDisplayName(appManager.freeModeModelName ?? appManager.currentModelName ?? "").prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text(appManager.modelDisplayName(appManager.freeModeModelName ?? appManager.currentModelName ?? ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // Topic input sheet view
    private var topicInputView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Topics of Interest")
                    .font(.headline)
                    .padding(.top)
                
                TextField("e.g., science, philosophy, art", text: $topicInput)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                
                // Popular topics
                Text("Popular Topics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Topic quick selection
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 10)
                        ], spacing: 10) {
                            ForEach(popularTopics, id: \.self) { topic in
                                TopicButton(
                                    topic: topic,
                                    isSelected: topicInput.lowercased().contains(topic.lowercased())
                                ) {
                                    if topicInput.isEmpty {
                                        topicInput = topic
                                    } else if !topicInput.lowercased().contains(topic.lowercased()) {
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
                                }
                            }
                        }
                    }
                }
                
                Text("Content Style")
                    .font(.headline)
                
                Picker("Content Style", selection: $preferencesInput) {
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
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Content Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appManager.freeModeTopic = topicInput
                        appManager.freeModePreferences = preferencesInput
                        showTopicInput = false
                        
                        if contentCards.isEmpty {
                            generateContent()
                        }
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Restore previous values
                        topicInput = appManager.freeModeTopic
                        preferencesInput = appManager.freeModePreferences
                        showTopicInput = false
                    }
                }
            }
        }
    }
    
    // Model picker sheet view
    private var modelPickerView: some View {
        NavigationView {
            List {
                ForEach(appManager.installedModels, id: \.self) { modelName in
                    ModelPickerRow(
                        modelName: modelName,
                        isSelected: modelName == appManager.freeModeModelName,
                        onSelect: {
                            appManager.freeModeModelName = modelName
                            showModelPicker = false
                        }
                    )
                    .environmentObject(appManager)
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showModelPicker = false
                    }
                }
            }
        }
    }
    
    // Custom prompt sheet view
    private var customPromptView: some View {
        NavigationView {
            Form {
                Section(header: Text("TOPICS")) {
                    // Topic selection
                    if !topicInput.isEmpty {
                        HStack {
                            Text("Current Topics:")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(topicInput)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Use Selected Topics", isOn: $useSelectedTopics)
                        .disabled(topicInput.isEmpty)
                    
                    Button("Choose Different Topics") {
                        showTopicInput = true
                        // We'll keep the custom prompt sheet open
                    }
                }
                
                Section(header: Text("CONTENT LENGTH")) {
                    Picker("Length", selection: $appManager.contentLengthMode) {
                        Text("Minimalist (50 words)").tag("minimalist")
                        Text("Brief (80 words)").tag("brief")
                        Text("Medium (150 words)").tag("medium")
                        Text("Detailed (300 words)").tag("detailed")
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("STYLE OPTIONS")) {
                    Picker("Content Style", selection: $preferencesInput) {
                        Text("Surprising Facts").tag("Provide surprising and lesser-known facts that challenge common assumptions.")
                        Text("Mind-blowing Ideas").tag("Focus on thought-provoking ideas that expand perspective.")
                        Text("Historical Insights").tag("Share fascinating historical insights and connections.")
                        Text("Future Trends").tag("Discuss emerging trends and future possibilities.")
                        Text("Creative Prompts").tag("Offer creative thought experiments and mental frameworks.")
                        Text("Gen Z Style").tag("Express complex ideas using Gen Z slang, internet humor, and abbreviated language patterns.")
                        Text("ELI5").tag("Explain Like I'm 5 - break down complex topics into ultra-simple terms anyone could understand.")
                        Text("Contrarian View").tag("Present a thoughtful counterpoint to the mainstream view on this topic.")
                        Text("Analogies & Metaphors").tag("Explain the topic through creative analogies and metaphors to make it more relatable.")
                        Text("Custom Prompt").tag("custom_prompt")
                    }
                    .pickerStyle(.navigationLink)
                    
                    if preferencesInput == "custom_prompt" {
                        TextEditor(text: $customPrompt)
                            .padding(4)
                            .frame(minHeight: 120)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.top, 4)
                    }
                }
                
                // Let's use a state variable to track if we want to use custom prompt override
                if preferencesInput != "custom_prompt" {
                    Section(header: Text("CUSTOM OVERRIDE")) {
                        Toggle("Use Custom Prompt Instead", isOn: $useCustomPromptOverride)
                            .onChange(of: useCustomPromptOverride) { _, newValue in
                                if !newValue {
                                    customPrompt = ""
                                }
                            }
                        
                        if useCustomPromptOverride {
                            TextEditor(text: $customPrompt)
                                .padding(4)
                                .frame(minHeight: 120)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .padding(.top, 4)
                        }
                    }
                }
                
                Section(footer: Text("This will generate content based on exactly what you've chosen above, without randomization.")) {
                    Button("Generate Content") {
                        if preferencesInput == "custom_prompt" || useCustomPromptOverride {
                            generateWithCustomPrompt()
                        } else {
                            generateWithSelectedSettings()
                        }
                        showCustomPromptSheet = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .buttonStyle(PlainButtonStyle())
                    .disabled((useSelectedTopics && topicInput.isEmpty) && 
                              preferencesInput != "custom_prompt" && 
                              !useCustomPromptOverride)
                }
            }
            .navigationTitle("Content Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomPromptSheet = false
                    }
                }
            }
        }
        .sheet(isPresented: $showTopicInput) {
            topicInputView
        }
    }
    
    // Function to generate content with a custom prompt
    private func generateWithCustomPrompt() {
        guard !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isGenerating else { return }
        guard let modelName = appManager.freeModeModelName ?? appManager.currentModelName,
              appManager.installedModels.contains(modelName) else { return }
        
        isGenerating = true
        
        Task {
            // Use the current topic input based on toggle state
            let topicForGeneration: String
            if useSelectedTopics && !topicInput.isEmpty {
                topicForGeneration = topicInput
            } else {
                topicForGeneration = "custom"
            }
            
            // Content length based on settings
            let contentLengthGuideline: String
            let maxWordCount: Int
            switch appManager.contentLengthMode {
            case "minimalist":
                contentLengthGuideline = "MAXIMUM 50 WORDS."
                maxWordCount = 50
            case "brief":
                contentLengthGuideline = "MAXIMUM 80 WORDS."
                maxWordCount = 80
            case "medium":
                contentLengthGuideline = "MAXIMUM 150 WORDS."
                maxWordCount = 150
            case "detailed":
                contentLengthGuideline = "MAXIMUM 300 WORDS."
                maxWordCount = 300
            default:
                contentLengthGuideline = "MAXIMUM 150 WORDS."
                maxWordCount = 150
            }
            
            // Create system prompt using the custom prompt
            let systemPrompt = """
            You're a smart, engaging content creator crafting bite-sized insights about \(topicForGeneration).
            
            **CUSTOM INSTRUCTION:**
            \(customPrompt)
            
            STRICT WORD COUNT: \(contentLengthGuideline)
            
            START DIRECTLY WITH A TITLE. Do not include any instructions or explanations in your output.
            """
            
            // Create a temporary thread for generation
            let tempThread = Thread()
            let systemMessage = Message(role: .system, content: systemPrompt, thread: tempThread)
            let userMessage = Message(role: .user, content: "Write about \(topicForGeneration) following the custom instruction. Start with a title. Stay under \(maxWordCount) words.", thread: tempThread)
            modelContext.insert(tempThread)
            modelContext.insert(systemMessage)
            modelContext.insert(userMessage)
            
            // Generate the content
            var generatedContent = await llm.generate(
                modelName: modelName,
                thread: tempThread,
                systemPrompt: systemPrompt
            )
            
            // Clean up the generated content using the same patterns
            // (reuse existing content cleanup code)
            let promptPatterns = [
                "You are creating engaging, bite-sized content about .*\\. Share an intriguing,.*",
                "You're a smart, engaging content creator crafting bite-sized insights about .*",
                "RESPONSE FORMAT:.*",
                "CONTENT GUIDELINES:.*",
                "STYLE:.*",
                "Write an insightful piece about.*",
                "Write about .*",
                "Write about .* using the exact style specified in the instructions\\. Start directly with a title\\. Stay under \\d+ words\\.",
                "ite an insightful piece about.*",
                "ite about .* using the exact style specified in the instructions\\. Start directly with a title\\. Stay under \\d+ words\\.",
                "ite>.*",
                "^ite.*",
                "^.?ite.*",
                "You are creating engaging, bite-sized content about .*",
                "Guidelines:.*",
                "- Use accessible.*",
                "- Make it feel like a discovery.*",
                "- Focus on ONE clear.*",
                "- Prioritize concrete.*",
                "- If historical.*",
                "- Don't use generic phrases.*",
                "- The goal is for the user.*",
                "Share a fascinating insight about .*",
                "STRICT WORD COUNT:.*",
                "\\d+$", // Single digit/number at end
                "Note: I('ve|'m|'ll) (followed|using|writing|tried).*", // Explanatory notes
                "As requested, I('ve|'m|'ll).*", // Model explaining what it did
                "I hope this (captures|sounds|matches).*", // Self-reference by model
                "I('ve|'m|'ll) (written|created|drafted) this in.*", // Self-reference by model
                "\\(Note:.*\\)", // Parenthetical notes
                ".*in Gen Z (style|language|slang).*", // References to writing style
                ".*as instructed.*", // References to following instructions
            ]
            
            for pattern in promptPatterns {
                if let range = generatedContent.range(of: pattern, options: .regularExpression) {
                    generatedContent = String(generatedContent[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Also check for explanation notes at the end of content
            let explanationPatterns = [
                "\\n\\s*Note:.*$",
                "\\n\\s*I('ve|'m|'ll) (followed|using|writing|tried).*$",
                "\\n\\s*As requested.*$",
                "\\n\\s*I hope this.*$",
                "Show less.*$",
                ".*using authentic Gen Z language.*$",
                ".*using Gen Z slang.*$",
                ".*as per your request.*$",
                ".*breaking (the |grammar )?rules.*$",
                ".*to keep (the |it |content )?concise.*$",
                ".*under \\d+ words.*$",
                "\\n\\s*\\d+$" // Number at the end on its own line
            ]
            
            for pattern in explanationPatterns {
                if let range = generatedContent.range(of: pattern, options: .regularExpression) {
                    generatedContent = String(generatedContent[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Create and save the content card
            let newCard = ContentCard(
                content: generatedContent,
                topic: topicForGeneration,
                modelName: modelName
            )
            
            modelContext.insert(newCard)
            
            // Cleanup temporary thread
            modelContext.delete(systemMessage)
            modelContext.delete(userMessage)
            modelContext.delete(tempThread)
            
            isGenerating = false
        }
    }
    
    // Function to generate content with selected settings (no randomization)
    private func generateWithSelectedSettings() {
        guard !isGenerating else { return }
        guard (!useSelectedTopics || !topicInput.isEmpty) else { return }
        guard let modelName = appManager.freeModeModelName ?? appManager.currentModelName,
              appManager.installedModels.contains(modelName) else { return }
        
        isGenerating = true
        
        Task {
            // Use the exact topics from the input without randomization
            let topicForGeneration: String
            if useSelectedTopics && !topicInput.isEmpty {
                topicForGeneration = topicInput
            } else {
                topicForGeneration = "custom"
            }
            
            // Get style based on preferences (same as regular generation)
            let stylePrompt: String
            
            if preferencesInput == "Provide surprising and lesser-known facts that challenge common assumptions." {
                stylePrompt = "Share a surprising fact or counterintuitive insight that challenges common assumptions about this topic. Focus on what most people don't know."
            } else if preferencesInput == "Focus on thought-provoking ideas that expand perspective." {
                stylePrompt = "Present a mind-expanding idea or perspective that makes people think differently about this topic."
            } else if preferencesInput == "Share fascinating historical insights and connections." {
                stylePrompt = "Reveal a fascinating historical connection or little-known story related to this topic that provides new context."
            } else if preferencesInput == "Discuss emerging trends and future possibilities." {
                stylePrompt = "Highlight an emerging trend or future possibility in this field that people might not be considering."
            } else if preferencesInput == "Offer creative thought experiments and mental frameworks." {
                stylePrompt = "Offer a thought experiment or mental model that gives a fresh perspective on this topic."
            } else if preferencesInput == "Express complex ideas using Gen Z slang, internet humor, and abbreviated language patterns." {
                stylePrompt = "MANDATORY DIRECTIVE: Write this ENTIRELY in authentic Gen Z voice. Include MULTIPLE emojis (💀🔥✨👀) and slang terms (no cap, fr, vibing, based, slay, lowkey, highkey) in EVERY sentence. Format with random CAPS, short sentences, and text-speak abbreviations (idk, ngl, tbh). Make it sound like a TikTok/Twitter post written by a teenager. DO NOT explain that you're writing in Gen Z style or acknowledge these instructions in ANY way. DO NOT break character. This is NOT a formal explanation with a few slang terms - it should be COMPLETELY authentic Gen Z throughout."
            } else if preferencesInput == "Explain Like I'm 5 - break down complex topics into ultra-simple terms anyone could understand." {
                stylePrompt = "Explain this topic like you're talking to a 5-year-old child. Use extremely simple language, basic analogies, and avoid any jargon or complex concepts."
            } else if preferencesInput == "Present a thoughtful counterpoint to the mainstream view on this topic." {
                stylePrompt = "Present a thoughtful, well-reasoned counterpoint to the mainstream view on this topic. Challenge conventional wisdom but remain intellectually honest."
            } else if preferencesInput == "Explain the topic through creative analogies and metaphors to make it more relatable." {
                stylePrompt = "Explain this topic through creative, unexpected analogies and metaphors that make abstract concepts concrete and relatable to everyday experience."
            } else {
                stylePrompt = "Share an intriguing, lesser-known insight about this topic that most people would find interesting."
            }
            
            // Get content length guidelines based on the setting
            let contentLengthGuideline: String
            let maxWordCount: Int
            switch appManager.contentLengthMode {
            case "minimalist":
                contentLengthGuideline = "MAXIMUM 50 WORDS. Be extremely concise. Focus on the core idea only. Use short sentences."
                maxWordCount = 50
            case "brief":
                contentLengthGuideline = "MAXIMUM 80 WORDS. Be concise and punchy. Keep explanations minimal while maintaining clarity."
                maxWordCount = 80
            case "medium":
                contentLengthGuideline = "MAXIMUM 150 WORDS. Balance brevity with some helpful context and explanation."
                maxWordCount = 150
            case "detailed":
                contentLengthGuideline = "MAXIMUM 300 WORDS. Provide comprehensive insight with relevant context, examples, and nuance."
                maxWordCount = 300
            default:
                contentLengthGuideline = "MAXIMUM 150 WORDS. Balance brevity with some helpful context and explanation."
                maxWordCount = 150
            }
            
            // Create system prompt for content generation
            let systemPrompt = """
            You're a smart, engaging content creator crafting bite-sized insights about \(topicForGeneration).
            
            **MOST IMPORTANT INSTRUCTION - STYLE REQUIREMENT:**
            \(stylePrompt)
            
            STRICT WORD COUNT: \(contentLengthGuideline)
            
            RESPONSE FORMAT:
            Start with a clear, compelling title followed by your insight. DO NOT include any instructions, prompts, or explanatory notes in your output. DO NOT explain or reference how you're writing.
            
            CONTENT GUIDELINES:
            - Use accessible, conversational language
            - Make it feel like a discovery, not an encyclopedic entry
            - Focus on ONE clear, memorable idea rather than multiple points
            - Prioritize concrete, specific details over general statements
            - If historical, include dates/time periods for context
            - Don't use generic phrases like "Did you know?" or "Interesting fact:"
            - Start with a title and jump straight into the content
            """
            
            // Create a temporary thread for generation
            let tempThread = Thread()
            let systemMessage = Message(role: .system, content: systemPrompt, thread: tempThread)
            let userMessage = Message(role: .user, content: "Write about \(topicForGeneration) using the exact style specified in the instructions. Start directly with a title. Stay under \(maxWordCount) words.", thread: tempThread)
            modelContext.insert(tempThread)
            modelContext.insert(systemMessage)
            modelContext.insert(userMessage)
            
            // Generate the content
            var generatedContent = await llm.generate(
                modelName: modelName,
                thread: tempThread,
                systemPrompt: systemPrompt
            )
            
            // Use the same cleanup code as in the regular generate function
            // Clean up the generated content
            let promptPatterns = [
                "You are creating engaging, bite-sized content about .*\\. Share an intriguing,.*",
                "You're a smart, engaging content creator crafting bite-sized insights about .*",
                "RESPONSE FORMAT:.*",
                "CONTENT GUIDELINES:.*",
                "STYLE:.*",
                "Write an insightful piece about.*",
                "Write about .*",
                "Write about .* using the exact style specified in the instructions\\. Start directly with a title\\. Stay under \\d+ words\\.",
                "ite an insightful piece about.*",
                "ite about .* using the exact style specified in the instructions\\. Start directly with a title\\. Stay under \\d+ words\\.",
                "ite>.*",
                "^ite.*",
                "^.?ite.*",
                "You are creating engaging, bite-sized content about .*",
                "Guidelines:.*",
                "- Use accessible.*",
                "- Make it feel like a discovery.*",
                "- Focus on ONE clear.*",
                "- Prioritize concrete.*",
                "- If historical.*",
                "- Don't use generic phrases.*",
                "- The goal is for the user.*",
                "Share a fascinating insight about .*",
                "STRICT WORD COUNT:.*",
                "\\d+$", // Single digit/number at end
                "Note: I('ve|'m|'ll) (followed|using|writing|tried).*", // Explanatory notes
                "As requested, I('ve|'m|'ll).*", // Model explaining what it did
                "I hope this (captures|sounds|matches).*", // Self-reference by model
                "I('ve|'m|'ll) (written|created|drafted) this in.*", // Self-reference by model
                "\\(Note:.*\\)", // Parenthetical notes
                ".*in Gen Z (style|language|slang).*", // References to writing style
                ".*as instructed.*", // References to following instructions
            ]
            
            for pattern in promptPatterns {
                if let range = generatedContent.range(of: pattern, options: .regularExpression) {
                    generatedContent = String(generatedContent[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Also check for explanation notes at the end of content
            let explanationPatterns = [
                "\\n\\s*Note:.*$",
                "\\n\\s*I('ve|'m|'ll) (followed|using|writing|tried).*$",
                "\\n\\s*As requested.*$",
                "\\n\\s*I hope this.*$",
                "Show less.*$",
                ".*using authentic Gen Z language.*$",
                ".*using Gen Z slang.*$",
                ".*as per your request.*$",
                ".*breaking (the |grammar )?rules.*$",
                ".*to keep (the |it |content )?concise.*$",
                ".*under \\d+ words.*$",
                "\\n\\s*\\d+$" // Number at the end on its own line
            ]
            
            for pattern in explanationPatterns {
                if let range = generatedContent.range(of: pattern, options: .regularExpression) {
                    generatedContent = String(generatedContent[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Enforce word count limits by truncating if necessary
            let words = generatedContent.split(separator: " ")
            if words.count > maxWordCount {
                // Attempt to find a sentence end to truncate at
                var truncatedContent = ""
                var wordCount = 0
                let sentences = generatedContent.split(separator: ".")
                
                for (i, sentence) in sentences.enumerated() {
                    let sentenceWords = sentence.split(separator: " ")
                    
                    if wordCount + sentenceWords.count <= maxWordCount || i == 0 {
                        truncatedContent += (i > 0 ? "." : "") + sentence
                        wordCount += sentenceWords.count
                    } else {
                        break
                    }
                }
                
                // Add ending period if needed
                if !truncatedContent.hasSuffix(".") {
                    truncatedContent += "."
                }
                
                generatedContent = truncatedContent
            }
            
            // Create and save the content card
            let newCard = ContentCard(
                content: generatedContent,
                topic: topicForGeneration, // Use the actual topics we used for generation
                modelName: modelName
            )
            
            modelContext.insert(newCard)
            
            // Cleanup temporary thread
            modelContext.delete(systemMessage)
            modelContext.delete(userMessage)
            modelContext.delete(tempThread)
            
            isGenerating = false
        }
    }
    
    // Function to generate content with improved prompt
    private func generateContent() {
        guard !isGenerating else { return }
        guard let modelName = appManager.freeModeModelName ?? appManager.currentModelName,
              appManager.installedModels.contains(modelName) else { return }
        
        isGenerating = true
        
        Task {
            // Parse topics from the comma-separated list
            let topics = topicInput.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // If no topics, use a default one
            let effectiveTopics = topics.isEmpty ? ["custom"] : topics
            
            // Select a topic to focus on for this generation
            // Either select one topic or combine a small number (max 2-3) based on settings
            let topicsCombinationMode = appManager.topicsCombinationMode
            
            var selectedTopics: [String] = []
            
            if topicsCombinationMode == "single" || effectiveTopics.count == 1 {
                // Just pick one topic randomly
                if let topic = effectiveTopics.randomElement() {
                    selectedTopics = [topic]
                }
            } else if topicsCombinationMode == "pair" && effectiveTopics.count > 1 {
                // Pick two random topics if possible
                var shuffledTopics = effectiveTopics.shuffled()
                selectedTopics = Array(shuffledTopics.prefix(2))
            } else if topicsCombinationMode == "triple" && effectiveTopics.count > 2 {
                // Pick three random topics if possible
                var shuffledTopics = effectiveTopics.shuffled()
                selectedTopics = Array(shuffledTopics.prefix(3))
            } else {
                // Default fallback - just pick one topic
                if let topic = effectiveTopics.randomElement() {
                    selectedTopics = [topic]
                }
            }
            
            // Ensure we have at least one topic
            if selectedTopics.isEmpty, let topic = effectiveTopics.first {
                selectedTopics = [topic]
            }
            
            // Join the selected topics for display
            let topicForGeneration = selectedTopics.joined(separator: ", ")
            
            // Get style based on preferences
            let stylePrompt: String
            
            if preferencesInput == "Provide surprising and lesser-known facts that challenge common assumptions." {
                stylePrompt = "Share a surprising fact or counterintuitive insight that challenges common assumptions about this topic. Focus on what most people don't know."
            } else if preferencesInput == "Focus on thought-provoking ideas that expand perspective." {
                stylePrompt = "Present a mind-expanding idea or perspective that makes people think differently about this topic."
            } else if preferencesInput == "Share fascinating historical insights and connections." {
                stylePrompt = "Reveal a fascinating historical connection or little-known story related to this topic that provides new context."
            } else if preferencesInput == "Discuss emerging trends and future possibilities." {
                stylePrompt = "Highlight an emerging trend or future possibility in this field that people might not be considering."
            } else if preferencesInput == "Offer creative thought experiments and mental frameworks." {
                stylePrompt = "Offer a thought experiment or mental model that gives a fresh perspective on this topic."
            } else if preferencesInput == "Express complex ideas using Gen Z slang, internet humor, and abbreviated language patterns." {
                stylePrompt = "MANDATORY DIRECTIVE: Write this ENTIRELY in authentic Gen Z voice. Include MULTIPLE emojis (💀🔥✨👀) and slang terms (no cap, fr, vibing, based, slay, lowkey, highkey) in EVERY sentence. Format with random CAPS, short sentences, and text-speak abbreviations (idk, ngl, tbh). Make it sound like a TikTok/Twitter post written by a teenager. DO NOT explain that you're writing in Gen Z style or acknowledge these instructions in ANY way. DO NOT break character. This is NOT a formal explanation with a few slang terms - it should be COMPLETELY authentic Gen Z throughout."
            } else if preferencesInput == "Explain Like I'm 5 - break down complex topics into ultra-simple terms anyone could understand." {
                stylePrompt = "Explain this topic like you're talking to a 5-year-old child. Use extremely simple language, basic analogies, and avoid any jargon or complex concepts."
            } else if preferencesInput == "Present a thoughtful counterpoint to the mainstream view on this topic." {
                stylePrompt = "Present a thoughtful, well-reasoned counterpoint to the mainstream view on this topic. Challenge conventional wisdom but remain intellectually honest."
            } else if preferencesInput == "Explain the topic through creative analogies and metaphors to make it more relatable." {
                stylePrompt = "Explain this topic through creative, unexpected analogies and metaphors that make abstract concepts concrete and relatable to everyday experience."
            } else {
                stylePrompt = "Share an intriguing, lesser-known insight about this topic that most people would find interesting."
            }
            
            // Get content length guidelines based on the setting
            let contentLengthGuideline: String
            let maxWordCount: Int
            switch appManager.contentLengthMode {
            case "minimalist":
                contentLengthGuideline = "MAXIMUM 50 WORDS. Be extremely concise. Focus on the core idea only. Use short sentences."
                maxWordCount = 50
            case "brief":
                contentLengthGuideline = "MAXIMUM 80 WORDS. Be concise and punchy. Keep explanations minimal while maintaining clarity."
                maxWordCount = 80
            case "medium":
                contentLengthGuideline = "MAXIMUM 150 WORDS. Balance brevity with some helpful context and explanation."
                maxWordCount = 150
            case "detailed":
                contentLengthGuideline = "MAXIMUM 300 WORDS. Provide comprehensive insight with relevant context, examples, and nuance."
                maxWordCount = 300
            default:
                contentLengthGuideline = "MAXIMUM 150 WORDS. Balance brevity with some helpful context and explanation."
                maxWordCount = 150
            }
            
            // Create system prompt for content generation
            let systemPrompt = """
            You're a smart, engaging content creator crafting bite-sized insights about \(topicForGeneration).
            
            **MOST IMPORTANT INSTRUCTION - STYLE REQUIREMENT:**
            \(stylePrompt)
            
            STRICT WORD COUNT: \(contentLengthGuideline)
            
            RESPONSE FORMAT:
            Start with a clear, compelling title followed by your insight. DO NOT include any instructions, prompts, or explanatory notes in your output. DO NOT explain or reference how you're writing.
            
            CONTENT GUIDELINES:
            - Use accessible, conversational language
            - Make it feel like a discovery, not an encyclopedic entry
            - Focus on ONE clear, memorable idea rather than multiple points
            - Prioritize concrete, specific details over general statements
            - If historical, include dates/time periods for context
            - Don't use generic phrases like "Did you know?" or "Interesting fact:"
            - Start with a title and jump straight into the content
            """
            
            // Create a temporary thread for generation
            let tempThread = Thread()
            let systemMessage = Message(role: .system, content: systemPrompt, thread: tempThread)
            let userMessage = Message(role: .user, content: "Write about \(topicForGeneration) using the exact style specified in the instructions. Start directly with a title. Stay under \(maxWordCount) words.", thread: tempThread)
            modelContext.insert(tempThread)
            modelContext.insert(systemMessage)
            modelContext.insert(userMessage)
            
            // Generate the content
            var generatedContent = await llm.generate(
                modelName: modelName,
                thread: tempThread,
                systemPrompt: systemPrompt
            )
            
            // Clean up the generated content
            let promptPatterns = [
                "You are creating engaging, bite-sized content about .*\\. Share an intriguing,.*",
                "You're a smart, engaging content creator crafting bite-sized insights about .*",
                "RESPONSE FORMAT:.*",
                "CONTENT GUIDELINES:.*",
                "STYLE:.*",
                "Write an insightful piece about.*",
                "Write about .*",
                "Write about .* using the exact style specified in the instructions\\. Start directly with a title\\. Stay under \\d+ words\\.",
                "ite an insightful piece about.*",
                "ite about .* using the exact style specified in the instructions\\. Start directly with a title\\. Stay under \\d+ words\\.",
                "ite>.*",
                "^ite.*",
                "^.?ite.*",
                "You are creating engaging, bite-sized content about .*",
                "Guidelines:.*",
                "- Use accessible.*",
                "- Make it feel like a discovery.*",
                "- Focus on ONE clear.*",
                "- Prioritize concrete.*",
                "- If historical.*",
                "- Don't use generic phrases.*",
                "- The goal is for the user.*",
                "Share a fascinating insight about .*",
                "STRICT WORD COUNT:.*",
                "\\d+$", // Single digit/number at end
                "Note: I('ve|'m|'ll) (followed|using|writing|tried).*", // Explanatory notes
                "As requested, I('ve|'m|'ll).*", // Model explaining what it did
                "I hope this (captures|sounds|matches).*", // Self-reference by model
                "I('ve|'m|'ll) (written|created|drafted) this in.*", // Self-reference by model
                "\\(Note:.*\\)", // Parenthetical notes
                ".*in Gen Z (style|language|slang).*", // References to writing style
                ".*as instructed.*", // References to following instructions
            ]
            
            for pattern in promptPatterns {
                if let range = generatedContent.range(of: pattern, options: .regularExpression) {
                    generatedContent = String(generatedContent[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Also check for explanation notes at the end of content
            let explanationPatterns = [
                "\\n\\s*Note:.*$",
                "\\n\\s*I('ve|'m|'ll) (followed|using|writing|tried).*$",
                "\\n\\s*As requested.*$",
                "\\n\\s*I hope this.*$",
                "Show less.*$",
                ".*using authentic Gen Z language.*$",
                ".*using Gen Z slang.*$",
                ".*as per your request.*$",
                ".*breaking (the |grammar )?rules.*$",
                ".*to keep (the |it |content )?concise.*$",
                ".*under \\d+ words.*$",
                "\\n\\s*\\d+$" // Number at the end on its own line
            ]
            
            for pattern in explanationPatterns {
                if let range = generatedContent.range(of: pattern, options: .regularExpression) {
                    generatedContent = String(generatedContent[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Enforce word count limits by truncating if necessary
            let words = generatedContent.split(separator: " ")
            if words.count > maxWordCount {
                // Attempt to find a sentence end to truncate at
                var truncatedContent = ""
                var wordCount = 0
                let sentences = generatedContent.split(separator: ".")
                
                for (i, sentence) in sentences.enumerated() {
                    let sentenceWords = sentence.split(separator: " ")
                    
                    if wordCount + sentenceWords.count <= maxWordCount || i == 0 {
                        truncatedContent += (i > 0 ? "." : "") + sentence
                        wordCount += sentenceWords.count
                    } else {
                        break
                    }
                }
                
                // Add ending period if needed
                if !truncatedContent.hasSuffix(".") {
                    truncatedContent += "."
                }
                
                generatedContent = truncatedContent
            }
            
            // Create and save the content card
            let newCard = ContentCard(
                content: generatedContent,
                topic: topicForGeneration, // Use the actual topics we used for generation
                modelName: modelName
            )
            
            modelContext.insert(newCard)
            
            // Cleanup temporary thread
            modelContext.delete(systemMessage)
            modelContext.delete(userMessage)
            modelContext.delete(tempThread)
            
            isGenerating = false
        }
    }
}

// ContentCardView component to display a single card
struct ContentCardView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var appManager: AppManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(LLMEvaluator.self) var llm
    var contentCard: ContentCard
    @Binding var showChat: Bool
    @Binding var currentThread: Thread?
    
    @State private var showFullContent = false
    @State private var showExportOptions = false
    @State private var selectedBackground: CardBackground = .plain
    @State private var selectedFont: CardFont = .system
    @State private var isCopied = false
    @State private var animationProgress: CGFloat = 0
    
    // Card backgrounds
    enum CardBackground: String, CaseIterable, Identifiable {
        case plain = "Plain"
        case gradient = "Gradient"
        case dark = "Dark"
        case light = "Light"
        case paper = "Paper"
        
        var id: String { self.rawValue }
        
        func color(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .plain:
                return Color(.systemBackground)
            case .gradient:
                return Color.clear // Gradient handled separately
            case .dark:
                return Color.black.opacity(0.9)
            case .light:
                return Color.white
            case .paper:
                return Color(red: 0.98, green: 0.97, blue: 0.94) // Papery color
            }
        }
        
        func textColor(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .dark:
                return .white
            case .plain:
                return colorScheme == .dark ? .white : .black
            default:
                return .black
            }
        }
        
        func backgroundView(for colorScheme: ColorScheme) -> some View {
            Group {
                if self == .gradient {
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else if self == .paper {
                    self.color(for: colorScheme)
                        .overlay(
                            Image(systemName: "square.text.square")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .opacity(0.05)
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(15))
                        )
                } else {
                    self.color(for: colorScheme)
                }
            }
        }
    }
    
    // Card fonts - updating to match app settings
    enum CardFont: String, CaseIterable, Identifiable {
        case system = "System"
        case serif = "Serif"
        case rounded = "Rounded"
        case mono = "Monospaced"
        case compressed = "Compressed"
        case condensed = "Condensed"
        case expanded = "Expanded"
        
        var id: String { self.rawValue }
        
        func font(size: CGFloat) -> Font {
            switch self {
            case .system:
                return .system(size: size)
            case .serif:
                return .system(size: size, design: .serif)
            case .rounded:
                return .system(size: size, design: .rounded)
            case .mono:
                return .system(size: size, design: .monospaced)
            case .compressed:
                #if os(iOS) || os(macOS)
                return .system(size: size, weight: .light)
                #else
                return .system(size: size)
                #endif
            case .condensed:
                #if os(iOS) || os(macOS)
                return .system(size: size, weight: .ultraLight)
                #else
                return .system(size: size)
                #endif
            case .expanded:
                #if os(iOS) || os(macOS)
                return .system(size: size, weight: .heavy)
                #else
                return .system(size: size)
                #endif
            }
        }
    }
    
    // Limit preview text to first 150 characters
    var previewContent: String {
        let content = contentCard.content
        if content.count <= 150 || showFullContent {
            return content
        } else {
            return String(content.prefix(150)) + "..."
        }
    }
    
    // Get displayed content based on animation style
    var displayedContent: String {
        let content = showFullContent ? contentCard.content : previewContent
        
        // Only apply typewriter if it's explicitly selected in chat interface
        if appManager.freestyleCardStyle == "typewriter" && animationProgress < 1 {
            let length = Int(Double(content.count) * animationProgress)
            return String(content.prefix(length))
        }
        
        return content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card header
            HStack(alignment: .center) {
                // Topic pill
                Text(contentCard.topic)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(appManager.freestyleCardStyle == "terminal" ? .green : .blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(appManager.freestyleCardStyle == "terminal" ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
                    )
                
                Spacer()
                
                // Time ago
                Text(timeAgo(from: contentCard.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Content with style-specific modifications
            Group {
                if appManager.freestyleCardStyle == "terminal" {
                    Text(displayedContent)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                } else if appManager.freestyleCardStyle == "retro" {
                    Text(displayedContent)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                } else if appManager.freestyleCardStyle == "handwritten" {
                    Text(displayedContent)
                        .font(.system(.body, design: .serif))
                        .italic()
                        .foregroundColor(.primary)
                } else if appManager.freestyleCardStyle == "comic" {
                    Text(displayedContent)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(4)
                } else if appManager.freestyleCardStyle == "futuristic" {
                    VStack {
                        Text(displayedContent)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                ZStack {
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)],
                                        startPoint: .topLeading, 
                                        endPoint: .bottomTrailing
                                    )
                                    
                                    // Futuristic grid lines
                                    GeometryReader { geometry in
                                        Path { path in
                                            // Horizontal lines
                                            for i in 0...10 {
                                                let y = CGFloat(i) * geometry.size.height / 10
                                                path.move(to: CGPoint(x: 0, y: y))
                                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                                            }
                                            
                                            // Vertical lines
                                            for i in 0...10 {
                                                let x = CGFloat(i) * geometry.size.width / 10
                                                path.move(to: CGPoint(x: x, y: 0))
                                                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                                            }
                                        }
                                        .stroke(Color.cyan.opacity(0.2), lineWidth: 0.5)
                                    }
                                }
                            )
                            .cornerRadius(8)
                    }
                } else {
                    Markdown(displayedContent)
                        .markdownTheme(.gitHub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Apply animations only if they're supported (handle legacy settings)
            .opacity(appManager.freestyleCardStyle == "fade" ? animationProgress : 1)
            .offset(y: appManager.freestyleCardStyle == "bounce" ? (1 - animationProgress) * 20 : 0)
            
            // Bottom row with read more and actions
            HStack {
                // Read more button
                if contentCard.content.count > 150 {
                    Button {
                        showFullContent.toggle()
                        if showFullContent && (appManager.freestyleCardStyle != "none") {
                            // Reset and restart animation when showing full content
                            animationProgress = 0
                            withAnimation(.easeOut(duration: 1.0)) {
                                animationProgress = 1.0
                            }
                        }
                    } label: {
                        Text(showFullContent ? "Show less" : "Read more")
                            .font(.footnote)
                            .foregroundColor(appManager.freestyleCardStyle == "terminal" ? .green : .blue)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    // Continue in chat button
                    Button {
                        continueInChat()
                    } label: {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .foregroundColor(.gray)
                    }
                    
                    // Copy to clipboard button
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = contentCard.content
                        withAnimation {
                            isCopied = true
                        }
                        // Reset the copied state after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isCopied = false
                            }
                        }
                        #endif
                    } label: {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(isCopied ? .green : .gray)
                    }
                    
                    // Save/unsave button
                    Button {
                        contentCard.isSaved.toggle()
                    } label: {
                        Image(systemName: contentCard.isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(contentCard.isSaved ? .blue : .gray)
                    }
                    
                    // Delete button
                    Button {
                        deleteCard()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Model attribution
            if let modelName = contentCard.modelName {
                HStack {
                    Spacer()
                    Text(appManager.modelDisplayName(modelName))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if contentCard.content.count > 150 {
                showFullContent.toggle()
                if showFullContent && (appManager.freestyleCardStyle != "none") {
                    // Reset and restart animation when showing full content
                    animationProgress = 0
                    withAnimation(.easeOut(duration: 1.0)) {
                        animationProgress = 1.0
                    }
                }
            }
        }
        .sheet(isPresented: $showExportOptions) {
            exportOptionsView
        }
        .onAppear {
            if appManager.freestyleCardStyle != "none" {
                // Start animation when view appears
                animationProgress = 0
                withAnimation(.easeOut(duration: 1.0)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }
    
    // Background color based on style
    var cardBackgroundColor: Color {
        switch appManager.freestyleCardStyle {
        case "minimalist":
            return Color(.systemBackground).opacity(0.8)
        case "terminal":
            return Color.black
        case "retro":
            return Color(.systemBackground)
        case "futuristic":
            return Color.blue.opacity(0.1)
        default:
            return Color(.systemBackground)
        }
    }
    
    // Function to delete the card
    private func deleteCard() {
            modelContext.delete(contentCard)
    }
    
    // Improved chat continuation that properly handles the conversation context
    private func continueInChat() {
        // Create a new thread
        let newThread = Thread()
        
        // Add content as user message to establish the context for conversation
        let systemMessage = Message(
            role: .system, 
            content: "You are a helpful assistant engaging in a conversation about the topic: \(contentCard.topic). Respond to the user's questions and comments conversationally. Do not generate story-like content unless specifically requested.", 
            thread: newThread
        )
        
        // Initial user message referencing the content
        let userMessage = Message(
            role: .user, 
            content: "I found this interesting: \"\(contentCard.content)\"\n\nLet's talk about this topic.", 
            thread: newThread
        )
        
        // Initial AI response to establish conversation
        let aiMessage = Message(
            role: .assistant, 
            content: "That's an interesting topic! What aspects of it would you like to discuss or explore further?", 
            thread: newThread
        )
        
        // Save messages to thread
        modelContext.insert(newThread)
        modelContext.insert(systemMessage)
        modelContext.insert(userMessage)
        modelContext.insert(aiMessage)
        
        // Set as current thread and navigate to chat
        currentThread = newThread
        showChat = false
    }
    
    // Export options view
    private var exportOptionsView: some View {
        NavigationView {
            Form {
                Section(header: Text("BACKGROUND")) {
                    Picker("Style", selection: $selectedBackground) {
                        ForEach(CardBackground.allCases) { background in
                            Text(background.rawValue).tag(background)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("TYPOGRAPHY")) {
                    Picker("Font", selection: $selectedFont) {
                        ForEach(CardFont.allCases) { font in
                            Text(font.rawValue).tag(font)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section {
                    Button {
                        // Copy card content to clipboard
                        #if os(iOS)
                        let contentToCopy = contentCard.content
                        UIPasteboard.general.string = contentToCopy
                        withAnimation {
                            isCopied = true
                        }
                        // Reset the copied state after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isCopied = false
                            }
                        }
                        #endif
                    } label: {
                        Text(isCopied ? "Copied to Clipboard!" : "Copy to Clipboard")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                            .padding()
                            .background(isCopied ? Color.green : Color.blue)
                            .cornerRadius(10)
                    }
                }
                
                Section(header: Text("PREVIEW")) {
                    cardForExport
                        .frame(minHeight: 450)
                }
            }
            .navigationTitle("Export Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showExportOptions = false
                    }
                }
            }
        }
    }
    
    // Improved card view for export - more minimalist with better text handling
    private var cardForExport: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Topic
            Text(contentCard.topic)
                .font(selectedFont.font(size: 14))
                .fontWeight(.medium)
                .foregroundColor(selectedBackground == .gradient ? .white : .blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(selectedBackground == .gradient ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                )
            
            // Content - using ScrollView to handle overflow
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Extract title and body if possible
                    let components = contentCard.content.split(separator: "\n", maxSplits: 1)
                    if components.count > 1 {
                        Text(String(components[0]))
                            .font(selectedFont.font(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(selectedBackground.textColor(for: colorScheme))
                            .padding(.bottom, 4)
                        
                        Text(String(components[1]))
                            .font(selectedFont.font(size: 16))
                            .foregroundColor(selectedBackground.textColor(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(contentCard.content)
                            .font(selectedFont.font(size: 16))
                            .foregroundColor(selectedBackground.textColor(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            
            Spacer()
            
            // App attribution - more subtle
            HStack {
                Spacer()
                Text("free.ai")
                    .font(selectedFont.font(size: 11))
                    .foregroundColor(selectedBackground.textColor(for: colorScheme).opacity(0.5))
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                selectedBackground.backgroundView(for: colorScheme)
            }
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(10)
    }
    
    // Helper function to format time
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#if os(iOS)
// Helper view to simplify the model picker row
struct ModelPickerRow: View {
    @EnvironmentObject var appManager: AppManager
    let modelName: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Text(String(appManager.modelDisplayName(modelName).prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading) {
                    Text(appManager.modelDisplayName(modelName))
                        .font(.headline)
                    
                    if let model = ModelConfiguration.availableModels.first(where: { $0.name == modelName }),
                       let size = model.modelSize {
                        Text("\(NSDecimalNumber(decimal: size).doubleValue, specifier: "%.1f") GB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
#endif

#Preview {
    FreeModeView(showChat: .constant(false), currentThread: .constant(nil))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}

// Topic button for quick selection
// This is now imported from FreeModeSettingsView so no need to redeclare it
// struct TopicButton: View { ... } 