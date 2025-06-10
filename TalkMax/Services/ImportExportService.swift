import Foundation
import AppKit
import UniformTypeIdentifiers
import KeyboardShortcuts
import LaunchAtLogin

struct GeneralSettings: Codable {
    let toggleMiniRecorderShortcut: KeyboardShortcuts.Shortcut?
    let isPushToTalkEnabled: Bool?
    let pushToTalkKeyRawValue: String?
    let launchAtLoginEnabled: Bool?
    let isMenuBarOnly: Bool?
    let useAppleScriptPaste: Bool?
    let recorderType: String?
    let isAudioCleanupEnabled: Bool?
    let audioRetentionPeriod: Int?
    let isAutoCopyEnabled: Bool?
    let isSoundFeedbackEnabled: Bool?
    let isSystemMuteEnabled: Bool?
    let currentTranscriptionModel: String?
    let selectedLanguage: String?
}

struct TalkMaxExportedSettings: Codable {
    let version: String
    let customPrompts: [CustomPrompt]
    let powerModeConfigs: [PowerModeConfig]
    let defaultPowerModeConfig: PowerModeConfig
    let dictionaryItems: [DictionaryItem]?
    let wordReplacements: [String: String]?
    let generalSettings: GeneralSettings?
    let customEmojis: [String]?
}

class ImportExportService {
    static let shared = ImportExportService()
    private let currentSettingsVersion: String
    private let dictionaryItemsKey = "CustomDictionaryItems"
    private let wordReplacementsKey = "wordReplacements"

    private let keyIsPushToTalkEnabled = "isPushToTalkEnabled"
    private let keyPushToTalkKey = "pushToTalkKey"
    private let keyIsMenuBarOnly = "IsMenuBarOnly"
    private let keyUseAppleScriptPaste = "UseAppleScriptPaste"
    private let keyRecorderType = "RecorderType"
    private let keyIsAudioCleanupEnabled = "IsAudioCleanupEnabled"
    private let keyAudioRetentionPeriod = "AudioRetentionPeriod"
    private let keyIsAutoCopyEnabled = "IsAutoCopyEnabled"
    private let keyIsSoundFeedbackEnabled = "isSoundFeedbackEnabled"
    private let keyIsSystemMuteEnabled = "isSystemMuteEnabled"

    private init() {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            self.currentSettingsVersion = version
        } else {
            self.currentSettingsVersion = "0.0.0"
        }
    }

    @MainActor
    func exportSettings(enhancementService: AIEnhancementService, whisperPrompt: WhisperPrompt, hotkeyManager: HotkeyManager, menuBarManager: MenuBarManager, mediaController: MediaController, soundManager: SoundManager, whisperState: WhisperState) {
        let powerModeManager = PowerModeManager.shared
        let emojiManager = EmojiManager.shared

        let exportablePrompts = enhancementService.customPrompts.filter { !$0.isPredefined }

        let powerConfigs = powerModeManager.configurations
        let defaultPowerConfig = powerModeManager.defaultConfig

        var exportedDictionaryItems: [DictionaryItem]? = nil
        if let data = UserDefaults.standard.data(forKey: dictionaryItemsKey),
           let items = try? JSONDecoder().decode([DictionaryItem].self, from: data) {
            exportedDictionaryItems = items
        }

        let exportedWordReplacements = UserDefaults.standard.dictionary(forKey: wordReplacementsKey) as? [String: String]

        let generalSettingsToExport = GeneralSettings(
            toggleMiniRecorderShortcut: KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder),
            isPushToTalkEnabled: hotkeyManager.isPushToTalkEnabled,
            pushToTalkKeyRawValue: hotkeyManager.pushToTalkKey.rawValue,
            launchAtLoginEnabled: LaunchAtLogin.isEnabled,
            isMenuBarOnly: menuBarManager.isMenuBarOnly,
            useAppleScriptPaste: UserDefaults.standard.bool(forKey: keyUseAppleScriptPaste),
            recorderType: whisperState.recorderType,
            isAudioCleanupEnabled: UserDefaults.standard.bool(forKey: keyIsAudioCleanupEnabled),
            audioRetentionPeriod: UserDefaults.standard.integer(forKey: keyAudioRetentionPeriod),
            isAutoCopyEnabled: whisperState.isAutoCopyEnabled,
            isSoundFeedbackEnabled: soundManager.isEnabled,
            isSystemMuteEnabled: mediaController.isSystemMuteEnabled,
            currentTranscriptionModel: whisperState.currentTranscriptionModel?.name,
            selectedLanguage: UserDefaults.standard.string(forKey: "SelectedLanguage")
        )

        let exportedSettings = TalkMaxExportedSettings(
            version: currentSettingsVersion,
            customPrompts: exportablePrompts,
            powerModeConfigs: powerConfigs,
            defaultPowerModeConfig: defaultPowerConfig,
            dictionaryItems: exportedDictionaryItems,
            wordReplacements: exportedWordReplacements,
            generalSettings: generalSettingsToExport,
            customEmojis: emojiManager.customEmojis
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let jsonData = try encoder.encode(exportedSettings)

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.json]
            savePanel.nameFieldStringValue = "TalkMax_Settings_Backup.json"
            savePanel.title = "Export TalkMax Settings"
            savePanel.message = "Choose a location to save your settings."

            DispatchQueue.main.async {
                if savePanel.runModal() == .OK {
                    if let url = savePanel.url {
                        do {
                            try jsonData.write(to: url)
                            self.showAlert(title: "Export Successful", message: "Your settings have been successfully exported to \(url.lastPathComponent).")
                        } catch {
                            self.showAlert(title: "Export Error", message: "Could not save settings to file: \(error.localizedDescription)")
                        }
                    }
                } else {
                    self.showAlert(title: "Export Canceled", message: "The settings export operation was canceled.")
                }
            }
        } catch {
            self.showAlert(title: "Export Error", message: "Could not encode settings to JSON: \(error.localizedDescription)")
        }
    }

    @MainActor
    func importSettings(enhancementService: AIEnhancementService, whisperPrompt: WhisperPrompt, hotkeyManager: HotkeyManager, menuBarManager: MenuBarManager, mediaController: MediaController, soundManager: SoundManager, whisperState: WhisperState) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import TalkMax Settings"
        openPanel.message = "Choose a settings file to import. This will overwrite ALL settings (prompts, power modes, dictionary, general app settings)."

        DispatchQueue.main.async {
            if openPanel.runModal() == .OK {
                guard let url = openPanel.url else {
                    self.showAlert(title: "Import Error", message: "Could not get the file URL from the open panel.")
                    return
                }

                do {
                    let jsonData = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let importedSettings = try decoder.decode(TalkMaxExportedSettings.self, from: jsonData)
                    
                    if importedSettings.version != self.currentSettingsVersion {
                        self.showAlert(title: "Version Mismatch", message: "The imported settings file (version \(importedSettings.version)) is from a different version than your application (version \(self.currentSettingsVersion)). Proceeding with import, but be aware of potential incompatibilities.")
                    }

                    let predefinedPrompts = enhancementService.customPrompts.filter { $0.isPredefined }
                    enhancementService.customPrompts = predefinedPrompts + importedSettings.customPrompts
                    
                    let powerModeManager = PowerModeManager.shared
                    powerModeManager.configurations = importedSettings.powerModeConfigs
                    powerModeManager.defaultConfig = importedSettings.defaultPowerModeConfig
                    powerModeManager.saveConfigurations()
                    powerModeManager.updateConfiguration(powerModeManager.defaultConfig)

                    if let customEmojis = importedSettings.customEmojis {
                        let emojiManager = EmojiManager.shared
                        for emoji in customEmojis {
                            _ = emojiManager.addCustomEmoji(emoji)
                        }
                    }

                    if let itemsToImport = importedSettings.dictionaryItems {
                        Task {
                            await whisperPrompt.saveDictionaryItems(itemsToImport)
                        }
                    } else {
                        print("No dictionary items (for spelling) found in the imported file. Existing items remain unchanged.")
                    }

                    if let replacementsToImport = importedSettings.wordReplacements {
                        UserDefaults.standard.set(replacementsToImport, forKey: self.wordReplacementsKey)
                    } else {
                        print("No word replacements found in the imported file. Existing replacements remain unchanged.")
                    }

                    if let general = importedSettings.generalSettings {
                        if let shortcut = general.toggleMiniRecorderShortcut {
                            KeyboardShortcuts.setShortcut(shortcut, for: .toggleMiniRecorder)
                        }
                        if let pttEnabled = general.isPushToTalkEnabled {
                            hotkeyManager.isPushToTalkEnabled = pttEnabled
                        }
                        if let pttKeyRaw = general.pushToTalkKeyRawValue,
                           let pttKey = HotkeyManager.PushToTalkKey(rawValue: pttKeyRaw) {
                            hotkeyManager.pushToTalkKey = pttKey
                        }
                        if let launch = general.launchAtLoginEnabled {
                            LaunchAtLogin.isEnabled = launch
                        }
                        if let menuOnly = general.isMenuBarOnly {
                            menuBarManager.isMenuBarOnly = menuOnly
                        }
                        if let appleScriptPaste = general.useAppleScriptPaste {
                            UserDefaults.standard.set(appleScriptPaste, forKey: self.keyUseAppleScriptPaste)
                        }
                        if let recType = general.recorderType {
                            whisperState.recorderType = recType
                        }
                        if let audioCleanup = general.isAudioCleanupEnabled {
                            UserDefaults.standard.set(audioCleanup, forKey: self.keyIsAudioCleanupEnabled)
                        }
                        if let audioRetention = general.audioRetentionPeriod {
                            UserDefaults.standard.set(audioRetention, forKey: self.keyAudioRetentionPeriod)
                        }
                        if let autoCopy = general.isAutoCopyEnabled {
                            whisperState.isAutoCopyEnabled = autoCopy
                        }
                        if let soundFeedback = general.isSoundFeedbackEnabled {
                            soundManager.isEnabled = soundFeedback
                        }
                        if let muteSystem = general.isSystemMuteEnabled {
                            mediaController.isSystemMuteEnabled = muteSystem
                        }
                        if let currentModelName = general.currentTranscriptionModel,
                           let selectedModel = whisperState.allAvailableModels.first(where: { $0.name == currentModelName }) {
                            Task {
                                await whisperState.setDefaultTranscriptionModel(selectedModel)
                            }
                        }
                        if let selectedLanguage = general.selectedLanguage {
                            UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage")
                        }
                    }

                    self.showRestartAlert(message: "Settings imported successfully from \(url.lastPathComponent). All settings (including general app settings) have been applied.")

                } catch {
                    self.showAlert(title: "Import Error", message: "Error importing settings: \(error.localizedDescription). The file might be corrupted or not in the correct format.")
                }
            } else {
                self.showAlert(title: "Import Canceled", message: "The settings import operation was canceled.")
            }
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func showRestartAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Import Successful"
            alert.informativeText = message + "\n\nIMPORTANT: If you were using AI enhancement features, please make sure to reconfigure your API keys in the Enhancement section.\n\nIt is recommended to restart TalkMax for all changes to take full effect."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Configure API Keys")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                NotificationCenter.default.post(
                    name: .navigateToDestination,
                    object: nil,
                    userInfo: ["destination": "Enhancement"]
                )
            }
        }
    }
}
