import SwiftUI
import SwiftData
import Charts
import KeyboardShortcuts

struct MetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transcription.timestamp) private var transcriptions: [Transcription]
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasLoadedData = false
    let skipSetupCheck: Bool

    init(skipSetupCheck: Bool = false) {
        self.skipSetupCheck = skipSetupCheck
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ?
                        Color(hue: 0.6, saturation: 0.1, brightness: 0.15).opacity(0.8) :
                        Color(hue: 0.6, saturation: 0.1, brightness: 0.95).opacity(0.8),
                    colorScheme == .dark ?
                        Color(hue: 0.7, saturation: 0.1, brightness: 0.18).opacity(0.8) :
                        Color(hue: 0.7, saturation: 0.08, brightness: 0.98).opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Content
            if skipSetupCheck {
                MetricsContent(transcriptions: Array(transcriptions))
            } else if isSetupComplete {
                MetricsContent(transcriptions: Array(transcriptions))
            } else {
                MetricsSetupView()
            }
        }
        .task {
            // Ensure the model context is ready
            hasLoadedData = true
        }
    }

    private var isSetupComplete: Bool {
        hasLoadedData &&
        whisperState.currentModel != nil &&
        KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil &&
        AXIsProcessTrusted() &&
        CGPreflightScreenCaptureAccess()
    }
}
