import UIKit
import SafeGramCore

/// Local privacy cover for Safe Exit.
/// This protects the on-device UI only and never changes Telegram authorization state.
public final class SafeGramPrivacyCover: NSObject {
    public static let shared = SafeGramPrivacyCover()

    private weak var window: UIWindow?
    private var cover: UIView?
    private var snapshotCover: UIView?
    private var unlockInProgress = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: .safeGramLockStateChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(coverSnapshot), name: UIApplication.willResignActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Attach once the host application's main window exists.
    public func attach(to window: UIWindow) {
        self.window = window
        update()
    }

    /// Re-evaluates the privacy cover. Safe to call from scene/app lifecycle hooks.
    @objc public func update() {
        guard let window else { return }
        if SafeGramSettings.shared.isLocallyLocked {
            showCover(in: window)
        } else {
            cover?.removeFromSuperview()
            cover = nil
            unlockInProgress = false
        }
        snapshotCover?.removeFromSuperview()
        snapshotCover = nil
    }

    @objc private func coverSnapshot() {
        guard let window, snapshotCover == nil else { return }
        let view = UIView(frame: window.bounds)
        view.backgroundColor = .systemBackground
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        snapshotCover = view
    }

    private func showCover(in window: UIWindow) {
        if let cover {
            window.bringSubviewToFront(cover)
            return
        }

        let shield = UIView(frame: window.bounds)
        shield.backgroundColor = .systemBackground
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.isUserInteractionEnabled = true
        shield.accessibilityViewIsModal = true
        shield.accessibilityLabel = "SAFEGRAM locked"

        let label = UILabel(frame: shield.bounds.insetBy(dx: 24, dy: 24))
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.text = "SAFEGRAM\nLocked\n\nTap to unlock"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        shield.addSubview(label)

        let tap = UITapGestureRecognizer(target: self, action: #selector(requestUnlock))
        shield.addGestureRecognizer(tap)

        window.addSubview(shield)
        window.bringSubviewToFront(shield)
        cover = shield
    }

    @objc private func requestUnlock() {
        guard !unlockInProgress else { return }
        unlockInProgress = true
        SafeGramLockManager.shared.unlock(reason: "Unlock SAFEGRAM") { [weak self] _ in
            guard let self else { return }
            self.unlockInProgress = false
            self.update()
        }
    }
}
