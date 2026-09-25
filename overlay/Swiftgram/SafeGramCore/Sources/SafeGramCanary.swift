import Foundation

public struct SafeGramCanary: Codable, Equatable, Identifiable {
    public let id: UUID
    public let marker: String
    public let label: String
    public let createdAt: Date

    public init(id: UUID = UUID(), marker: String, label: String, createdAt: Date = Date()) {
        self.id = id
        self.marker = marker
        self.label = label
        self.createdAt = createdAt
    }
}

public final class SafeGramCanaryStore {
    public static let shared = SafeGramCanaryStore()
    private func store(_ accountId: Int64) -> SafeGramJSONStore<[SafeGramCanary]> { SafeGramJSONStore(filename: "canaries.json", accountId: accountId) }
    private let queue = DispatchQueue(label: "safegram.canary")
    private init() {}

    @discardableResult
    public func create(accountId: Int64, label: String) -> SafeGramCanary {
        let compact = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        let canary = SafeGramCanary(marker: "SGCANARY-\(compact)", label: label)
        queue.sync {
            let store = store(accountId)
            var values = store.load(default: [])
            values.append(canary)
            store.save(values)
        }
        return canary
    }

    public func all(accountId: Int64) -> [SafeGramCanary] { store(accountId).load(default: []).sorted { $0.createdAt > $1.createdAt } }

    public func inspect(_ event: SafeGramMessageEvent, accountId: Int64) {
        let text = event.text
        guard !text.isEmpty else { return }
        let hits = store(accountId).load(default: []).filter { text.contains($0.marker) }
        for hit in hits {
            SafeGramForensicsStore.shared.recordFinding(
                SafeGramSecurityFinding(
                    severity: .medium,
                    kind: "canary_seen",
                    title: "Canary marker seen",
                    detail: "Marker \(hit.label) appeared in a message visible to this account.",
                    chatId: event.chatId,
                    messageId: event.messageId
                ), accountId: accountId
            )
        }
    }
}
