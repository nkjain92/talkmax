import Foundation
import IOKit

class PolarService {
    private let organizationId = "Org"
    private let apiToken = "Token"
    private let baseURL = "https://api.polar.sh"
    
    struct LicenseValidationResponse: Codable {
        let status: String
        let limit_activations: Int?
        let id: String?
        let activation: ActivationResponse?
    }
    
    struct ActivationResponse: Codable {
        let id: String
    }
    
    struct ActivationRequest: Codable {
        let key: String
        let organization_id: String
        let label: String
        let meta: [String: String]
    }
    
    struct ActivationResult: Codable {
        let id: String
        let license_key: LicenseKeyInfo
    }
    
    struct LicenseKeyInfo: Codable {
        let limit_activations: Int
        let status: String
    }
    
    // Generate a unique device identifier
    private func getDeviceIdentifier() -> String {
        // Use the macOS serial number or a generated UUID that persists
        if let serialNumber = getMacSerialNumber() {
            return serialNumber
        }
        
        // Fallback to a stored UUID if we can't get the serial number
        let defaults = UserDefaults.standard
        if let storedId = defaults.string(forKey: "TalkMaxDeviceIdentifier") {
            return storedId
        }
        
        // Create and store a new UUID if none exists
        let newId = UUID().uuidString
        defaults.set(newId, forKey: "TalkMaxDeviceIdentifier")
        return newId
    }
    
    // Try to get the Mac serial number
    private func getMacSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if platformExpert == 0 { return nil }
        
        defer { IOObjectRelease(platformExpert) }
        
        if let serialNumber = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0) {
            return (serialNumber.takeRetainedValue() as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    // Check if a license key requires activation
    func checkLicenseRequiresActivation(_ key: String) async throws -> (isValid: Bool, requiresActivation: Bool, activationsLimit: Int?) {
        let url = URL(string: "\(baseURL)/v1/customer-portal/license-keys/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "key": key,
            "organization_id": organizationId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Error Response: \(errorString)")
                }
                throw LicenseError.validationFailed
            }
        }
        
        let validationResponse = try JSONDecoder().decode(LicenseValidationResponse.self, from: data)
        let isValid = validationResponse.status == "granted"
        
        // If limit_activations is nil or 0, the license doesn't require activation
        let requiresActivation = (validationResponse.limit_activations ?? 0) > 0
        
        return (isValid: isValid, requiresActivation: requiresActivation, activationsLimit: validationResponse.limit_activations)
    }
    
    // Activate a license key on this device
    func activateLicenseKey(_ key: String) async throws -> (activationId: String, activationsLimit: Int) {
        let url = URL(string: "\(baseURL)/v1/customer-portal/license-keys/activate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        
        let deviceId = getDeviceIdentifier()
        let hostname = Host.current().localizedName ?? "Unknown Mac"
        
        let activationRequest = ActivationRequest(
            key: key,
            organization_id: organizationId,
            label: hostname,
            meta: ["device_id": deviceId]
        )
        
        request.httpBody = try JSONEncoder().encode(activationRequest)
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Error Response: \(errorString)")
                    
                    // Check for specific error messages
                    if errorString.contains("License key does not require activation") {
                        throw LicenseError.activationNotRequired
                    }
                }
                throw LicenseError.activationFailed
            }
        }
        
        let activationResult = try JSONDecoder().decode(ActivationResult.self, from: data)
        return (activationId: activationResult.id, activationsLimit: activationResult.license_key.limit_activations)
    }
    
    // Validate a license key with an activation ID
    func validateLicenseKeyWithActivation(_ key: String, activationId: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/v1/customer-portal/license-keys/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "key": key,
            "organization_id": organizationId,
            "activation_id": activationId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Error Response: \(errorString)")
                }
                throw LicenseError.validationFailed
            }
        }
        
        let validationResponse = try JSONDecoder().decode(LicenseValidationResponse.self, from: data)
        return validationResponse.status == "granted"
    }
}

enum LicenseError: Error, LocalizedError {
    case activationFailed
    case validationFailed
    case activationLimitReached
    case activationNotRequired
    
    var errorDescription: String? {
        switch self {
        case .activationFailed:
            return "Failed to activate license on this device."
        case .validationFailed:
            return "License validation failed."
        case .activationLimitReached:
            return "This license has reached its maximum number of activations."
        case .activationNotRequired:
            return "This license does not require activation."
        }
    }
} 
