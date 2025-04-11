//
//  freeaiApp.swift

//
//

import SwiftUI
import SwiftData
import MLXLLM
import MLXLMCommon

@main
struct freeaiApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @State private var evaluator = LLMEvaluator()
    @StateObject private var appManager = AppManager()
    @State private var launchMessage: String = ""
    
    let launchMessages = [
        "completely free forever",
        "freestyle ai",
        "super free",
        "no internet, no problems",
        "if ai will take over, might as well be free",
        "free as in freedom",
        "private by design",
        "yours to own"
    ]
    
    var sharedModelContainer: SwiftData.ModelContainer = {
        let schema = Schema([
            Thread.self,
            Message.self,
            UserProfile.self,
            ContentCard.self,
            DumpNote.self,
            Reminder.self
        ])
        
        // Add this to forcibly reset the database if needed
        let url = URL.applicationSupportDirectory.appending(path: "default.store")
        
        // Create configuration with correct parameters
        let modelConfiguration = ModelConfiguration(schema: schema, 
                                               isStoredInMemoryOnly: false,
                                               allowsSave: true)
        
        // For debugging purposes
        print("📱 App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
        print("📁 Database path: \(url.path)")

        do {
            // Try to create the model container
            let container = try SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ Successfully created model container")
            return container
        } catch {
            // Print detailed error information
            print("❌ Error creating model container: \(error)")
            print("🔍 Error details: \(String(describing: error))")
            
            // Attempt to delete the database and retry
            print("🗑️ Attempting to delete and recreate database...")
            try? FileManager.default.removeItem(at: url)
            
            do {
                // Try again with a fresh database
                return try SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                print("❌❌ Critical error after database reset: \(error)")
                
                // Last resort: in-memory only database
                print("⚠️ Falling back to in-memory database")
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                
                do {
                    return try SwiftData.ModelContainer(for: schema, configurations: [fallbackConfig])
                } catch {
                    print("💥 Fatal error: Could not create any model container")
                    fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environment(evaluator)
                .environmentObject(appManager)
                .environment(DeviceStat())
                .onAppear {
                    launchMessage = launchMessages.randomElement() ?? launchMessages[0]
                    // Make launchMessage available to LaunchView or other views that need it
                    UserDefaults.standard.set(launchMessage, forKey: "currentLaunchMessage")
                }
                #if os(macOS) || os(visionOS)
                .frame(minWidth: 640, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
                #if os(macOS)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
                #endif
                #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(visionOS)
        .windowResizability(.contentSize)
        #endif
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Show Main Window") {
                    if let mainWindow = NSApp.windows.first {
                        mainWindow.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
        #endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var closedWindowsStack = [NSWindow]()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainWindow = NSApp.windows.first
        mainWindow?.delegate = self
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // if there's a recently closed window, bring that back
        if let lastClosed = closedWindowsStack.popLast() {
            lastClosed.makeKeyAndOrderFront(self)
        } else {
            // otherwise, un-minimize any minimized windows
            for window in sender.windows where window.isMiniaturized {
                window.deminiaturize(nil)
            }
        }
        return false
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            closedWindowsStack.append(window)
        }
    }
}
#endif
