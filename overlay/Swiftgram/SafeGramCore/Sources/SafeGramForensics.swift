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
        let retainMessageHistory = SafeGramSettings.shared.forensicsEnabled
        let inspectForThreats = SafeGramSettings.shared.leakGuardEnabled
        guard retainMessageHistory || inspectForThreats else { return }

        queue.sync {
            // Store message text only after the user has explicitly opted in.
            // Disabling message history must not silently disable link and
            // secret-pattern warnings.
            if retainMessageHistory {
                let store = store(accountId)
                var events = store.load(default: [])
                if let previous = events.last(where: { $0.chatId == event.chatId && $0.messageId == event.messageId }),
                   previous.kind == event.kind && previous.text == event.text {
                    // A replayed event may still need scanning if the warning
                    // switch was turned on since its first delivery.
                } else {
                    events.append(event)
                    if events.count > 50_000 { events.removeFirst(events.count - 50_000) }
                    store.save(events)
                }
            }

            if inspectForThreats {
                let newAlerts = SafeGramThreatEngine.shared.scan(text: event.text, chatId: event.chatId, messageId: event.messageId)
                guard !newAlerts.isEmpty else { return }
                let alerts = alerts(accountId)
                var all = alerts.load(default: [])
                for finding in newAlerts {
                    // The bridge may receive the same message repeatedly after
                    // reconnect; avoid multiplying identical warning cards.
                    if !all.contains(where: {
                        $0.kind == finding.kind &&
                        $0.chatId == finding.chatId &&
                        $0.messageId == finding.messageId &&
                        $0.detail == finding.detail
                    }) {
                        all.append(finding)
                    }
                }
                if all.count > 10_000 { all.removeFirst(all.count - 10_000) }
                alerts.save(all)
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

    /// Account-scoped deletion. Does not delete chat messages in Telegram.
    public func clearHistory(accountId: Int64) throws {
        try queue.sync {
            try store(accountId).clear()
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
