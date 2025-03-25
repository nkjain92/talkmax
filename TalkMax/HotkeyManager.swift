import Foundation
import KeyboardShortcuts
import Carbon
import AppKit

extension KeyboardShortcuts.Name {
    static let toggleMiniRecorder = Self("toggleMiniRecorder")
    static let escapeRecorder = Self("escapeRecorder")
    static let toggleEnhancement = Self("toggleEnhancement")
    // Prompt selection shortcuts
    static let selectPrompt1 = Self("selectPrompt1")
    static let selectPrompt2 = Self("selectPrompt2")
    static let selectPrompt3 = Self("selectPrompt3")
    static let selectPrompt4 = Self("selectPrompt4")
    static let selectPrompt5 = Self("selectPrompt5")
    static let selectPrompt6 = Self("selectPrompt6")
    static let selectPrompt7 = Self("selectPrompt7")
    static let selectPrompt8 = Self("selectPrompt8")
    static let selectPrompt9 = Self("selectPrompt9")
}

@MainActor
class HotkeyManager: ObservableObject {
    @Published var isListening = false
    @Published var isShortcutConfigured = false
    @Published var isPushToTalkEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPushToTalkEnabled, forKey: "isPushToTalkEnabled")
            resetKeyStates()
            setupKeyMonitor()
        }
    }
    @Published var pushToTalkKey: PushToTalkKey {
        didSet {
            UserDefaults.standard.set(pushToTalkKey.rawValue, forKey: "pushToTalkKey")
            resetKeyStates()
        }
    }
    
    private var whisperState: WhisperState
    private var currentKeyState = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var visibilityTask: Task<Void, Never>?
    
    // New properties for advanced key handling
    private var keyPressStartTime: Date?
    private var lastKeyPressEndTime: Date?
    private var isLockedRecording = false  // For toggle mode after double-press
    private let doublePressThreshold = 0.5  // 500ms for double-press detection
    private let briefPressThreshold = 1.0 // 1000ms threshold for brief press
    
    enum PushToTalkKey: String, CaseIterable {
        case rightOption = "rightOption"
        case fn = "fn"
        case rightCommand = "rightCommand"
        case rightShift = "rightShift"
        
        var displayName: String {
            switch self {
            case .rightOption: return "Right Option (⌥)"
            case .fn: return "Fn"
            case .rightCommand: return "Right Command (⌘)"
            case .rightShift: return "Right Shift (⇧)"
            }
        }
        
        var keyCode: CGKeyCode {
            switch self {
            case .rightOption: return 0x3D
            case .fn: return 0x3F
            case .rightCommand: return 0x36
            case .rightShift: return 0x3C
            }
        }
        
        var flags: CGEventFlags {
            switch self {
            case .rightOption: return .maskAlternate
            case .fn: return .maskSecondaryFn
            case .rightCommand: return .maskCommand
            case .rightShift: return .maskShift
            }
        }
    }
    
    init(whisperState: WhisperState) {
        self.isPushToTalkEnabled = UserDefaults.standard.bool(forKey: "isPushToTalkEnabled")
        self.pushToTalkKey = PushToTalkKey(rawValue: UserDefaults.standard.string(forKey: "pushToTalkKey") ?? "") ?? .rightCommand
        self.whisperState = whisperState
        
        updateShortcutStatus()
        setupEnhancementShortcut()
        setupVisibilityObserver()
    }
    
    private func resetKeyStates() {
        currentKeyState = false
        keyPressStartTime = nil
        lastKeyPressEndTime = nil
        isLockedRecording = false
    }
    
    private func setupVisibilityObserver() {
        visibilityTask = Task { @MainActor in
            for await isVisible in whisperState.$isMiniRecorderVisible.values {
                if isVisible {
                    setupEscapeShortcut()
                    KeyboardShortcuts.setShortcut(.init(.e, modifiers: .command), for: .toggleEnhancement)
                    setupPromptShortcuts()
                } else {
                    removeEscapeShortcut()
                    removeEnhancementShortcut()
                    removePromptShortcuts()
                }
            }
        }
    }
    
    private func setupKeyMonitor() {
        removeKeyMonitor()
        
        guard isPushToTalkEnabled else { return }
        guard AXIsProcessTrusted() else { return }
        
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                
                if type == .flagsChanged {
                    Task { @MainActor in
                        await manager.handleKeyEvent(event)
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let runLoopSource = self.runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func removeKeyMonitor() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource = self.runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }
    
    private func handleKeyEvent(_ event: CGEvent) async {
        let flags = event.flags
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        
        let isKeyPressed = flags.contains(pushToTalkKey.flags)
        let isTargetKey = pushToTalkKey == .fn ? true : keycode == pushToTalkKey.keyCode
        
        guard isTargetKey else { return }
        guard isKeyPressed != currentKeyState else { return }
        
        currentKeyState = isKeyPressed
        
        // Key is pressed down
        if isKeyPressed {
            // If we're in locked recording mode, key press should stop recording
            if isLockedRecording && whisperState.isMiniRecorderVisible {
                isLockedRecording = false
                await whisperState.handleToggleMiniRecorder()
                return
            }
            
            // Start timing the key press
            keyPressStartTime = Date()
            
            // Check for double press
            if let lastEndTime = lastKeyPressEndTime,
               Date().timeIntervalSince(lastEndTime) < doublePressThreshold {
                // Double press detected - set locked recording mode
                isLockedRecording = true
            }
            
            // Show recorder if not already visible
            if !whisperState.isMiniRecorderVisible {
                await whisperState.handleToggleMiniRecorder()
            }
        } 
        // Key is released
        else {
            let now = Date()
            lastKeyPressEndTime = now
            
            // Calculate press duration
            if let startTime = keyPressStartTime {
                let pressDuration = now.timeIntervalSince(startTime)
                
                // 1. Brief press (< 500ms): Immediately dismiss recorder without transcribing
                if pressDuration < briefPressThreshold && !isLockedRecording {
                    await whisperState.dismissMiniRecorder()
                } 
                // 2. Normal press in non-locked mode: Use handleToggleMiniRecorder to stop and transcribe
                else if !isLockedRecording && whisperState.isMiniRecorderVisible {
                    await whisperState.handleToggleMiniRecorder()
                }
                // 3. If in locked mode, we don't do anything on release
            }
            
            keyPressStartTime = nil
        }
    }
    
    private func setupEscapeShortcut() {
        KeyboardShortcuts.setShortcut(.init(.escape), for: .escapeRecorder)
        KeyboardShortcuts.onKeyDown(for: .escapeRecorder) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible else { return }
                
                // Reset locked recording state when using Escape key
                self.isLockedRecording = false
                
                SoundManager.shared.playEscSound()
                await self.whisperState.dismissMiniRecorder()
            }
        }
    }
    
    private func removeEscapeShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: .escapeRecorder)
    }
    
    private func setupEnhancementShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleEnhancement) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible,
                      let enhancementService = await self.whisperState.getEnhancementService() else { return }
                enhancementService.isEnhancementEnabled.toggle()
            }
        }
    }
    
    private func setupPromptShortcuts() {
        // Set up Command+1 through Command+9 shortcuts with proper key definitions
        KeyboardShortcuts.setShortcut(.init(.one, modifiers: .command), for: .selectPrompt1)
        KeyboardShortcuts.setShortcut(.init(.two, modifiers: .command), for: .selectPrompt2)
        KeyboardShortcuts.setShortcut(.init(.three, modifiers: .command), for: .selectPrompt3)
        KeyboardShortcuts.setShortcut(.init(.four, modifiers: .command), for: .selectPrompt4)
        KeyboardShortcuts.setShortcut(.init(.five, modifiers: .command), for: .selectPrompt5)
        KeyboardShortcuts.setShortcut(.init(.six, modifiers: .command), for: .selectPrompt6)
        KeyboardShortcuts.setShortcut(.init(.seven, modifiers: .command), for: .selectPrompt7)
        KeyboardShortcuts.setShortcut(.init(.eight, modifiers: .command), for: .selectPrompt8)
        KeyboardShortcuts.setShortcut(.init(.nine, modifiers: .command), for: .selectPrompt9)
        
        // Setup handlers for each shortcut
        setupPromptHandler(for: .selectPrompt1, index: 0)
        setupPromptHandler(for: .selectPrompt2, index: 1)
        setupPromptHandler(for: .selectPrompt3, index: 2)
        setupPromptHandler(for: .selectPrompt4, index: 3)
        setupPromptHandler(for: .selectPrompt5, index: 4)
        setupPromptHandler(for: .selectPrompt6, index: 5)
        setupPromptHandler(for: .selectPrompt7, index: 6)
        setupPromptHandler(for: .selectPrompt8, index: 7)
        setupPromptHandler(for: .selectPrompt9, index: 8)
    }
    
    private func setupPromptHandler(for shortcutName: KeyboardShortcuts.Name, index: Int) {
        KeyboardShortcuts.onKeyDown(for: shortcutName) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible,
                      let enhancementService = await self.whisperState.getEnhancementService() else { return }
                
                let prompts = enhancementService.allPrompts
                if index < prompts.count {
                    // Enable AI enhancement if it's not already enabled
                    if !enhancementService.isEnhancementEnabled {
                        enhancementService.isEnhancementEnabled = true
                    }
                    // Switch to the selected prompt
                    enhancementService.setActivePrompt(prompts[index])
                }
            }
        }
    }
    
    private func removePromptShortcuts() {
        // Remove Command+1 through Command+9 shortcuts
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt1)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt2)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt3)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt4)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt5)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt6)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt7)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt8)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt9)
    }
    
    private func removeEnhancementShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: .toggleEnhancement)
    }
    
    func updateShortcutStatus() {
        isShortcutConfigured = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil
        if isShortcutConfigured {
            setupShortcutHandler()
            setupKeyMonitor()
        } else {
            removeKeyMonitor()
        }
    }
    
    private func setupShortcutHandler() {
        KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorder) { [weak self] in
            Task { @MainActor in
                await self?.whisperState.handleToggleMiniRecorder()
            }
        }
    }
    
    deinit {
        visibilityTask?.cancel()
        Task { @MainActor in
            removeKeyMonitor()
            removeEscapeShortcut()
            removeEnhancementShortcut()
        }
    }
}
