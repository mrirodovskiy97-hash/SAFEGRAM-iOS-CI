import Foundation

private struct SafeGramIdentitySample: Codable {
    var peerId: Int64
    var texts: [String]
    var lastAlertAt: Date?
}

public final class SafeGramIdentityMonitor {
    public static let shared = SafeGramIdentityMonitor()
    private func store(_ accountId: Int64) -> SafeGramJSONStore<[SafeGramIdentitySample]> { SafeGramJSONStore(filename: "identity-samples.json", accountId: accountId) }
    private let queue = DispatchQueue(label: "safegram.identity")
    private init() {}

    public func ingest(_ event: SafeGramMessageEvent, accountId: Int64) {
        guard SafeGramSettings.shared.fingerprintEnabled,
              event.kind != .deleted,
              let peerId = event.authorId else { return }
        let text = event.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        queue.sync {
            let store = store(accountId)
            var rows = store.load(default: [])
            var row = rows.first(where: { $0.peerId == peerId }) ?? SafeGramIdentitySample(peerId: peerId, texts: [], lastAlertAt: nil)
            row.texts.append(text)
            if row.texts.count > 200 { row.texts.removeFirst(row.texts.count - 200) }

            if row.texts.count >= 12 {
                let recentCount = min(5, max(2, row.texts.count / 4))
                let split = row.texts.count - recentCount
                let baseline = SafeGramFingerprintEngine.fingerprint(texts: Array(row.texts[..<split]))
                let recent = SafeGramFingerprintEngine.fingerprint(texts: Array(row.texts[split...]))
                let score = SafeGramFingerprintEngine.anomalyScore(baseline: baseline, recent: recent)
                let cooldownPassed = row.lastAlertAt.map { Date().timeIntervalSince($0) > 6 * 3600 } ?? true
                if score >= 0.58 && cooldownPassed {
                    SafeGramForensicsStore.shared.recordFinding(
                        SafeGramSecurityFinding(
                            severity: score >= 0.75 ? .high : .medium,
                            kind: "identity_style_shift",
                            title: "Writing style changed",
                            detail: "Visible message style changed significantly (score \(String(format: "%.2f", score))). This is only a heuristic, not proof of account compromise.",
                            chatId: event.chatId,
                            messageId: event.messageId
                        ), accountId: accountId
                    )
                    row.lastAlertAt = Date()
                }
            }

            if let index = rows.firstIndex(where: { $0.peerId == peerId }) { rows[index] = row } else { rows.append(row) }
            store.save(rows)
        }
    }
}
