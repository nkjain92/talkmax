import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import AppKit
import KeyboardShortcuts
import os

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isModelLoaded = false
    @Published var messageLog = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    @Published var currentModel: WhisperModel?
    @Published var isModelLoading = false
    @Published var availableModels: [WhisperModel] = []
    @Published var predefinedModels: [PredefinedModel] = PredefinedModels.models
    @Published var clipboardMessage = ""
    @Published var miniRecorderError: String?
    @Published var isProcessing = false
    @Published var shouldCancelRecording = false
    @Published var isTranscribing = false
    @Published var isAutoCopyEnabled: Bool = UserDefaults.standard.object(forKey: "IsAutoCopyEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isAutoCopyEnabled, forKey: "IsAutoCopyEnabled")
        }
    }
    @Published var recorderType: String = UserDefaults.standard.string(forKey: "RecorderType") ?? "mini" {
        didSet {
            UserDefaults.standard.set(recorderType, forKey: "RecorderType")
        }
    }

    @Published var isVisualizerActive = false

    @Published var isMiniRecorderVisible = false {
        didSet {
            if isMiniRecorderVisible {
                showRecorderPanel()
            } else {
                hideRecorderPanel()
            }
        }
    }

    var whisperContext: WhisperContext?
    let recorder = Recorder()
    var recordedFile: URL? = nil
    let whisperPrompt = WhisperPrompt()

    let modelContext: ModelContext

    private var modelUrl: URL? {
        let possibleURLs = [
            Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin", subdirectory: "Models"),
            Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin"),
            Bundle.main.bundleURL.appendingPathComponent("Models/ggml-base.en.bin")
        ]

        for url in possibleURLs {
            if let url = url, FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private enum LoadError: Error {
        case couldNotLocateModel
    }

    let modelsDirectory: URL
    let recordingsDirectory: URL
    let enhancementService: AIEnhancementService?
    let logger = Logger(subsystem: "com.nishank.talkmax", category: "WhisperState")
    private var transcriptionStartTime: Date?
    var notchWindowManager: NotchWindowManager?
    var miniWindowManager: MiniWindowManager?

    // For model progress tracking
    @Published var downloadProgress: [String: Double] = [:]

    init(modelContext: ModelContext, enhancementService: AIEnhancementService? = nil) {
        self.modelContext = modelContext
        self.modelsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.nishank.TalkMax")
            .appendingPathComponent("WhisperModels")
        self.recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.nishank.TalkMax")
            .appendingPathComponent("Recordings")
        self.enhancementService = enhancementService

        super.init()

        setupNotifications()
        createModelsDirectoryIfNeeded()
        createRecordingsDirectoryIfNeeded()
        loadAvailableModels()

        if let savedModelName = UserDefaults.standard.string(forKey: "CurrentModel"),
           let savedModel = availableModels.first(where: { $0.name == savedModelName }) {
            currentModel = savedModel
        }
    }

    private func createRecordingsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            messageLog += "Error creating recordings directory: \(error.localizedDescription)\n"
        }
    }

    func toggleRecord() async {
        if isRecording {
            logger.notice("🛑 Stopping recording")

            await MainActor.run {
                isRecording = false
                isVisualizerActive = false
            }

            await recorder.stopRecording()

            if let recordedFile {
                let duration = Date().timeIntervalSince(transcriptionStartTime ?? Date())
                if !shouldCancelRecording {
                    await transcribeAudio(recordedFile, duration: duration)
                }
            } else {
                logger.error("❌ No recorded file found after stopping recording")
            }
        } else {
            guard currentModel != nil else {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "No Whisper Model Selected"
                    alert.informativeText = "Please select a default whisper model in AI Models tab before recording."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return
            }

            shouldCancelRecording = false

            logger.notice("🎙️ Starting recording")
            requestRecordPermission { [self] granted in
                if granted {
                    Task {
                        do {
                            let file = try FileManager.default.url(for: .documentDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)
                                .appending(path: "output.wav")

                            self.recordedFile = file
                            self.transcriptionStartTime = Date()

                            await MainActor.run {
                                self.isRecording = true
                                self.isVisualizerActive = true
                            }

                            async let recordingTask = self.recorder.startRecording(toOutputFile: file, delegate: self)
                            async let windowConfigTask = ActiveWindowService.shared.applyConfigurationForCurrentApp()

                            async let modelLoadingTask: Void = {
                                if let currentModel = await self.currentModel, await self.whisperContext == nil {
                                    logger.notice("🔄 Loading model in parallel with recording: \(currentModel.name)")
                                    do {
                                        try await self.loadModel(currentModel)
                                    } catch {
                                        logger.error("❌ Model preloading failed: \(error.localizedDescription)")
                                        await MainActor.run {
                                            self.messageLog += "Error preloading model: \(error.localizedDescription)\n"
                                        }
                                    }
                                }
                            }()

                            try await recordingTask
                            await windowConfigTask

                            if let enhancementService = self.enhancementService,
                               enhancementService.isEnhancementEnabled &&
                               enhancementService.useScreenCaptureContext {
                                await enhancementService.captureScreenContext()
                            }

                            await modelLoadingTask

                        } catch {
                            await MainActor.run {
                                self.messageLog += "\(error.localizedDescription)\n"
                                self.isRecording = false
                                self.isVisualizerActive = false
                            }
                        }
                    }
                } else {
                    self.messageLog += "Recording permission denied\n"
                }
            }
        }
    }

    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
#if os(macOS)
        response(true)
#else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            response(granted)
        }
#endif
    }

    // MARK: AVAudioRecorderDelegate

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            Task {
                await handleRecError(error)
            }
        }
    }

    private func handleRecError(_ error: Error) {
        messageLog += "\(error.localizedDescription)\n"
        isRecording = false
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording(success: flag)
        }
    }

    private func onDidFinishRecording(success: Bool) {
        if !success {
            messageLog += "Recording did not finish successfully\n"
        }
    }

    private func transcribeAudio(_ url: URL, duration: TimeInterval) async {
        if shouldCancelRecording { return }

        await MainActor.run {
            isProcessing = true
            isTranscribing = true
            canTranscribe = false
        }

        defer {
            if shouldCancelRecording {
                Task {
                    await cleanupModelResources()
                }
            }
        }

        guard let currentModel = currentModel else {
            logger.error("❌ Cannot transcribe: No model selected")
            messageLog += "Cannot transcribe: No model selected.\n"
            currentError = .modelLoadFailed
            return
        }

        if whisperContext == nil {
            logger.notice("🔄 Model not loaded yet, attempting to load now: \(currentModel.name)")
            do {
                try await loadModel(currentModel)
            } catch {
                logger.error("❌ Failed to load model: \(currentModel.name) - \(error.localizedDescription)")
                messageLog += "Failed to load transcription model. Please try again.\n"
                currentError = .modelLoadFailed
                return
            }
        }

        guard let whisperContext = whisperContext else {
            logger.error("❌ Cannot transcribe: Model could not be loaded")
            messageLog += "Cannot transcribe: Model could not be loaded after retry.\n"
            currentError = .modelLoadFailed
            return
        }

        logger.notice("🔄 Starting transcription with model: \(currentModel.name)")
        do {
            let permanentURL = try saveRecordingPermanently(url)
            let permanentURLString = permanentURL.absoluteString

            if shouldCancelRecording { return }

            messageLog += "Reading wave samples...\n"
            let data = try readAudioSamples(url)

            if shouldCancelRecording { return }

            messageLog += "Transcribing data using \(currentModel.name) model...\n"
            messageLog += "Setting prompt: \(whisperPrompt.transcriptionPrompt)\n"
            await whisperContext.setPrompt(whisperPrompt.transcriptionPrompt)

            if shouldCancelRecording { return }

            await whisperContext.fullTranscribe(samples: data)

            if shouldCancelRecording { return }

            var text = await whisperContext.getTranscription()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.notice("✅ Transcription completed successfully, length: \(text.count) characters")

            if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                text = WordReplacementService.shared.applyReplacements(to: text)
                logger.notice("✅ Word replacements applied")
            }

            if let enhancementService = enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured {
                do {
                    if shouldCancelRecording { return }

                    messageLog += "Enhancing transcription with AI...\n"
                    let enhancedText = try await enhancementService.enhance(text)
                    messageLog += "Enhancement completed.\n"

                    let newTranscription = Transcription(
                        text: text,
                        duration: duration,
                        enhancedText: enhancedText,
                        audioFileURL: permanentURLString
                    )
                    modelContext.insert(newTranscription)
                    try? modelContext.save()

                    text = enhancedText
                } catch {
                    messageLog += "Enhancement failed: \(error.localizedDescription). Using original transcription.\n"
                    let newTranscription = Transcription(
                        text: text,
                        duration: duration,
                        audioFileURL: permanentURLString
                    )
                    modelContext.insert(newTranscription)
                    try? modelContext.save()
                }
            } else {
                let newTranscription = Transcription(
                    text: text,
                    duration: duration,
                    audioFileURL: permanentURLString
                )
                modelContext.insert(newTranscription)
                try? modelContext.save()
            }

            messageLog += "Done: \(text)\n"

            SoundManager.shared.playStopSound()

            if AXIsProcessTrusted() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    CursorPaster.pasteAtCursor(text)
                }
            } else {
                messageLog += "Accessibility permissions not granted. Transcription not pasted automatically.\n"
            }

            if isAutoCopyEnabled {
                let success = ClipboardManager.copyToClipboard(text)
                if success {
                    clipboardMessage = "Transcription copied to clipboard"
                } else {
                    clipboardMessage = "Failed to copy to clipboard"
                    messageLog += "Failed to copy transcription to clipboard\n"
                }
            }

            await cleanupModelResources()
            await dismissMiniRecorder()

        } catch {
            messageLog += "\(error.localizedDescription)\n"
            currentError = .transcriptionFailed

            await cleanupModelResources()
            await dismissMiniRecorder()
        }
    }

    private func readAudioSamples(_ url: URL) throws -> [Float] {
        return try decodeWaveFile(url)
    }

    private func decodeWaveFile(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }

    @Published var currentError: WhisperStateError?

    func getEnhancementService() -> AIEnhancementService? {
        return enhancementService
    }

    private func saveRecordingPermanently(_ tempURL: URL) throws -> URL {
        let fileName = "\(UUID().uuidString).wav"
        let permanentURL = recordingsDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: tempURL, to: permanentURL)
        return permanentURL
    }
}

struct WhisperModel: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var downloadURL: String {
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)"
    }
    var filename: String {
        "\(name).bin"
    }
}

private class TaskDelegate: NSObject, URLSessionTaskDelegate {
    private let continuation: CheckedContinuation<Void, Never>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        continuation.resume()
    }
}

extension Notification.Name {
    static let toggleMiniRecorder = Notification.Name("toggleMiniRecorder")
}
