import SwiftUI

struct TimeEfficiencyView: View {
    let totalRecordedTime: TimeInterval
    let estimatedTypingTime: TimeInterval
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Time Efficiency")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                Text("Time Saved: \(timeFormattedString(timeSaved))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Full bar (representing typing time)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.gray.opacity(0.2),
                                    Color.gray.opacity(0.1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 24)

                    // Actual time spent (represented as a portion of the bar)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.green,
                                    Color.green.opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: (1.0 - calculateRatio()) * geometry.size.width, height: 24)

                    // Progress percentage label
                    HStack {
                        Spacer()

                        if efficiencyPercentage >= 10 {
                            Text("\(efficiencyPercentage, specifier: "%.0f")% more efficient")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        }

                        Spacer()
                    }
                }
            }
            .frame(height: 24)

            // Comparative metrics
            HStack(spacing: 30) {
                timeMetric(
                    label: "Voice Recording",
                    value: timeFormattedString(totalRecordedTime),
                    icon: "mic.fill",
                    color: .green
                )

                timeMetric(
                    label: "Estimated Typing",
                    value: timeFormattedString(estimatedTypingTime),
                    icon: "keyboard.fill",
                    color: .gray
                )
            }
            .padding(.top, 8)
        }
    }

    private func timeMetric(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color,
                            color.opacity(0.7)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
        }
    }

    // MARK: - Helper Methods

    private var timeSaved: TimeInterval {
        max(0, estimatedTypingTime - totalRecordedTime)
    }

    private var efficiencyPercentage: Double {
        guard estimatedTypingTime > 0 else { return 0 }
        let ratio = (estimatedTypingTime - totalRecordedTime) / estimatedTypingTime
        return max(0, ratio * 100)
    }

    private func timeFormattedString(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(Int(seconds))s"
        }
    }

    private func calculateRatio() -> Double {
        guard estimatedTypingTime > 0 else { return 0 }
        let ratio = totalRecordedTime / estimatedTypingTime
        // Limit the ratio to a maximum of 1.0 (100% of the bar width)
        return min(max(0, ratio), 1.0)
    }
}
