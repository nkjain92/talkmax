import SwiftUI
import SwiftData
import KeyboardShortcuts

// ViewType enum with all cases
enum ViewType: String, CaseIterable {
    case metrics = "Dashboard"
    case record = "Record Audio"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case models = "AI Models"
    case enhancement = "Enhancement"
    case powerMode = "Power Mode"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case dictionary = "Dictionary"
    case settings = "Settings"
    case about = "About"

    var icon: String {
        switch self {
        case .metrics: return "gauge.medium"
        case .record: return "mic.circle.fill"
        case .transcribeAudio: return "waveform.circle.fill"
        case .history: return "doc.text.fill"
        case .models: return "brain.head.profile"
        case .enhancement: return "wand.and.stars"
        case .powerMode: return "sparkles.square.fill.on.square"
        case .permissions: return "shield.fill"
        case .audioInput: return "mic.fill"
        case .dictionary: return "character.book.closed.fill"
        case .settings: return "gearshape.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct DynamicSidebar: View {
    @Binding var selectedView: ViewType
    @Binding var hoveredView: ViewType?
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var buttonAnimation

    var body: some View {
        VStack(spacing: 4) {
            // App Header
            HStack(spacing: 10) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(8)
                }

                Text("TalkMax")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)

            // Categories sections
            VStack(alignment: .leading, spacing: 24) {
                // Lists section
                sidebarSection(title: "", items: [.metrics, .history])

                // Creation section
                sidebarSection(title: "Creation", items: [.record, .transcribeAudio])

                // AI & Power section
                sidebarSection(title: "AI & Power", items: [.models, .enhancement, .powerMode])

                // Settings section
                sidebarSection(title: "Settings", items: [.permissions, .audioInput, .dictionary, .settings, .about])
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func sidebarSection(title: String, items: [ViewType]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
            }

            ForEach(items, id: \.self) { viewType in
                DynamicSidebarButton(
                    title: viewType.rawValue,
                    systemImage: viewType.icon,
                    isSelected: selectedView == viewType,
                    isHovered: hoveredView == viewType,
                    namespace: buttonAnimation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedView = viewType
                    }
                }
                .onHover { isHovered in
                    hoveredView = isHovered ? viewType : nil
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DynamicSidebarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let isHovered: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .secondary)
                    .frame(width: 20)

                // Title
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .secondary)

                Spacer()

                // Count badge
                if let count = getCount(for: title), count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ?
                                      Color.accentColor.opacity(0.9) :
                                      Color.secondary.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(colorScheme == .dark ?
                                  Color.accentColor.opacity(0.2) :
                                  Color.accentColor.opacity(0.1))
                            .matchedGeometryEffect(id: "background", in: namespace)
                    } else if isHovered {
                        Capsule()
                            .fill(colorScheme == .dark ?
                                  Color.white.opacity(0.07) :
                                  Color.black.opacity(0.03))
                    }
                }
                .padding(.horizontal, 10)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func getCount(for title: String) -> Int? {
        // Placeholder for now - we'll add real counts later
        switch title {
        case "Dashboard": return 12
        case "History": return 6
        case "Record Audio", "Power Mode": return 2
        default: return nil
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @State private var selectedView: ViewType = .metrics
    @State private var hoveredView: ViewType?
    @State private var hasLoadedData = false
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private var isSetupComplete: Bool {
        hasLoadedData &&
        whisperState.currentModel != nil &&
        KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil &&
        AXIsProcessTrusted() &&
        CGPreflightScreenCaptureAccess()
    }

    var body: some View {
        ZStack {
            // App background - soft gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ?
                        Color(hue: 0.6, saturation: 0.1, brightness: 0.15) :
                        Color(hue: 0.6, saturation: 0.1, brightness: 0.95),
                    colorScheme == .dark ?
                        Color(hue: 0.7, saturation: 0.1, brightness: 0.18) :
                        Color(hue: 0.7, saturation: 0.08, brightness: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Main app container
            HStack(spacing: 0) {
                // Sidebar with elevated design
                ZStack {
                    // Sidebar background with shadow for floating effect
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ?
                              Color(white: 0.17) :
                              Color(white: 0.97))
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                            radius: 15,
                            x: 5,
                            y: 0
                        )

                    // Sidebar content
                    DynamicSidebar(
                        selectedView: $selectedView,
                        hoveredView: $hoveredView
                    )
                }
                .frame(width: 240)
                .padding(.leading, 20)
                .padding(.vertical, 20)

                // Main content area with floating design
                ZStack {
                    // Main content background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ?
                              Color(white: 0.17) :
                              Color.white)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                            radius: 15,
                            x: 0,
                            y: 0
                        )

                    // Detail view content
                    detailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(20)
                }
                .padding(.trailing, 20)
                .padding(.vertical, 20)
                .padding(.leading, 10)
            }
        }
        .frame(minWidth: 1200, minHeight: 750)
        .onAppear {
            hasLoadedData = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            print("ContentView: Received navigation notification")
            if let destination = notification.userInfo?["destination"] as? String {
                print("ContentView: Destination received: \(destination)")
                switch destination {
                case "Settings":
                    print("ContentView: Navigating to Settings")
                    selectedView = .settings
                case "AI Models":
                    print("ContentView: Navigating to AI Models")
                    selectedView = .models
                case "History":
                    print("ContentView: Navigating to History")
                    selectedView = .history
                case "Permissions":
                    print("ContentView: Navigating to Permissions")
                    selectedView = .permissions
                case "Enhancement":
                    print("ContentView: Navigating to Enhancement")
                    selectedView = .enhancement
                default:
                    print("ContentView: No matching destination found for: \(destination)")
                    break
                }
            } else {
                print("ContentView: No destination in notification")
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedView {
        case .metrics:
            if isSetupComplete {
                MetricsView(skipSetupCheck: true)
            } else {
                MetricsSetupView()
            }
        case .models:
            ModelManagementView(whisperState: whisperState)
        case .enhancement:
            EnhancementSettingsView()
        case .record:
            RecordView()
        case .transcribeAudio:
            AudioTranscribeView()
        case .history:
            TranscriptionHistoryView()
        case .audioInput:
            AudioInputSettingsView()
        case .dictionary:
            DictionarySettingsView(whisperPrompt: whisperState.whisperPrompt)
        case .powerMode:
            PowerModeView()
        case .settings:
            SettingsView()
                .environmentObject(whisperState)
        case .about:
            AboutView()
        case .permissions:
            PermissionsView()
        }
    }
}
