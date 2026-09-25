import Foundation

public final class SafeGramSettings {
    public static let shared = SafeGramSettings()

    private enum Key {
        static let enabled = "safegram.enabled"
        static let securityCenter = "safegram.securityCenter"
        static let relationshipRadar = "safegram.relationshipRadar"
        static let profileTimeline = "safegram.profileTimeline"
        static let forensics = "safegram.forensics"
        static let leakGuard = "safegram.leakGuard"
        static let fingerprint = "safegram.fingerprint"
        static let safeExit = "safegram.safeExit"
        static let faceID = "safegram.faceID"
        static let locked = "safegram.locked"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.securityCenter: true,
            Key.relationshipRadar: true,
            Key.profileTimeline: true,
            Key.forensics: true,
            Key.leakGuard: true,
            Key.fingerprint: true,
            Key.safeExit: true,
            Key.faceID: true,
            Key.locked: false
        ])
    }

    public var enabled: Bool { get { defaults.bool(forKey: Key.enabled) } set { defaults.set(newValue, forKey: Key.enabled) } }
    public var securityCenterEnabled: Bool { get { defaults.bool(forKey: Key.securityCenter) } set { defaults.set(newValue, forKey: Key.securityCenter) } }
    public var relationshipRadarEnabled: Bool { get { defaults.bool(forKey: Key.relationshipRadar) } set { defaults.set(newValue, forKey: Key.relationshipRadar) } }
    public var profileTimelineEnabled: Bool { get { defaults.bool(forKey: Key.profileTimeline) } set { defaults.set(newValue, forKey: Key.profileTimeline) } }
    public var forensicsEnabled: Bool { get { defaults.bool(forKey: Key.forensics) } set { defaults.set(newValue, forKey: Key.forensics) } }
    public var leakGuardEnabled: Bool { get { defaults.bool(forKey: Key.leakGuard) } set { defaults.set(newValue, forKey: Key.leakGuard) } }
    public var fingerprintEnabled: Bool { get { defaults.bool(forKey: Key.fingerprint) } set { defaults.set(newValue, forKey: Key.fingerprint) } }
    public var safeExitEnabled: Bool { get { defaults.bool(forKey: Key.safeExit) } set { defaults.set(newValue, forKey: Key.safeExit) } }
    public var faceIDEnabled: Bool { get { defaults.bool(forKey: Key.faceID) } set { defaults.set(newValue, forKey: Key.faceID) } }
    public var isLocallyLocked: Bool { get { defaults.bool(forKey: Key.locked) } set { defaults.set(newValue, forKey: Key.locked) } }
}
