import Foundation

public enum SafeGramSeverity: Int, Codable, Comparable, CaseIterable {
    case info = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    public static func < (lhs: SafeGramSeverity, rhs: SafeGramSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct SafeGramSecurityFinding: Codable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let severity: SafeGramSeverity
    public let kind: String
    public let title: String
    public let detail: String
    public let chatId: Int64?
    public let messageId: Int64?

    public init(id: UUID = UUID(), createdAt: Date = Date(), severity: SafeGramSeverity, kind: String, title: String, detail: String, chatId: Int64? = nil, messageId: Int64? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.severity = severity
        self.kind = kind
        self.title = title
        self.detail = detail
        self.chatId = chatId
        self.messageId = messageId
    }
}

public enum SafeGramMessageEventKind: String, Codable {
    case received
    case edited
    case deleted
}

public struct SafeGramMessageEvent: Codable, Equatable, Identifiable {
    public let id: UUID
    public let chatId: Int64
    public let messageId: Int64
    public let authorId: Int64?
    public let authorUsername: String?
    public let text: String
    public let timestamp: Date
    public let kind: SafeGramMessageEventKind
    public let replyToAuthorId: Int64?
    public let mentionedUserIds: [Int64]
    public let mediaNames: [String]

    public init(id: UUID = UUID(), chatId: Int64, messageId: Int64, authorId: Int64?, authorUsername: String?, text: String, timestamp: Date = Date(), kind: SafeGramMessageEventKind, replyToAuthorId: Int64? = nil, mentionedUserIds: [Int64] = [], mediaNames: [String] = []) {
        self.id = id
        self.chatId = chatId
        self.messageId = messageId
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.text = text
        self.timestamp = timestamp
        self.kind = kind
        self.replyToAuthorId = replyToAuthorId
        self.mentionedUserIds = mentionedUserIds
        self.mediaNames = mediaNames
    }
}

public struct SafeGramProfileSnapshot: Codable, Equatable, Identifiable {
    public let id: UUID
    public let peerId: Int64
    public let capturedAt: Date
    public let displayName: String
    public let username: String?
    public let bio: String?
    public let avatarId: String?

    public init(id: UUID = UUID(), peerId: Int64, capturedAt: Date = Date(), displayName: String, username: String?, bio: String?, avatarId: String? = nil) {
        self.id = id
        self.peerId = peerId
        self.capturedAt = capturedAt
        self.displayName = displayName
        self.username = username
        self.bio = bio
        self.avatarId = avatarId
    }
}

public struct SafeGramRelationshipEdge: Codable, Equatable, Hashable {
    public let sourceUserId: Int64
    public let targetUserId: Int64
    public var replies: Int
    public var mentions: Int
    public var lastSeen: Date

    public init(sourceUserId: Int64, targetUserId: Int64, replies: Int = 0, mentions: Int = 0, lastSeen: Date = Date()) {
        self.sourceUserId = sourceUserId
        self.targetUserId = targetUserId
        self.replies = replies
        self.mentions = mentions
        self.lastSeen = lastSeen
    }

    public var score: Int { replies * 3 + mentions * 2 }
}

public struct SafeGramStyleFingerprint: Codable, Equatable {
    public let sampleCount: Int
    public let averageLength: Double
    public let punctuationRatio: Double
    public let uppercaseRatio: Double
    public let emojiRatio: Double
    public let averageWords: Double

    public init(sampleCount: Int, averageLength: Double, punctuationRatio: Double, uppercaseRatio: Double, emojiRatio: Double, averageWords: Double) {
        self.sampleCount = sampleCount
        self.averageLength = averageLength
        self.punctuationRatio = punctuationRatio
        self.uppercaseRatio = uppercaseRatio
        self.emojiRatio = emojiRatio
        self.averageWords = averageWords
    }
}
