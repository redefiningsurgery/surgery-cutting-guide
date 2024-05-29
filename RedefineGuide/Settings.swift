import Foundation
import Combine

fileprivate let server_url_key = "server_url"
fileprivate let continuously_track_key = "continuously_track"

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
    
    /// When true, it continuously calls the server to update the bone position.  When false, it just performs an initial tracking.  Should only be false for testing and eventually removed
    var continuouslyTrack: Bool {
        get {
            return _continuously_track
        }
        set {
            _continuously_track = newValue
            
            Settings.persistedSettings.set(_continuously_track, forKey: continuously_track_key)
        }
    }
    private var _continuously_track: Bool
    
    private init() {
        _serverUrl = Settings.persistedSettings.string(forKey: server_url_key) ?? "unnamed device"
        _continuously_track = Settings.persistedSettings.bool(forKey: continuously_track_key)
    }
    
    private static var persistedSettings: UserDefaults {
        return UserDefaults.standard
    }
}
