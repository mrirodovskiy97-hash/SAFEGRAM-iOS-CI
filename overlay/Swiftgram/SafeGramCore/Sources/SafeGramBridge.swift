import Foundation

public final class SafeGramEventBridge {
    public static let shared = SafeGramEventBridge()
    private init() {}

    public func messageReceived(accountId: Int64, chatId: Int64, messageId: Int64, authorId: Int64?, authorUsername: String?, text: String, date: Date, replyToAuthorId: Int64? = nil, mentionedUserIds: [Int64] = [], mediaNames: [String] = []) {
        ingest(SafeGramMessageEvent(chatId: chatId, messageId: messageId, authorId: authorId, authorUsername: authorUsername, text: text, timestamp: date, kind: .received, replyToAuthorId: replyToAuthorId, mentionedUserIds: mentionedUserIds, mediaNames: mediaNames), accountId: accountId)
    }

    public func messageEdited(accountId: Int64, chatId: Int64, messageId: Int64, authorId: Int64?, authorUsername: String?, text: String, date: Date, previousText: String? = nil) {
        if let previousText, SafeGramForensicsStore.shared.history(accountId: accountId, chatId: chatId, messageId: messageId).isEmpty {
            ingest(SafeGramMessageEvent(chatId: chatId, messageId: messageId, authorId: authorId, authorUsername: authorUsername, text: previousText, timestamp: date, kind: .received), accountId: accountId)
        }
        ingest(SafeGramMessageEvent(chatId: chatId, messageId: messageId, authorId: authorId, authorUsername: authorUsername, text: text, timestamp: date, kind: .edited), accountId: accountId)
    }

    public func messageDeleted(accountId: Int64, chatId: Int64, messageId: Int64, lastKnownText: String = "") {
        let previous = SafeGramForensicsStore.shared.history(accountId: accountId, chatId: chatId, messageId: messageId).last
        let text = lastKnownText.isEmpty ? (previous?.text ?? "") : lastKnownText
        ingest(SafeGramMessageEvent(chatId: chatId, messageId: messageId, authorId: previous?.authorId, authorUsername: previous?.authorUsername, text: text, timestamp: Date(), kind: .deleted), accountId: accountId)
    }

    public func profileObserved(accountId: Int64, peerId: Int64, displayName: String, username: String?, bio: String?, avatarId: String?) {
        guard SafeGramSettings.shared.enabled else { return }
        SafeGramProfileTimeline.shared.ingest(SafeGramProfileSnapshot(peerId: peerId, displayName: displayName, username: username, bio: bio, avatarId: avatarId), accountId: accountId)
    }

    public func profileBioObserved(accountId: Int64, peerId: Int64, bio: String?) {
        guard SafeGramSettings.shared.enabled else { return }
        SafeGramProfileTimeline.shared.ingestBio(accountId: accountId, peerId: peerId, bio: bio)
    }

    private func ingest(_ event: SafeGramMessageEvent, accountId: Int64) {
        guard SafeGramSettings.shared.enabled else { return }
        if SafeGramForensicsStore.shared.containsEquivalent(event, accountId: accountId) { return }
        SafeGramForensicsStore.shared.ingest(event, accountId: accountId)
        SafeGramRelationshipRadar.shared.ingest(event, accountId: accountId)
        SafeGramIdentityMonitor.shared.ingest(event, accountId: accountId)
        SafeGramCanaryStore.shared.inspect(event, accountId: accountId)
    }
}
