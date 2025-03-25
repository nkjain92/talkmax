import SwiftUI
import SwiftData
import AppKit
import OSLog

@main
struct TalkMaxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer
    
    @StateObject private var whisperState: WhisperState
    @StateObject private var hotkeyManager: HotkeyManager
    @StateObject private var menuBarManager: MenuBarManager
    @StateObject private var aiService = AIService()
    @StateObject private var enhancementService: AIEnhancementService
    @StateObject private var activeWindowService = ActiveWindowService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Audio cleanup manager for automatic deletion of old audio files
    private let audioCleanupManager = AudioCleanupManager.shared
    
    init() {
        do {
            let schema = Schema([
                Transcription.self
            ])
            
            // Create app-specific Application Support directory URL
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("com.nishank.TalkMax", isDirectory: true)
            
            // Create the directory if it doesn't exist
            try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            
            // Configure SwiftData to use the conventional location
            let storeURL = appSupportURL.appendingPathComponent("default.store")
            let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Print SwiftData storage location
            if let url = container.mainContext.container.configurations.first?.url {
                print("💾 SwiftData storage location: \(url.path)")
            }
            
        } catch {
            fatalError("Failed to create ModelContainer for Transcription: \(error.localizedDescription)")
        }
        
        // Initialize services with proper sharing of instances
        let aiService = AIService()
        _aiService = StateObject(wrappedValue: aiService)
        
        let enhancementService = AIEnhancementService(aiService: aiService, modelContext: container.mainContext)
        _enhancementService = StateObject(wrappedValue: enhancementService)
        
        let whisperState = WhisperState(modelContext: container.mainContext, enhancementService: enhancementService)
        _whisperState = StateObject(wrappedValue: whisperState)
        
        let hotkeyManager = HotkeyManager(whisperState: whisperState)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)
        
        let menuBarManager = MenuBarManager(
            whisperState: whisperState,
            container: container,
            enhancementService: enhancementService,
            aiService: aiService,
            hotkeyManager: hotkeyManager
        )
        _menuBarManager = StateObject(wrappedValue: menuBarManager)
        
        // Configure ActiveWindowService with enhancementService
        let activeWindowService = ActiveWindowService.shared
        activeWindowService.configure(with: enhancementService)
        _activeWindowService = StateObject(wrappedValue: activeWindowService)
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(whisperState)
                    .environmentObject(hotkeyManager)
                    .environmentObject(menuBarManager)
                    .environmentObject(aiService)
                    .environmentObject(enhancementService)
                    .modelContainer(container)
                    .onAppear {
                        audioCleanupManager.startAutomaticCleanup(modelContext: container.mainContext)
                    }
                    .background(WindowAccessor { window in
                        WindowManager.shared.configureWindow(window)
                    })
                    .onDisappear {
                        whisperState.unloadModel()
                        audioCleanupManager.stopAutomaticCleanup()
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(hotkeyManager)
                    .environmentObject(whisperState)
                    .environmentObject(aiService)
                    .environmentObject(enhancementService)
                    .frame(minWidth: 1200, minHeight: 800)
            }
        }
        
        MenuBarExtra {
            MenuBarView()
                .environmentObject(whisperState)
                .environmentObject(hotkeyManager)
                .environmentObject(menuBarManager)
                .environmentObject(aiService)
                .environmentObject(enhancementService)
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 22
                $0.size.width = 22 / ratio
                return $0
            }(NSImage(named: "menuBarIcon")!)

            Image(nsImage: image)
        }
        .menuBarExtraStyle(.menu)
        
        #if DEBUG
        WindowGroup("Debug") {
            Button("Toggle Menu Bar Only") {
                menuBarManager.isMenuBarOnly.toggle()
            }
        }
        #endif
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
