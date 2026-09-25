import Foundation

public final class SafeGramRelationshipRadar {
    public static let shared = SafeGramRelationshipRadar()
    private func store(_ accountId: Int64) -> SafeGramJSONStore<[SafeGramRelationshipEdge]> { SafeGramJSONStore(filename: "relationship-radar.json", accountId: accountId) }
    private let queue = DispatchQueue(label: "safegram.radar")

    private init() {}

    public func ingest(_ event: SafeGramMessageEvent, accountId: Int64) {
        guard SafeGramSettings.shared.relationshipRadarEnabled, event.kind == .received, let source = event.authorId else { return }
        queue.sync {
            let store = store(accountId)
            var edges = store.load(default: [])
            if let target = event.replyToAuthorId, target != source {
                update(&edges, source: source, target: target, reply: true)
            }
            for target in Set(event.mentionedUserIds) where target != source {
                update(&edges, source: source, target: target, reply: false)
            }
            store.save(edges)
        }
    }

    public func strongestConnections(accountId: Int64, for userId: Int64, limit: Int = 10) -> [SafeGramRelationshipEdge] {
        store(accountId).load(default: [])
            .filter { $0.sourceUserId == userId || $0.targetUserId == userId }
            .sorted { lhs, rhs in lhs.score == rhs.score ? lhs.lastSeen > rhs.lastSeen : lhs.score > rhs.score }
            .prefix(limit)
            .map { $0 }
    }

    private func update(_ edges: inout [SafeGramRelationshipEdge], source: Int64, target: Int64, reply: Bool) {
        if let i = edges.firstIndex(where: { $0.sourceUserId == source && $0.targetUserId == target }) {
            edges[i].lastSeen = Date()
            if reply { edges[i].replies += 1 } else { edges[i].mentions += 1 }
        } else {
            edges.append(SafeGramRelationshipEdge(sourceUserId: source, targetUserId: target, replies: reply ? 1 : 0, mentions: reply ? 0 : 1))
        }
    }
}

public final class SafeGramProfileTimeline {
    public static let shared = SafeGramProfileTimeline()
    private func store(_ accountId: Int64) -> SafeGramJSONStore<[SafeGramProfileSnapshot]> { SafeGramJSONStore(filename: "profile-timeline.json", accountId: accountId) }
    private let queue = DispatchQueue(label: "safegram.profile")
    private init() {}

    public func ingest(_ snapshot: SafeGramProfileSnapshot, accountId: Int64) {
        guard SafeGramSettings.shared.profileTimelineEnabled else { return }
        queue.sync {
            let store = store(accountId)
            var rows = store.load(default: [])
            let last = rows.last(where: { $0.peerId == snapshot.peerId })
            let resolved = SafeGramProfileSnapshot(peerId: snapshot.peerId, capturedAt: snapshot.capturedAt, displayName: snapshot.displayName, username: snapshot.username, bio: snapshot.bio ?? last?.bio, avatarId: snapshot.avatarId ?? last?.avatarId)
            if let last, last.displayName == resolved.displayName, last.username == resolved.username, last.bio == resolved.bio, last.avatarId == resolved.avatarId {
                return
            }
            rows.append(resolved)
            if rows.count > 20_000 { rows.removeFirst(rows.count - 20_000) }
            store.save(rows)
        }
    }

    public func ingestBio(accountId: Int64, peerId: Int64, bio: String?) {
        let last = history(accountId: accountId, peerId: peerId).first
        ingest(SafeGramProfileSnapshot(peerId: peerId, displayName: last?.displayName ?? "", username: last?.username, bio: bio ?? "", avatarId: last?.avatarId), accountId: accountId)
    }

    public func history(accountId: Int64, peerId: Int64) -> [SafeGramProfileSnapshot] {
        store(accountId).load(default: []).filter { $0.peerId == peerId }.sorted { $0.capturedAt > $1.capturedAt }
    }

    public func recent(accountId: Int64, limit: Int = 20) -> [SafeGramProfileSnapshot] {
        Array(store(accountId).load(default: []).sorted { $0.capturedAt > $1.capturedAt }.prefix(limit))
    }
}

public enum SafeGramFingerprintEngine {
    public static func fingerprint(texts: [String]) -> SafeGramStyleFingerprint {
        let samples = texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !samples.isEmpty else { return SafeGramStyleFingerprint(sampleCount: 0, averageLength: 0, punctuationRatio: 0, uppercaseRatio: 0, emojiRatio: 0, averageWords: 0) }
        var chars = 0, punctuation = 0, uppercase = 0, emoji = 0, words = 0
        for text in samples {
            chars += text.count
            words += text.split(whereSeparator: { $0.isWhitespace }).count
            for scalar in text.unicodeScalars {
                if CharacterSet.punctuationCharacters.contains(scalar) { punctuation += 1 }
                if CharacterSet.uppercaseLetters.contains(scalar) { uppercase += 1 }
                if scalar.properties.isEmojiPresentation { emoji += 1 }
            }
        }
        let d = Double(max(chars, 1))
        return SafeGramStyleFingerprint(sampleCount: samples.count, averageLength: Double(chars) / Double(samples.count), punctuationRatio: Double(punctuation) / d, uppercaseRatio: Double(uppercase) / d, emojiRatio: Double(emoji) / d, averageWords: Double(words) / Double(samples.count))
    }

    public static func anomalyScore(baseline: SafeGramStyleFingerprint, recent: SafeGramStyleFingerprint) -> Double {
        guard baseline.sampleCount >= 5, recent.sampleCount >= 2 else { return 0 }
        func delta(_ a: Double, _ b: Double, floor: Double) -> Double { min(abs(a - b) / max(abs(a), floor), 2.0) / 2.0 }
        let components = [delta(baseline.averageLength, recent.averageLength, floor: 8), delta(baseline.punctuationRatio, recent.punctuationRatio, floor: 0.03), delta(baseline.uppercaseRatio, recent.uppercaseRatio, floor: 0.03), delta(baseline.emojiRatio, recent.emojiRatio, floor: 0.02), delta(baseline.averageWords, recent.averageWords, floor: 3)]
        return components.reduce(0, +) / Double(components.count)
    }
}
