import SwiftUI

extension CustomPrompt {
    func promptIcon(isSelected: Bool, onTap: @escaping () -> Void, onEdit: ((CustomPrompt) -> Void)? = nil, onDelete: ((CustomPrompt) -> Void)? = nil) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Dynamic background with blur effect
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: isSelected ?
                                Gradient(colors: [
                                    Color.accentColor.opacity(0.9),
                                    Color.accentColor.opacity(0.7)
                                ]) :
                                Gradient(colors: [
                                    Color(NSColor.controlBackgroundColor).opacity(0.95),
                                    Color(NSColor.controlBackgroundColor).opacity(0.85)
                                ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isSelected ?
                                            Color.white.opacity(0.3) : Color.white.opacity(0.15),
                                        isSelected ?
                                            Color.white.opacity(0.1) : Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ?
                            Color.accentColor.opacity(0.4) : Color.black.opacity(0.1),
                        radius: isSelected ? 10 : 6,
                        x: 0,
                        y: 3
                    )

                // Decorative background elements
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                isSelected ?
                                    Color.white.opacity(0.15) : Color.white.opacity(0.08),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .offset(x: -15, y: -15)
                    .blur(radius: 2)

                // Icon with enhanced effects
                Image(systemName: icon.rawValue)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isSelected ?
                                [Color.white, Color.white.opacity(0.9)] :
                                [Color.primary.opacity(0.9), Color.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isSelected ?
                            Color.white.opacity(0.5) : Color.clear,
                        radius: 4
                    )
                    .shadow(
                        color: isSelected ?
                            Color.accentColor.opacity(0.5) : Color.clear,
                        radius: 3
                    )
            }
            .frame(width: 48, height: 48)

            // Enhanced title styling
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ?
                    .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: 70)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onTapGesture(perform: onTap)
        .contextMenu {
            if !isPredefined && (onEdit != nil || onDelete != nil) {
                if let onEdit = onEdit {
                    Button {
                        onEdit(self)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete(self)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct EnhancementSettingsView: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @State private var isEditingPrompt = false
    @State private var isSettingsExpanded = true
    @State private var selectedPromptForEdit: CustomPrompt?
    @State private var isEditingTriggerWord = false
    @State private var tempTriggerWord = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main Settings Sections
                VStack(spacing: 24) {
                    // Enable/Disable Toggle Section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable Enhancement")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Turn on AI-powered enhancement features")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $enhancementService.isEnhancementEnabled)
                                    .toggleStyle(ModernToggleStyle())
                                    .labelsHidden()
                            }

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle("Clipboard Context", isOn: $enhancementService.useClipboardContext)
                                        .toggleStyle(ModernToggleStyle(scale: 0.8))
                                        .disabled(!enhancementService.isEnhancementEnabled)

                                    Text("Use text from clipboard to understand the context")
                                        .font(.system(size: 12))
                                        .foregroundColor(enhancementService.isEnhancementEnabled ? .secondary : .secondary.opacity(0.5))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle("Screen Capture", isOn: $enhancementService.useScreenCaptureContext)
                                        .toggleStyle(ModernToggleStyle(scale: 0.8))
                                        .disabled(!enhancementService.isEnhancementEnabled)

                                    Text("Learn what is on the screen to understand the context")
                                        .font(.system(size: 12))
                                        .foregroundColor(enhancementService.isEnhancementEnabled ? .secondary : .secondary.opacity(0.5))
                                }
                            }
                        }
                    }

                    // 1. AI Provider Integration Section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("AI Provider Integration")
                                .font(.system(size: 15, weight: .semibold))

                            APIKeyManagementView()
                                .padding(.vertical, 8)
                        }
                    }

                    // 3. Enhancement Modes & Assistant Section
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Enhancement Modes & Assistant")
                                .font(.system(size: 15, weight: .semibold))

                            // Modes Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Enhancement Modes")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Button(action: { isEditingPrompt = true }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12))
                                            Text("Add Mode")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Add new mode")
                                }

                                if enhancementService.allPrompts.isEmpty {
                                    Text("No modes available")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                } else {
                                    let columns = [
                                        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 36)
                                    ]

                                    LazyVGrid(columns: columns, spacing: 24) {
                                        ForEach(enhancementService.allPrompts) { prompt in
                                            prompt.promptIcon(
                                                isSelected: enhancementService.selectedPromptId == prompt.id,
                                                onTap: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    enhancementService.setActivePrompt(prompt)
                                                }},
                                                onEdit: { selectedPromptForEdit = $0 },
                                                onDelete: { enhancementService.deletePrompt($0) }
                                            )
                                        }
                                    }
                                    .padding(.vertical, 12)
                                }
                            }

                            Divider()
                                .padding(.vertical, 4)

                            // Assistant Mode Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Assistant Mode")
                                        .font(.system(size: 14, weight: .medium))
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.accentColor)
                                }

                                Text("Configure how to trigger the AI assistant mode")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Current Trigger:")
                                            .font(.system(size: 13, weight: .medium))

                                        Text("\"\(enhancementService.assistantTriggerWord)\"")
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundColor(.accentColor)
                                    }

                                    if isEditingTriggerWord {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 8) {
                                                TextField("New trigger word", text: $tempTriggerWord)
                                                    .textFieldStyle(ModernTextFieldStyle())
                                                    .frame(maxWidth: 200)

                                                Button("Save") {
                                                    enhancementService.assistantTriggerWord = tempTriggerWord
                                                    isEditingTriggerWord = false
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(tempTriggerWord.isEmpty ? Color.gray : Color.accentColor)
                                                .cornerRadius(8)
                                                .disabled(tempTriggerWord.isEmpty)

                                                Button("Cancel") {
                                                    isEditingTriggerWord = false
                                                    tempTriggerWord = enhancementService.assistantTriggerWord
                                                }
                                                .foregroundColor(.primary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color(.windowBackgroundColor))
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                )
                                            }

                                            Text("Default: \"hey\"")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Button("Change Trigger Word") {
                                            tempTriggerWord = enhancementService.assistantTriggerWord
                                            isEditingTriggerWord = true
                                        }
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }

                                Text("Start with \"\(enhancementService.assistantTriggerWord), \" to use AI assistant mode")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("Instead of enhancing the text, TalkMax will respond like a conversational AI assistant")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $isEditingPrompt) {
            PromptEditorView(mode: .add)
        }
        .sheet(item: $selectedPromptForEdit) { prompt in
            PromptEditorView(mode: .edit(prompt))
        }
    }
}

// Modern, rounded toggle style with enhanced visuals
struct ModernToggleStyle: ToggleStyle {
    var scale: CGFloat = 1.0

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            ZStack {
                // Track
                Capsule()
                    .fill(
                        configuration.isOn ?
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.35),
                                Color.gray.opacity(0.25)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 51 * scale, height: 31 * scale)

                // Subtle inner glow
                if configuration.isOn {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 50 * scale, height: 30 * scale)
                        .opacity(0.5)
                }

                // Thumb
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color.white.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: Color.black.opacity(configuration.isOn ? 0.15 : 0.1),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                    .frame(width: 27 * scale, height: 27 * scale)
                    .overlay(
                        // Subtle inner shadow/highlight on thumb
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .opacity(0.5)
                    )
                    .offset(x: configuration.isOn ? 11 * scale : -11 * scale)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isOn)
            }
            .onTapGesture {
                withAnimation {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                ZStack {
                    // Base background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.textBackgroundColor))

                    // Subtle inner shadow at the top
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.03),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 3,
                x: 0,
                y: 1
            )
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
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
}
