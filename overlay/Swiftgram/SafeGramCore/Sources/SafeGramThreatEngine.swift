import Foundation

public final class SafeGramThreatEngine {
    public static let shared = SafeGramThreatEngine()
    private init() {}

    private let sensitivePatterns: [(kind: String, title: String, regex: String, severity: SafeGramSeverity)] = [
        ("private_key", "Private key marker", #"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#, .critical),
        ("seed_phrase", "Possible seed phrase", #"(?i)\b(?:seed|mnemonic|recovery phrase)\b.{0,40}\b(?:[a-z]{3,}\s+){7,23}[a-z]{3,}\b"#, .critical),
        ("api_key", "Possible API key", #"(?i)\b(?:api[_ -]?key|token|secret)\b\s*[:=]\s*[A-Za-z0-9_\-]{16,}"#, .high),
        ("telegram_bot_token", "Telegram bot token", #"\b\d{6,12}:[A-Za-z0-9_-]{25,}\b"#, .high),
        ("password", "Password-like value", #"(?i)\b(?:password|passwd|пароль)\b\s*[:=]\s*\S{6,}"#, .high)
    ]

    public func scan(text: String, chatId: Int64? = nil, messageId: Int64? = nil) -> [SafeGramSecurityFinding] {
        guard !text.isEmpty else { return [] }
        var findings: [SafeGramSecurityFinding] = []

        for pattern in sensitivePatterns {
            if matches(pattern.regex, in: text) {
                findings.append(SafeGramSecurityFinding(severity: pattern.severity, kind: pattern.kind, title: pattern.title, detail: "Sensitive value detected. Review before forwarding or exporting.", chatId: chatId, messageId: messageId))
            }
        }

        for raw in extractURLs(from: text) {
            findings.append(contentsOf: inspectURL(raw, chatId: chatId, messageId: messageId))
        }
        return findings
    }

    public func inspectURL(_ raw: String, chatId: Int64? = nil, messageId: Int64? = nil) -> [SafeGramSecurityFinding] {
        guard let url = URL(string: raw), let host = url.host?.lowercased() else { return [] }
        var result: [SafeGramSecurityFinding] = []

        if host.contains("xn--") {
            result.append(SafeGramSecurityFinding(severity: .high, kind: "punycode", title: "Punycode domain", detail: host, chatId: chatId, messageId: messageId))
        }
        if isRawIPAddress(host) {
            result.append(SafeGramSecurityFinding(severity: .medium, kind: "raw_ip", title: "Link uses raw IP", detail: host, chatId: chatId, messageId: messageId))
        }
        if url.scheme?.lowercased() == "http" {
            result.append(SafeGramSecurityFinding(severity: .medium, kind: "http", title: "Unencrypted HTTP link", detail: host, chatId: chatId, messageId: messageId))
        }
        if host.split(separator: ".").count >= 5 {
            result.append(SafeGramSecurityFinding(severity: .low, kind: "deep_subdomain", title: "Unusually deep subdomain", detail: host, chatId: chatId, messageId: messageId))
        }
        return result
    }

    private func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private func extractURLs(from text: String) -> [String] {
        let pattern = #"(?i)\bhttps?://[^\s<>()\[\]{}\"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
        }
    }

    private func isRawIPAddress(_ host: String) -> Bool {
        let ipv4 = #"^(?:\d{1,3}\.){3}\d{1,3}$"#
        return matches(ipv4, in: host) || host.contains(":")
    }
}
