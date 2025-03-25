import Foundation

extension UserDefaults {
    enum Keys {
        static let aiProviderApiKey = "TalkMaxAIProviderKey"
    }

    // MARK: - AI Provider API Key
    var aiProviderApiKey: String? {
        get { string(forKey: Keys.aiProviderApiKey) }
        set { setValue(newValue, forKey: Keys.aiProviderApiKey) }
    }
}
