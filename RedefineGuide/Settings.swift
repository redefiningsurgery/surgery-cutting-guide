import Foundation
import Combine

fileprivate let server_url_key = "server_url"
fileprivate let continuously_track_key = "continuously_track"
fileprivate let show_axis_editor_key = "show_axis_editor"

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

    @Published var showAxisEditor: Bool {
        didSet {
            UserDefaults.standard.set(showAxisEditor, forKey: show_axis_editor_key)
        }
    }
        
    private init() {
        devServerUrl = ""
        continuouslyTrack = false
        showAxisEditor = false
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
        self.showAxisEditor = UserDefaults.standard.bool(forKey: show_axis_editor_key)
    }
    
    deinit {
        // Remove observer
        NotificationCenter.default.removeObserver(self)
    }
}
