import Foundation
import SwiftData

@Model
final class Transcription {
    let id: UUID
    var text: String
    var enhancedText: String?
    var timestamp: Date
    var duration: TimeInterval
    var audioFileURL: String?

    // Compute word count from text
    var wordCount: Int {
        return text.split(separator: " ").count
    }

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), duration: TimeInterval, enhancedText: String? = nil, audioFileURL: String? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.enhancedText = enhancedText
        self.audioFileURL = audioFileURL
    }
}
