import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SafeGramCore

private final class SafeGramToggleTarget: NSObject {
    let change: (Bool) -> Void
    init(_ change: @escaping (Bool) -> Void) { self.change = change }
    @objc func changed(_ sender: UISwitch) { change(sender.isOn) }
}

private final class SafeGramSecurityCenterNode: ASDisplayNode {
    let accountId: Int64
    var onExport: (() -> Void)?
    var onLegacyImport: (() -> Void)?
    var onCreateCanary: (() -> Void)?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var targets: [SafeGramToggleTarget] = []

    init(accountId: Int64) {
        self.accountId = accountId
        super.init()
        backgroundColor = .systemGroupedBackground
    }

    override func didLoad() {
        super.didLoad()
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 18, bottom: 30, right: 18)
        stack.isLayoutMarginsRelativeArrangement = true
        scroll.addSubview(stack)
        refresh()
    }

    private func label(_ title: String, size: CGFloat = 16) -> UILabel {
        let result = UILabel()
        result.text = title
        result.font = .systemFont(ofSize: size)
        result.textColor = .label
        result.numberOfLines = 0
        return result
    }

    private func toggle(_ title: String, value: Bool, change: @escaping (Bool) -> Void) {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        let caption = label(title)
        let control = UISwitch()
        control.isOn = value
        let target = SafeGramToggleTarget(change)
        targets.append(target)
        control.addTarget(target, action: #selector(SafeGramToggleTarget.changed(_:)), for: .valueChanged)
        row.addArrangedSubview(caption)
        row.addArrangedSubview(control)
        stack.addArrangedSubview(row)
    }

    func refresh() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        targets.removeAll()
        stack.addArrangedSubview(label("SAFEGRAM Security Center", size: 22))
        stack.addArrangedSubview(label("Saved events: \(SafeGramForensicsStore.shared.eventCount(accountId: accountId)) · Findings: \(SafeGramForensicsStore.shared.findingCount(accountId: accountId))"))
        let settings = SafeGramSettings.shared
        toggle("SAFEGRAM enabled", value: settings.enabled) { settings.enabled = $0 }
        toggle("Message Forensics", value: settings.forensicsEnabled) { settings.forensicsEnabled = $0 }
        toggle("Relationship Radar", value: settings.relationshipRadarEnabled) { settings.relationshipRadarEnabled = $0 }
        toggle("Profile Time Machine", value: settings.profileTimelineEnabled) { settings.profileTimelineEnabled = $0 }
        toggle("Leak Guard and URL checks", value: settings.leakGuardEnabled) { settings.leakGuardEnabled = $0 }
        toggle("Identity Fingerprint", value: settings.fingerprintEnabled) { settings.fingerprintEnabled = $0 }
        toggle("Safe Exit", value: settings.safeExitEnabled) { settings.safeExitEnabled = $0 }
        stack.addArrangedSubview(label("Unlock uses Face ID or the device code when available.", size: 13))

        let button = UIButton(type: .system)
        button.setTitle("Safe Exit · Lock app", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(safeExit), for: .touchUpInside)
        stack.addArrangedSubview(button)
        let exportButton = UIButton(type: .system)
        exportButton.setTitle("Export Evidence Vault JSON", for: .normal)
        exportButton.addTarget(self, action: #selector(exportEvidence), for: .touchUpInside)
        stack.addArrangedSubview(exportButton)
        let migrateButton = UIButton(type: .system)
        migrateButton.setTitle("Import older SAFEGRAM data…", for: .normal)
        migrateButton.addTarget(self, action: #selector(importLegacy), for: .touchUpInside)
        stack.addArrangedSubview(migrateButton)
        let canaryButton = UIButton(type: .system)
        canaryButton.setTitle("Create Canary marker", for: .normal)
        canaryButton.addTarget(self, action: #selector(createCanary), for: .touchUpInside)
        stack.addArrangedSubview(canaryButton)
        stack.addArrangedSubview(label("Recent findings", size: 20))
        let findings = SafeGramForensicsStore.shared.findings(accountId: accountId, limit: 20)
        if findings.isEmpty { stack.addArrangedSubview(label("No findings yet.")) }
        for finding in findings {
            stack.addArrangedSubview(label("[\(finding.severity)] \(finding.title): \(finding.detail)", size: 14))
        }
        stack.addArrangedSubview(label("Recent message history", size: 20))
        for event in SafeGramForensicsStore.shared.history(accountId: accountId).suffix(20).reversed() {
            stack.addArrangedSubview(label("\(event.kind.rawValue) · chat \(event.chatId) / \(event.messageId): \(String(event.text.prefix(140)))", size: 14))
        }
        stack.addArrangedSubview(label("Profile Time Machine", size: 20))
        for profile in SafeGramProfileTimeline.shared.recent(accountId: accountId) {
            stack.addArrangedSubview(label("\(profile.peerId) · \(profile.displayName) · @\(profile.username ?? "—") · bio: \(profile.bio ?? "—") · avatar: \(profile.avatarId ?? "—")", size: 14))
        }
        setNeedsLayout()
    }

    @objc private func safeExit() { SafeGramLockManager.shared.safeExit() }
    @objc private func exportEvidence() { onExport?() }
    @objc private func importLegacy() { onLegacyImport?() }
    @objc private func createCanary() { onCreateCanary?() }

    override func layout() {
        super.layout()
        scroll.frame = bounds
        let width = bounds.width
        let height = stack.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        stack.frame = CGRect(x: 0, y: 0, width: width, height: height)
        scroll.contentSize = stack.bounds.size
    }
}

public final class SafeGramSecurityCenterController: ViewController {
    private let accountId: Int64
    public init(accountId: Int64) {
        self.accountId = accountId
        super.init(navigationBarPresentationData: nil)
        self.title = "SAFEGRAM"
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadDisplayNode() {
        let node = SafeGramSecurityCenterNode(accountId: accountId)
        node.onExport = { [weak self] in self?.shareEvidence() }
        node.onLegacyImport = { [weak self, weak node] in
            guard let self else { return }
            let alert = UIAlertController(title: "Import older data?", message: "Older SAFEGRAM files do not identify their Telegram account. Import only if they belong to this account. Existing account files will be kept.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { [weak self, weak node] _ in
                guard let self else { return }
                do {
                    let count = try SafeGramLegacyMigration.copyToAccount(self.accountId)
                    node?.refresh()
                    self.showResult("Imported \(count) files. Originals remain available for rollback.")
                } catch { self.showResult(error.localizedDescription) }
            }))
            self.present(alert, animated: true)
        }
        node.onCreateCanary = { [weak self] in
            guard let self else { return }
            let marker = SafeGramCanaryStore.shared.create(accountId: self.accountId, label: "Personal marker")
            UIPasteboard.general.string = marker.marker
            self.showResult("Marker copied: \(marker.marker)")
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    private func shareEvidence() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SAFEGRAM-evidence-\(accountId)-\(UUID().uuidString).json")
        do {
            let result = try SafeGramForensicsStore.shared.export(accountId: accountId, destination: url)
            let controller = UIActivityViewController(activityItems: [result.url, "SHA-256: \(result.sha256)"], applicationActivities: nil)
            controller.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url) }
            if let popover = controller.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
            }
            self.present(controller, animated: true)
        } catch {
            showResult(error.localizedDescription)
        }
    }

    private func showResult(_ message: String) {
        let alert = UIAlertController(title: "SAFEGRAM", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}

public func safeGramSecurityCenterController(accountId: Int64) -> ViewController {
    SafeGramSecurityCenterController(accountId: accountId)
}
