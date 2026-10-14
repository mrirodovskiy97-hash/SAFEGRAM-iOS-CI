import Foundation

// Standalone macOS Swift smoke. No Telegram credentials or network access.
func verify(_ ok: @autoclosure () -> Bool, _ message: String) {
    if !ok() {
        fputs("SAFEGRAM PRIVACY SMOKE FAILED: \(message)\n", stderr)
        exit(1)
    }
}

let settings = SafeGramSettings.shared
verify(settings.enabled, "feature master switch")
verify(!settings.forensicsEnabled, "plaintext history disabled by default")
verify(!settings.relationshipRadarEnabled, "relationship tracking disabled by default")
verify(!settings.profileTimelineEnabled, "profile tracking disabled by default")
verify(!settings.fingerprintEnabled, "writing samples disabled by default")
verify(settings.leakGuardEnabled, "link warnings enabled by default")

let accountId = Int64.random(in: 500_000_000 ... 900_000_000)
let first = SafeGramMessageEvent(
    chatId: 111, messageId: 1, authorId: 42,
    authorUsername: "example", text: "Test HTTP URL http://192.0.2.1/page",
    kind: .received
)
let store = SafeGramForensicsStore.shared
store.ingest(first, accountId: accountId)
verify(store.eventCount(accountId: accountId) == 0, "warnings should not save message text")
let count = store.findingCount(accountId: accountId)
verify(count >= 2, "warnings should work without message-history storage")
store.ingest(first, accountId: accountId)
verify(store.findingCount(accountId: accountId) == count, "no duplicate warnings for retries")

settings.forensicsEnabled = true
let second = SafeGramMessageEvent(
    chatId: 111, messageId: 2, authorId: 42,
    authorUsername: nil, text: "opt-in history", kind: .received
)
store.ingest(second, accountId: accountId)
verify(store.eventCount(accountId: accountId) == 1, "opt-in history saves messages")
let historyFile = SafeGramJSONStore<[SafeGramMessageEvent]>(filename: "forensics-events.json", accountId: accountId).fileURL
verify(FileManager.default.fileExists(atPath: historyFile.path), "local history file exists")
try store.clearHistory(accountId: accountId)
settings.forensicsEnabled = false
verify(store.eventCount(accountId: accountId) == 0, "history deleted")
verify(!FileManager.default.fileExists(atPath: historyFile.path), "history file removed")
verify(store.findingCount(accountId: accountId) == count, "warnings survive history deletion")
let findingsFile = SafeGramJSONStore<[SafeGramSecurityFinding]>(filename: "security-findings.json", accountId: accountId)
try findingsFile.clear()
print("SAFEGRAM PRIVACY SMOKE PASS")
