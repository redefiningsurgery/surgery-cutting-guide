import Foundation
import Combine

fileprivate let default_server_url = "http://1.1.1.1"

fileprivate let server_url_key = "server_url"
fileprivate let enable_dev_mode_key = "enable_dev_mode"
fileprivate let continuously_track_key = "continuously_track"
fileprivate let save_requests_key = "save_requests"
fileprivate let ar_debugging_key = "ar_debugging"
fileprivate let camera_align_key = "camera_align"
fileprivate let enable_axes_key = "enable_axes"

class Settings: ObservableObject {
    static let shared = Settings()
    /// Whether to ignore setting of UserDefaults when properties are set as well as updating properties when settings are changed in the Settings app
    private var ignoreChanges: Bool

    @Published var devServerUrl: String = default_server_url {
        didSet {
            if !ignoreChanges {
                print("Setting UserDefaults \(server_url_key)")
                UserDefaults.standard.set(devServerUrl, forKey: server_url_key)
            }
        }
    }
    
    var isServerUrlSet: Bool {
        get {
            return !devServerUrl.isEmpty && devServerUrl != default_server_url
        }
    }

    @Published var enableDevMode: Bool = false {
        didSet {
            if !ignoreChanges {
                print("Setting UserDefaults \(enable_dev_mode_key)")
                UserDefaults.standard.set(enableDevMode, forKey: enable_dev_mode_key)
            }
        }
    }

    @Published var continuouslyTrack: Bool = false {
        didSet {
            if !ignoreChanges {
                print("Setting UserDefaults \(continuously_track_key)")
                UserDefaults.standard.set(continuouslyTrack, forKey: continuously_track_key)
            }
        }
    }

    @Published var saveRequests: Bool = false {
        didSet {
            if !ignoreChanges {
                print("Setting UserDefaults \(save_requests_key)")
                UserDefaults.standard.set(saveRequests, forKey: save_requests_key)
            }
        }
    }

    @Published var showARDebugging: Bool = false {
        didSet {
            if !ignoreChanges {
                print("Setting UserDefaults \(ar_debugging_key)")
                UserDefaults.standard.set(showARDebugging, forKey: ar_debugging_key)
            }
        }
    }

    @Published var enableAxes: Bool = false {
        didSet {
            if !ignoreChanges {
                print("Setting UserDefaults \(enable_axes_key)")
                UserDefaults.standard.set(enableAxes, forKey: enable_axes_key)
            }
        }
    }

    @Published var alignOverlayWithCamera: Bool = false {
        didSet {
            if !ignoreChanges {
                print("Setting UserDefaults \(camera_align_key)")
                UserDefaults.standard.set(alignOverlayWithCamera, forKey: camera_align_key)
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
        
        if let newValue = UserDefaults.standard.string(forKey: server_url_key), newValue != devServerUrl {
            self.devServerUrl = newValue
        }
        var newValue = UserDefaults.standard.bool(forKey: enable_dev_mode_key)
        if newValue != enableDevMode {
            self.enableDevMode = newValue
        }
        newValue = UserDefaults.standard.bool(forKey: continuously_track_key)
        if newValue != continuouslyTrack {
            self.continuouslyTrack = newValue
        }
        newValue = UserDefaults.standard.bool(forKey: save_requests_key)
        if newValue != saveRequests {
            self.saveRequests = newValue
        }
        newValue = UserDefaults.standard.bool(forKey: ar_debugging_key)
        if newValue != showARDebugging {
            self.showARDebugging = newValue
        }
        newValue = UserDefaults.standard.bool(forKey: enable_axes_key)
        if newValue != enableAxes {
            self.enableAxes = newValue
        }
        newValue = UserDefaults.standard.bool(forKey: camera_align_key)
        if newValue != alignOverlayWithCamera {
            self.alignOverlayWithCamera = newValue
        }

        ignoreChanges = false
    }
    
    deinit {
        // Remove observer
        NotificationCenter.default.removeObserver(self)
    }
}
