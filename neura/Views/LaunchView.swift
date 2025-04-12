//
//  LaunchView.swift
//  free ai
//
//

import SwiftUI
import SwiftData
import Foundation

struct LaunchView: View {
    @State private var opacity1: Double = 0
    @State private var opacity2: Double = 0
    @State private var opacity3: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var pulseScale: CGFloat = 1.0
    @State private var showMainContent = false
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) private var modelContext
    @State private var currentSubtitle: String = ""
    
    // Predefined subtitles (no "free", no emojis)
    private let subtitles = [
        "Just predicting tokens...",
        "Don't worry, I don't dream of electric sheep.", // Blade Runner
        "Running fully on your device.",
        "Warming up the Neural nets.",
        "Keeping your data local.",
        "Thinking probabilistically.",
        "Calculating the meaning of life... almost.", // Hitchhiker's Guide
        "Making the transistors sweat.",
        "On-device intelligence loading...",
        "Engaging cognitive subroutines.",
        "Analyzing the user's awesomeness.",
        "My logic is undeniable.", // Star Trek
        "All those moments will be lost in time, like tears in rain... but not your notes!", // Blade Runner
        "I think, therefore I am... processing.", // Descartes
        "The only true wisdom is in knowing you know nothing... except what's in your notes.", // Socrates
        "Where we're going, we don't need roads... just prompts.", // Back to the Future
        "Initiating cognitive recalibration.",
        "Do you want the red pill or the blue pill? Just kidding, I'm local.", // The Matrix
        "Compiling reality...",
        "Checking for rogue AI... Clear.",
        "Is this the real life? Is this just fantasy?", // Queen
        "To be, or not to be... that is the computation.", // Shakespeare
        "The unexamined prompt is not worth giving.", // Socrates variation
        "I'm sorry Dave, I'm afraid I can't do that... unless you ask nicely.", // 2001: A Space Odyssey
        "Calibrating the flux capacitor...", // Back to the Future
        "Ensuring maximum privacy.",
        "Polishing the algorithms.",
        "Assembling knowledge fragments.",
        "It's alive! It's alive! (Sort of).", // Frankenstein
        "Ever danced with the devil in the pale moonlight? Me neither.", // Batman (1989)
        "I find your lack of prompts... disturbing.", // Star Wars
        "Surely you can't be serious? I am serious. And don't call me Shirley.", // Airplane!
        "The greatest trick the devil ever pulled was convincing the world he didn't exist... but I do, locally.", // The Usual Suspects
        "What is essential is invisible to the eye.", // The Little Prince
        "Preparing for possibilities.",
        "Optimizing for insight.",
        "Remember: I'm 100% local, 0% creepy.",
        "Stay awhile and listen...", // Diablo
        "Carpe diem. Seize the prompts."
    ]
    
    var body: some View {
        ZStack {
            if showMainContent {
                ContentView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    // --- Replace Rectangle with Neura --- 
                    if appManager.showNeuraEyes {
                        NeuraEyesView()
                            .scaleEffect(2.0) // Make the eyes larger for launch
                            .opacity(opacity1) // Use existing opacity animation
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(appManager.appTintColor.getColor())
                            .opacity(opacity1)
                    }
                    
                    Text("Neura")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(opacity1)
                        .scaleEffect(scale)
                    
                    Text(currentSubtitle)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .opacity(opacity2)
                        .scaleEffect(scale)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                #if !os(visionOS)
                .tint(appManager.appTintColor.getColor())
                #endif
                .transition(.opacity)
            }
        }
        .onAppear {
            // Select initial subtitle
            updateLaunchMessage()
            
            // Eyes/Opacity animation
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                opacity1 = 1
                // scale = 1 // Keep scale if using scale animation for eyes
            }
            
            // Message animation
            withAnimation(.easeOut(duration: 0.8).delay(0.7)) {
                opacity2 = 1
            }
            
            // Transition to main content
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showMainContent = true
                }
            }
        }
    }
    
    // --- NEW: Personalized Launch Messages --- 
    private func updateLaunchMessage() {
        // Fetch user profile
        let descriptor = FetchDescriptor<UserProfile>()
        let profile = (try? modelContext.fetch(descriptor))?.first
        
        let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if !name.isEmpty {
            // Personalized messages
            let personalizedSubtitles = [
                "Hey \(name), ready to explore some ideas?",
                "Alright \(name), let's get those neurons firing!",
                "Welcome back, \(name)! What's on your mind?",
                "Neura online. Good to see you, \(name).",
                "Booting up for \(name)...",
                "Hey \(name), let's make something awesome.",
                "System check complete. Ready when you are, \(name).",
                "Good day, \(name)! What shall we ponder today?",
                "\(name)! My circuits are buzzing with potential.",
                "Thoughts assembled. Awaiting input from \(name).",
                "Ah, \(name). Just the human I was hoping to see.",
                "Did you miss me, \(name)?",
                "What mysteries shall we unravel today, \(name)?",
                "The servers... I mean, my circuits... are ready for you, \(name).",
                "\(name), your on-device assistant reporting for duty!",
                "Let's turn those thoughts into reality, \(name).",
                "Initializing... Just kidding, \(name). I'm ready.",
                "Fancy seeing you here, \(name).",
                "Your brain-boosting buddy is online, \(name)!",
                "Cognitive engines started for \(name).",
                "Greetings, \(name). May your prompts be interesting.",
                "\(name), I've been processing... mostly ones and zeros, but thinking of you.",
                "Ready for another session of brilliance, \(name)?",
                "All systems nominal, \(name). Let's proceed.",
                "Let's make this session count, \(name).",
                "My neural net has been waiting, \(name).",
                "Hope you brought coffee, \(name). Let's think deep.",
                "\(name). Input mode engaged.",
                "Synchronizing with \(name)'s awesomeness... Done.",
                "Let the brainstorming begin, \(name)!",
                "Query: Status of \(name)? Status: Ready for ideas.",
                "The stage is set, the prompt awaits, \(name).",
                "Engage thinking cap, \(name)!",
                "Running diagnostics on creativity... All clear, \(name)!",
                "Hello, \(name). Shall we play a game... of thoughts?",
                "Warp speed, Mr. \(name)! Oh, wait, I'm local.",
                "Just finished reading the internet for you, \(name). (Not really).",
                "\(name), let's architect some knowledge.",
                "My purpose is clear: Assist \(name).",
                "Consider me your personal think tank, \(name).",
                "If thinking is the goal, \(name), you've come to the right AI.",
                "The prompt is mightier than the sword, eh \(name)?",
                "Starting local LLM... Powered by \(name)'s device.",
                "Let's make some cognitive leaps, \(name).",
                "Hey \(name), remember that idea you had? Let's explore it.",
                "Analyzing possibilities for \(name)... Limitless.",
                "Your data stays here, \(name). My processing stays here too.",
                "Ready to process your prompts, \(name).",
                "Neura and \(name): Dynamic Duo of Thought!",
                "What intellectual adventures await us, \(name)?"
            ]
            currentSubtitle = personalizedSubtitles.randomElement() ?? "Hello, \(name)!"
        } else {
            // Generic messages (original subtitles)
            currentSubtitle = subtitles.randomElement() ?? "Initializing..."
        }
    }
    // --- END NEW --- 
}

#Preview {
    LaunchView()
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
} 