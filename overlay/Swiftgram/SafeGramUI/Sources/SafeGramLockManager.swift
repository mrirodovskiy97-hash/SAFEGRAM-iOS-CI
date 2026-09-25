import Foundation
import LocalAuthentication
import SafeGramCore

public enum SafeGramUnlockResult {
    case unlocked
    case unavailable
    case failed(Error?)
}

public final class SafeGramLockManager {
    public static let shared = SafeGramLockManager()
    private init() {}

    /// Safe Exit is a local app lock only. It deliberately does NOT call Telegram logout,
    /// export auth keys, clone sessions, or suppress Telegram security notifications.
    public func safeExit() {
        guard SafeGramSettings.shared.safeExitEnabled else { return }
        SafeGramSettings.shared.isLocallyLocked = true
        NotificationCenter.default.post(name: .safeGramLockStateChanged, object: nil)
    }

    public func unlock(reason: String = "Unlock SAFEGRAM", completion: @escaping (SafeGramUnlockResult) -> Void) {
        guard SafeGramSettings.shared.isLocallyLocked else { completion(.unlocked); return }
        // Device passcode remains required even when biometric preference is off.
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.unavailable)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
            DispatchQueue.main.async {
                if success {
                    SafeGramSettings.shared.isLocallyLocked = false
                    NotificationCenter.default.post(name: .safeGramLockStateChanged, object: nil)
                    completion(.unlocked)
                } else {
                    completion(.failed(evalError))
                }
            }
        }
    }
}

public extension Notification.Name {
    static let safeGramLockStateChanged = Notification.Name("SafeGramLockStateChanged")
}
