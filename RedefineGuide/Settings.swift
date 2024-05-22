import Foundation
import Combine

fileprivate let server_url_key = "server_url"

class Settings: ObservableObject {
    static let shared = Settings()

    /// The url to the web server for development testing
    var devServerUrl: String {
        get {
            return _serverUrl
        }
        set {
            _serverUrl = newValue
            
            Settings.persistedSettings.set(_serverUrl, forKey: server_url_key)
        }
    }
    private var _serverUrl: String
    
    private init() {
        _serverUrl = Settings.persistedSettings.string(forKey: server_url_key) ?? "unnamed device"
    }
    
    private static var persistedSettings: UserDefaults {
        return UserDefaults.standard
    }
}
