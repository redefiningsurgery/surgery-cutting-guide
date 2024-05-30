import Foundation
import Combine

fileprivate let server_url_key = "server_url"
fileprivate let continuously_track_key = "continuously_track"

class Settings: ObservableObject {
    static let shared = Settings()

    @Published var devServerUrl: String {
        didSet {
            UserDefaults.standard.set(devServerUrl, forKey: server_url_key)
        }
    }

    @Published var continuouslyTrack: Bool {
        didSet {
            UserDefaults.standard.set(continuouslyTrack, forKey: continuously_track_key)
        }
    }
    
    private init() {
        devServerUrl = ""
        continuouslyTrack = false
        setValues()

        // Setup notification observer
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func userDefaultsDidChange(notification: Notification) {
        setValues()
    }
    
    private func setValues() {
        self.devServerUrl = UserDefaults.standard.string(forKey: server_url_key) ?? "http://default-url.com"
        self.continuouslyTrack = UserDefaults.standard.bool(forKey: continuously_track_key)
    }
    
    deinit {
        // Remove observer
        NotificationCenter.default.removeObserver(self)
    }
}
