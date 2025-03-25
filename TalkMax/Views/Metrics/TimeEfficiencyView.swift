import SwiftUI

struct TimeEfficiencyView: View {
    // MARK: - Properties
    
    private let totalRecordedTime: TimeInterval
    private let estimatedTypingTime: TimeInterval
    
    // Computed properties for efficiency metrics
    private var timeSaved: TimeInterval {
        estimatedTypingTime - totalRecordedTime
    }
    
    private var efficiencyMultiplier: Double {
        guard totalRecordedTime > 0 else { return 0 }
        let multiplier = estimatedTypingTime / totalRecordedTime
        return round(multiplier * 10) / 10  // Round to 1 decimal place
    }
    
    private var efficiencyMultiplierFormatted: String {
        String(format: "%.1fx", efficiencyMultiplier)
    }
    
    // MARK: - Initializer
    
    init(totalRecordedTime: TimeInterval, estimatedTypingTime: TimeInterval) {
        self.totalRecordedTime = totalRecordedTime
        self.estimatedTypingTime = estimatedTypingTime
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            mainContent
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            headerSection
            timeComparisonSection
            bottomSection
        }
        .padding(.vertical, 24)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                Text("You are")
                    .font(.system(size: 32, weight: .bold))
                
                Text("\(efficiencyMultiplierFormatted) Faster")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(efficiencyGradient)
                
                Text("with TalkMax")
                    .font(.system(size: 32, weight: .bold))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 24)
    }
    
    private var timeComparisonSection: some View {
        HStack(spacing: 16) {
            TimeBlockView(
                duration: totalRecordedTime,
                label: "SPEAKING TIME",
                icon: "mic.circle.fill",
                color: .green
            )
            
            TimeBlockView(
                duration: estimatedTypingTime,
                label: "TYPING TIME",
                icon: "keyboard.fill",
                color: .orange
            )
        }
        .padding(.horizontal, 24)
    }
    
    private var bottomSection: some View {
        HStack {
            timeSavedView
            Spacer()
            discordCommunityLink
        }
        .padding(.horizontal, 24)
    }
    
    private var timeSavedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIME SAVED")
                .font(.system(size: 13, weight: .heavy))
                .tracking(4)
                .foregroundColor(.secondary)
            
            Text(formatDuration(timeSaved))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(accentGradient)
        }
    }
    
    private var discordCommunityLink: some View {
        Link(destination: URL(string: "https://discord.gg/xryDy57nYD")!) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "ellipsis.message.fill")
                        .foregroundStyle(accentGradient)
                        .font(.system(size: 36))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Need Support?")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Got Feature Ideas? We're Listening!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("JOIN DISCORD")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(6)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color.blue.opacity(0.7))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var efficiencyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.green,
                Color.green.opacity(0.7)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: .controlAccentColor),
                Color(nsColor: .controlAccentColor).opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Utility Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// MARK: - Helper Struct

struct TimeBlockView: View {
    let duration: TimeInterval
    let label: String
    let icon: String
    let color: Color
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDuration(duration))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text(label)
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
        )
    }
}
