import SwiftUI
import KeyboardShortcuts

struct MetricsSetupView: View {
    @EnvironmentObject private var whisperState: WhisperState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAccessibilityEnabled = AXIsProcessTrusted()
    @State private var isScreenRecordingEnabled = CGPreflightScreenCaptureAccess()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    welcomeHeader(geometry: geometry)

                    // Setup Steps Card
                    setupStepsCard(geometry: geometry)

                    // Action Button
                    actionButtonCard(geometry: geometry)
                }
                .padding(32)
                .frame(minHeight: geometry.size.height)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            // Refresh permission status on appear
            isAccessibilityEnabled = AXIsProcessTrusted()
            isScreenRecordingEnabled = CGPreflightScreenCaptureAccess()
        }
    }

    // Animated welcome header
    private func welcomeHeader(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)

                // App icon
                AppIconView(size: min(90, geometry.size.width * 0.15), cornerRadius: 22)
            }

            VStack(spacing: 8) {
                Text("Welcome to TalkMax")
                    .font(.system(size: min(32, geometry.size.width * 0.05), weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)

                Text("Complete the setup to get started")
                    .font(.system(size: min(16, geometry.size.width * 0.025), weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 16)
    }

    // Styled setup steps card
    private func setupStepsCard(geometry: GeometryProxy) -> some View {
        VStack(spacing: 6) {
            ForEach(0..<4) { index in
                setupStep(for: index, geometry: geometry)

                if index < 3 {
                    Divider()
                        .padding(.horizontal, 32)
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor))

                // Subtle inner shadow at the top
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.07),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    // Styled action button card
    private func actionButtonCard(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            Button(action: {
                if !isAccessibilityEnabled || !isScreenRecordingEnabled {
                    openSettings()
                } else if whisperState.currentModel == nil {
                    openModelManagement()
                }
            }) {
                HStack {
                    Spacer()

                    Text(buttonText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(
                    color: Color.accentColor.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Help text
            Text(helpTextContent)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: min(600, geometry.size.width * 0.8))
        }
        .padding(24)
        .background(
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor))

                // Subtle inner shadow at the top
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.07),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    private func setupStep(for index: Int, geometry: GeometryProxy) -> some View {
        let isCompleted: Bool
        let icon: String
        let title: String
        let description: String

        switch index {
        case 0:
            isCompleted = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil
            icon = "command"
            title = "Set Keyboard Shortcut"
            description = "Set up a keyboard shortcut to use TalkMax anywhere"
        case 1:
            isCompleted = isAccessibilityEnabled
            icon = "hand.raised"
            title = "Enable Accessibility"
            description = "Allow TalkMax to paste transcribed text directly at your cursor position"
        case 2:
            isCompleted = isScreenRecordingEnabled
            icon = "video"
            title = "Enable Screen Recording"
            description = "Allow TalkMax to understand context from your screen for transcript Enhancement"
        default:
            isCompleted = whisperState.currentModel != nil
            icon = "arrow.down"
            title = "Download Model"
            description = "Choose and download an AI model"
        }

        return HStack(spacing: 16) {
            // Status Icon
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isCompleted ?
                                    Color.green.opacity(0.25) :
                                    Color.red.opacity(0.25),
                                isCompleted ?
                                    Color.green.opacity(0.15) :
                                    Color.red.opacity(0.15)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                (isCompleted ? Color.green : Color.red).opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 20
                        )
                    )
                    .frame(width: 48, height: 48)
                    .blur(radius: 2.5)

                // Icon
                Image(systemName: "\(icon)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isCompleted ? Color.green : Color.red,
                                isCompleted ? Color.green.opacity(0.8) : Color.red.opacity(0.8)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: min(16, geometry.size.width * 0.025), weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(description)
                    .font(.system(size: min(14, geometry.size.width * 0.022)))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            if isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green,
                                Color.green.opacity(0.8)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.red,
                                Color.red.opacity(0.8)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .padding(.vertical, 12)
    }

    private var buttonText: String {
        if !isAccessibilityEnabled || !isScreenRecordingEnabled {
            return "Open System Settings"
        } else if whisperState.currentModel == nil {
            return "Download AI Model"
        } else {
            return "Start Using TalkMax"
        }
    }

    private var helpTextContent: String {
        if !isAccessibilityEnabled {
            return "TalkMax needs accessibility permissions to paste text and control your keyboard shortcuts."
        } else if !isScreenRecordingEnabled {
            return "TalkMax needs screen recording permissions to understand context for AI enhancement."
        } else if whisperState.currentModel == nil {
            return "TalkMax needs an AI model to transcribe your voice. Don't worry, all processing happens on your device."
        } else {
            return "All set! You can now start using TalkMax to transcribe your voice."
        }
    }

    private func openSettings() {
        NotificationCenter.default.post(
            name: .navigateToDestination,
            object: nil,
            userInfo: ["destination": "Settings"]
        )
    }

    private func openModelManagement() {
        NotificationCenter.default.post(
            name: .navigateToDestination,
            object: nil,
            userInfo: ["destination": "AI Models"]
        )
    }
}

