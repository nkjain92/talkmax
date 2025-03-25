import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var whisperState: WhisperState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var updaterViewModel: UpdaterViewModel
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var aiService: AIService
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var menuRefreshTrigger = false  // Added to force menu updates
    
    var body: some View {
        VStack {
            Button("Toggle Mini Recorder") {
                Task {
                    await whisperState.toggleMiniRecorder()
                }
            }
            
            Toggle("AI Enhancement", isOn: $enhancementService.isEnhancementEnabled)
            
            Menu {
                ForEach(aiService.connectedProviders, id: \.self) { provider in
                    Button {
                        aiService.selectedProvider = provider
                    } label: {
                        HStack {
                            Text(provider.rawValue)
                            if aiService.selectedProvider == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if aiService.connectedProviders.isEmpty {
                    Text("No providers connected")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Button("Manage AI Providers") {
                    menuBarManager.openMainWindowAndNavigate(to: "Enhancement")
                }
            } label: {
                HStack {
                    Text("AI Provider: \(aiService.selectedProvider.rawValue)")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            Menu {
                ForEach(whisperState.availableModels) { model in
                    Button {
                        Task {
                            await whisperState.setDefaultModel(model)
                        }
                    } label: {
                        HStack {
                            Text(PredefinedModels.models.first { $0.name == model.name }?.displayName ?? model.name)
                            if whisperState.currentModel?.name == model.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if whisperState.availableModels.isEmpty {
                    Text("No models downloaded")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Button("Manage Models") {
                    menuBarManager.openMainWindowAndNavigate(to: "AI Models")
                }
            } label: {
                HStack {
                    Text("Model: \(PredefinedModels.models.first { $0.name == whisperState.currentModel?.name }?.displayName ?? "None")")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            LanguageSelectionView(whisperState: whisperState, displayMode: .menuItem)
            
            Toggle("Use Clipboard Context", isOn: $enhancementService.useClipboardContext)
                .disabled(!enhancementService.isEnhancementEnabled)
            
            Toggle("Use Screen Context", isOn: $enhancementService.useScreenCaptureContext)
                .disabled(!enhancementService.isEnhancementEnabled)
            
            Menu("Additional") {
                Button {
                    whisperState.isAutoCopyEnabled.toggle()
                } label: {
                    HStack {
                        Text("Auto-copy to Clipboard")
                        Spacer()
                        if whisperState.isAutoCopyEnabled {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button {
                    SoundManager.shared.isEnabled.toggle()
                    menuRefreshTrigger.toggle()
                } label: {
                    HStack {
                        Text("Sound Feedback")
                        Spacer()
                        if SoundManager.shared.isEnabled {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button {
                    MediaController.shared.isMediaPauseEnabled.toggle()
                    menuRefreshTrigger.toggle()
                } label: {
                    HStack {
                        Text("Pause Media During Recording")
                        Spacer()
                        if MediaController.shared.isMediaPauseEnabled {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .id("additional-menu-\(menuRefreshTrigger)")
            
            Divider()
            
            Button("History") {
                menuBarManager.openMainWindowAndNavigate(to: "History")
            }
            
            Button("Settings") {
                menuBarManager.openMainWindowAndNavigate(to: "Settings")
            }
            
            Button(menuBarManager.isMenuBarOnly ? "Show Dock Icon" : "Hide Dock Icon") {
                menuBarManager.toggleMenuBarOnly()
            }
            
            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            
            Divider()
            
            Button("Check for Updates") {
                updaterViewModel.checkForUpdates()
            }
            .disabled(!updaterViewModel.canCheckForUpdates)
            
            Button("About TalkMax") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Button("Help and Support") {
                openMailForSupport()
            }
            
            Divider()
            
            Button("Quit TalkMax") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func openMailForSupport() {
        let subject = "TalkMax Help & Support"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = URL(string: "mailto:nishank@gmail.com?subject=\(encodedSubject)")!
        NSWorkspace.shared.open(mailtoURL)
    }
}
