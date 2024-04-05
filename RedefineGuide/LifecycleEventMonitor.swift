import Foundation
import UIKit

/// Allows the registration of callbacks for certain app lifecycle events, such as entering the background or coming back into the foreground.
class LifecycleEventMonitor {
    
    static let shared = LifecycleEventMonitor()
    
    private init() {
        registerForAppLifecycleNotifications()
    }
    
    private var willEnterForegroundCallbacks: [() -> Void] = []
    private var willTerminateCallbacks: [() -> Void] = []
    private var willEnterBackgroundCallbacks: [() -> Void] = []
    
    private func registerForAppLifecycleNotifications() {
        //NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        // occurs if This notification is sent when the app is about to become inactive. This occurs for temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    func registerWillEnterForegroundCallback(callback: @escaping () -> Void) {
        willEnterForegroundCallbacks.append(callback)
    }

    /// Call this when the app is about to become inactive or clsoes
    func registerWillEnterBackgroundCallback(callback: @escaping () -> Void) {
        willEnterBackgroundCallbacks.append(callback)
    }

    func registerWillTerminateCallback(callback: @escaping () -> Void) {
        willTerminateCallbacks.append(callback)
    }
    
    @objc private func appWillEnterForeground() {
        willEnterForegroundCallbacks.forEach { $0() }
    }
    
    @objc private func appWillTerminate() {
        willTerminateCallbacks.forEach { $0() }
    }

    @objc private func appWillEnterBackground() {
        willEnterBackgroundCallbacks.forEach { $0() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
