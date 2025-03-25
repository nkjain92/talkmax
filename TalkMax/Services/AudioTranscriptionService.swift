import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import os

@MainActor
class AudioTranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var messageLog = ""
    @Published var currentError: TranscriptionError?
    
    private var whisperContext: WhisperContext?
    private let modelContext: ModelContext
    private let enhancementService: AIEnhancementService?
    private let whisperState: WhisperState
    private let logger = Logger(subsystem: "com.nishank.talkmax", category: "AudioTranscriptionService")
    
    enum TranscriptionError: Error {
        case noAudioFile
        case transcriptionFailed
        case modelNotLoaded
        case invalidAudioFormat
    }
    
    init(modelContext: ModelContext, whisperState: WhisperState) {
        self.modelContext = modelContext
        self.whisperState = whisperState
        self.enhancementService = whisperState.enhancementService
    }
    
    func retranscribeAudio(from url: URL, using whisperModel: WhisperModel) async throws -> Transcription {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.noAudioFile
        }
        
        await MainActor.run {
            isTranscribing = true
            messageLog = "Loading model...\n"
        }
        
        // Load the whisper model if needed
        if whisperContext == nil {
            do {
                whisperContext = try await WhisperContext.createContext(path: whisperModel.url.path)
                messageLog += "Model loaded successfully.\n"
            } catch {
                logger.error("❌ Failed to load model: \(error.localizedDescription)")
                messageLog += "Failed to load model: \(error.localizedDescription)\n"
                isTranscribing = false
                throw TranscriptionError.modelNotLoaded
            }
        }
        
        guard let whisperContext = whisperContext else {
            isTranscribing = false
            throw TranscriptionError.modelNotLoaded
        }
        
        // Get audio duration
        let audioAsset = AVURLAsset(url: url)
        var duration: TimeInterval = 0
        
        if #available(macOS 13.0, *) {
            let durationValue = try await audioAsset.load(.duration)
            duration = CMTimeGetSeconds(durationValue)
        } else {
            duration = CMTimeGetSeconds(audioAsset.duration)
        }
        
        // Create a permanent copy of the audio file
        let recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.nishank.TalkMax")
            .appendingPathComponent("Recordings")
        
        let fileName = "retranscribed_\(UUID().uuidString).wav"
        let permanentURL = recordingsDirectory.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.copyItem(at: url, to: permanentURL)
        } catch {
            logger.error("❌ Failed to create permanent copy of audio: \(error.localizedDescription)")
            messageLog += "Failed to create permanent copy of audio: \(error.localizedDescription)\n"
            isTranscribing = false
            throw error
        }
        
        let permanentURLString = permanentURL.absoluteString
        
        // Transcribe the audio
        messageLog += "Transcribing audio...\n"
        
        do {
            // Read audio samples
            let samples = try readAudioSamples(permanentURL)
            
            // Process with Whisper - using the same prompt as WhisperState
            messageLog += "Setting prompt: \(whisperState.whisperPrompt.transcriptionPrompt)\n"
            await whisperContext.setPrompt(whisperState.whisperPrompt.transcriptionPrompt)
            
            try await whisperContext.fullTranscribe(samples: samples)
            var text = await whisperContext.getTranscription()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.notice("✅ Retranscription completed successfully, length: \(text.count) characters")
            
            // Apply word replacements if enabled
            if UserDefaults.standard.bool(forKey: "IsWordReplacementEnabled") {
                text = WordReplacementService.shared.applyReplacements(to: text)
                logger.notice("✅ Word replacements applied")
            }
            
            // Apply AI enhancement if enabled - using the same enhancement service as WhisperState
            if let enhancementService = enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured {
                do {
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
                    do {
                        try modelContext.save()
                    } catch {
                        logger.error("❌ Failed to save transcription: \(error.localizedDescription)")
                        messageLog += "Failed to save transcription: \(error.localizedDescription)\n"
                    }
                    
                    await MainActor.run {
                        isTranscribing = false
                        messageLog += "Done: \(enhancedText)\n"
                    }
                    
                    return newTranscription
                } catch {
                    messageLog += "Enhancement failed: \(error.localizedDescription). Using original transcription.\n"
                    let newTranscription = Transcription(
                        text: text,
                        duration: duration,
                        audioFileURL: permanentURLString
                    )
                    modelContext.insert(newTranscription)
                    do {
                        try modelContext.save()
                    } catch {
                        logger.error("❌ Failed to save transcription: \(error.localizedDescription)")
                        messageLog += "Failed to save transcription: \(error.localizedDescription)\n"
                    }
                    
                    await MainActor.run {
                        isTranscribing = false
                        messageLog += "Done: \(text)\n"
                    }
                    
                    return newTranscription
                }
            } else {
                let newTranscription = Transcription(
                    text: text,
                    duration: duration,
                    audioFileURL: permanentURLString
                )
                modelContext.insert(newTranscription)
                do {
                    try modelContext.save()
                } catch {
                    logger.error("❌ Failed to save transcription: \(error.localizedDescription)")
                    messageLog += "Failed to save transcription: \(error.localizedDescription)\n"
                }
                
                await MainActor.run {
                    isTranscribing = false
                    messageLog += "Done: \(text)\n"
                }
                
                return newTranscription
            }
        } catch {
            logger.error("❌ Transcription failed: \(error.localizedDescription)")
            messageLog += "Transcription failed: \(error.localizedDescription)\n"
            currentError = .transcriptionFailed
            isTranscribing = false
            throw error
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
}
