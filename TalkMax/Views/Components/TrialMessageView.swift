import SwiftUI

struct TrialMessageView: View {
    let message: String
    let type: MessageType
    
    enum MessageType {
        case warning
        case expired
        case info
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if type == .expired || type == .warning {
                Button(action: {
                    if let url = URL(string: "https://trytalkmax.com/buy") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(type == .expired ? "Upgrade Now" : "Upgrade")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }
    
    private var icon: String {
        switch type {
        case .warning: return "exclamationmark.triangle.fill"
        case .expired: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .warning: return .orange
        case .expired: return .red
        case .info: return .blue
        }
    }
    
    private var title: String {
        switch type {
        case .warning: return "Trial Ending Soon"
        case .expired: return "Trial Expired"
        case .info: return "Trial Active"
        }
    }
    
    private var backgroundColor: Color {
        switch type {
        case .warning: return Color.orange.opacity(0.1)
        case .expired: return Color.red.opacity(0.1)
        case .info: return Color.blue.opacity(0.1)
        }
    }
} 
