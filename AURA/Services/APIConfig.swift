import Foundation

/// API Configuration — DO NOT COMMIT CREDENTIALS
/// Use environment variables or fetch from backend on app startup
struct APIConfig {
    /// 2GIS API Key — should be fetched from secure backend or set via environment
    /// NEVER hardcode in production
    static var twoGISApiKey: String {
        // Try to get from UserDefaults (set by backend)
        if let key = UserDefaults.standard.string(forKey: "twogis_api_key") {
            return key
        }
        
        // Fallback to environment variable if available
        if let key = ProcessInfo.processInfo.environment["TWOGIS_API_KEY"] {
            return key
        }
        
        // Development fallback — empty string forces error handling
        #if DEBUG
        print("⚠️ WARNING: 2GIS API key not configured. Set via UserDefaults or environment variable.")
        return ""
        #else
        fatalError("2GIS API key not configured. Configure via secure backend endpoint.")
        #endif
    }
    
    /// Set API key (call from app startup after fetching from backend)
    static func configure(twoGISKey: String) {
        UserDefaults.standard.set(twoGISKey, forKey: "twogis_api_key")
    }
    
    /// Clear sensitive data
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "twogis_api_key")
    }
}
