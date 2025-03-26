import SwiftUI
import Charts
import KeyboardShortcuts

struct MetricsContent: View {
    let transcriptions: [Transcription]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if transcriptions.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Efficiency Card
                    dashboardCard {
                        TimeEfficiencyView(totalRecordedTime: totalRecordedTime, estimatedTypingTime: estimatedTypingTime)
                    }

                    // Metrics Grid
                    metricsGrid

                    // Chart Card
                    dashboardCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TalkMax Activity")
                                .font(.system(size: 16, weight: .semibold))

                            talkMaxTrendChart
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                // Glow background
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 10)

                // Icon
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("No Transcriptions Yet")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text("Start recording to see your metrics")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }

            Button(action: {
                // Properly trigger recording using NotificationCenter instead
                if KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil {
                    NotificationCenter.default.post(name: .toggleMiniRecorder, object: nil)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                    Text("Start Recording")
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
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
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .shadow(
                color: Color.accentColor.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Words Captured",
                value: "\(totalWordsTranscribed)",
                icon: "text.word.spacing",
                color: .blue
            )
            MetricCard(
                title: "Voice-to-Text Sessions",
                value: "\(transcriptions.count)",
                icon: "mic.circle.fill",
                color: .green
            )
            MetricCard(
                title: "Average Words/Minute",
                value: String(format: "%.1f", averageWordsPerMinute),
                icon: "speedometer",
                color: .orange
            )
            MetricCard(
                title: "Words/Session",
                value: String(format: "%.1f", averageWordsPerSession),
                icon: "chart.bar.fill",
                color: .purple
            )
        }
    }

    private var talkMaxTrendChart: some View {
        // Group transcriptions by day for the chart
        var groupedByDay: [Date: [Transcription]] = [:]
        for transcription in transcriptions {
            let day = Calendar.current.startOfDay(for: transcription.timestamp)
            if groupedByDay[day] == nil {
                groupedByDay[day] = []
            }
            groupedByDay[day]?.append(transcription)
        }

        // Create data points for each day
        let sortedDays = groupedByDay.keys.sorted()
        let chartData = sortedDays.map { date -> (Date, Int) in
            let transcriptionsOnDay = groupedByDay[date] ?? []
            let wordCount = transcriptionsOnDay.reduce(0) { $0 + $1.wordCount }
            return (date, wordCount)
        }

        // Chart with enhanced styling
        return VStack {
            if chartData.isEmpty {
                Text("Not enough data for chart")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(chartData, id: \.0) { dataPoint in
                        BarMark(
                            x: .value("Date", dataPoint.0, unit: .day),
                            y: .value("Words", dataPoint.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.7)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day().month())
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(
                            stroke: StrokeStyle(
                                lineWidth: 1,
                                dash: [5, 5]
                            )
                        )
                        .foregroundStyle(Color.gray.opacity(0.3))

                        AxisValueLabel {
                            // Simplify the approach to display the value
                            Text(value.as(Int.self)?.description ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .chartBackground { _ in
                    Color.clear
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Card Container
    @ViewBuilder
    private func dashboardCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
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

    // MARK: - Computed Properties
    private var totalWordsTranscribed: Int {
        transcriptions.reduce(0) { $0 + $1.wordCount }
    }

    private var totalRecordedTime: TimeInterval {
        transcriptions.reduce(0) { $0 + $1.duration }
    }

    private var estimatedTypingTime: TimeInterval {
        // Assume average typing speed of 40 WPM (0.67 words per second)
        let wordsPerSecond = 0.67
        return Double(totalWordsTranscribed) / wordsPerSecond
    }

    private var averageWordsPerMinute: Double {
        guard totalRecordedTime > 0 else { return 0 }
        return Double(totalWordsTranscribed) / (totalRecordedTime / 60)
    }

    private var averageWordsPerSession: Double {
        guard !transcriptions.isEmpty else { return 0 }
        return Double(totalWordsTranscribed) / Double(transcriptions.count)
    }
}
