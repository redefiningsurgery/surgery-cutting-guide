import Foundation
import Combine

fileprivate let server_url_key = "server_url"
fileprivate let continuously_track_key = "continuously_track"
fileprivate let enable_dev_mode_key = "enable_dev_mode"

class Settings: ObservableObject {
    static let shared = Settings()
    /// Whether to ignore setting of UserDefaults when properties are set as well as updating properties when settings are changed in the Settings app
    private var ignoreChanges: Bool

    @Published var devServerUrl: String = "" {
        didSet {
            if !ignoreChanges {
                UserDefaults.standard.set(devServerUrl, forKey: server_url_key)
            }
        }
    }

    @Published var continuouslyTrack: Bool = false {
        didSet {
            if !ignoreChanges {
                UserDefaults.standard.set(continuouslyTrack, forKey: continuously_track_key)
            }
        }
    }

    @Published var enableDevMode: Bool = false {
        didSet {
            if !ignoreChanges {
                UserDefaults.standard.set(enableDevMode, forKey: enable_dev_mode_key)
            }
        }
    }

    private init() {
        ignoreChanges = true

        // Setup notification observer
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)

        setValues()
    }

    /// Occurs when user updates settings in the system Settings app
    @objc private func userDefaultsDidChange(notification: Notification) {
        guard !ignoreChanges else {
            return
        }
        setValues()
    }
    
    private func setValues() {
        ignoreChanges = true
        self.devServerUrl = UserDefaults.standard.string(forKey: server_url_key) ?? "http://default-url.com"
        self.continuouslyTrack = UserDefaults.standard.bool(forKey: continuously_track_key)
        self.enableDevMode = UserDefaults.standard.bool(forKey: enable_dev_mode_key)
        ignoreChanges = false
    }
    
    deinit {
        // Remove observer
        NotificationCenter.default.removeObserver(self)
    }
}
