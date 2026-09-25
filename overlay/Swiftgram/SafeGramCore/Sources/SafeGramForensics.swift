import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(CommonCrypto)
import CommonCrypto
#endif

public struct SafeGramEvidenceBundle: Codable {
    public let exportedAt: Date
    public let accountId: Int64
    public let chatId: Int64?
    public let events: [SafeGramMessageEvent]
}

public final class SafeGramForensicsStore {
    public static let shared = SafeGramForensicsStore()
    private func store(_ accountId: Int64) -> SafeGramJSONStore<[SafeGramMessageEvent]> { SafeGramJSONStore(filename: "forensics-events.json", accountId: accountId) }
    private func alerts(_ accountId: Int64) -> SafeGramJSONStore<[SafeGramSecurityFinding]> { SafeGramJSONStore(filename: "security-findings.json", accountId: accountId) }
    private let queue = DispatchQueue(label: "safegram.forensics")
    private init() {}

    public func ingest(_ event: SafeGramMessageEvent, accountId: Int64) {
        guard SafeGramSettings.shared.forensicsEnabled else { return }
        queue.sync {
            let store = store(accountId)
            let alerts = alerts(accountId)
            var events = store.load(default: [])
            if let previous = events.last(where: { $0.chatId == event.chatId && $0.messageId == event.messageId }) {
                if previous.kind == event.kind && previous.text == event.text { return }
            }
            events.append(event)
            if events.count > 50_000 { events.removeFirst(events.count - 50_000) }
            store.save(events)

            if SafeGramSettings.shared.leakGuardEnabled {
                let newAlerts = SafeGramThreatEngine.shared.scan(text: event.text, chatId: event.chatId, messageId: event.messageId)
                if !newAlerts.isEmpty {
                    var all = alerts.load(default: [])
                    all.append(contentsOf: newAlerts)
                    if all.count > 10_000 { all.removeFirst(all.count - 10_000) }
                    alerts.save(all)
                }
            }
        }
    }

    public func history(accountId: Int64, chatId: Int64? = nil, messageId: Int64? = nil) -> [SafeGramMessageEvent] {
        store(accountId).load(default: []).filter { event in
            if let chatId, event.chatId != chatId { return false }
            if let messageId { return event.messageId == messageId }
            return true
        }.sorted { $0.timestamp < $1.timestamp }
    }

    public func containsEquivalent(_ event: SafeGramMessageEvent, accountId: Int64) -> Bool {
        guard let last = store(accountId).load(default: []).last(where: { $0.chatId == event.chatId && $0.messageId == event.messageId }) else { return false }
        return last.kind == event.kind && last.text == event.text
    }

    public func findings(accountId: Int64, limit: Int = 200) -> [SafeGramSecurityFinding] {
        alerts(accountId).load(default: []).sorted { $0.createdAt > $1.createdAt }.prefix(limit).map { $0 }
    }

    public func recordFinding(_ finding: SafeGramSecurityFinding, accountId: Int64) {
        queue.sync {
            let alerts = alerts(accountId)
            var all = alerts.load(default: [])
            if all.contains(where: { $0.kind == finding.kind && $0.chatId == finding.chatId && $0.messageId == finding.messageId && $0.detail == finding.detail }) { return }
            all.append(finding)
            if all.count > 10_000 { all.removeFirst(all.count - 10_000) }
            alerts.save(all)
        }
    }

    public func eventCount(accountId: Int64) -> Int {
        store(accountId).load(default: []).count
    }

    public func findingCount(accountId: Int64) -> Int {
        alerts(accountId).load(default: []).count
    }

    public func export(accountId: Int64, chatId: Int64? = nil, destination: URL) throws -> (url: URL, sha256: String) {
        let bundle = SafeGramEvidenceBundle(exportedAt: Date(), accountId: accountId, chatId: chatId, events: history(accountId: accountId, chatId: chatId))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        let digest = try sha256(data)
        try data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])
        return (destination, digest)
    }

    private func sha256(_ data: Data) throws -> String {
        #if canImport(CryptoKit)
        if #available(iOS 13.0, macOS 10.15, *) {
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        #endif
        #if canImport(CommonCrypto)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        throw SafeGramStorageError.invalidData
        #endif
    }
}
