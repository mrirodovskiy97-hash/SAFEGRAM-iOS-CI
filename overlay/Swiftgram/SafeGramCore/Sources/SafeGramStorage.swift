import Foundation

public enum SafeGramStorageError: Error {
    case unableToCreateDirectory
    case invalidData
}

public final class SafeGramJSONStore<Element: Codable> {
    private let url: URL
    private let queue = DispatchQueue(label: "safegram.store", qos: .utility)

    public init(filename: String, accountId: Int64, baseDirectory: URL? = nil) {
        let fm = FileManager.default
        let base = baseDirectory ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("SafeGram", isDirectory: true)
            .appendingPathComponent("account-\(accountId)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(filename)
    }

    public func load(default defaultValue: Element) -> Element {
        queue.sync {
            guard let data = try? Data(contentsOf: url) else { return defaultValue }
            return (try? JSONDecoder.safeGram.decode(Element.self, from: data)) ?? defaultValue
        }
    }

    public func save(_ value: Element) {
        queue.sync {
            guard let data = try? JSONEncoder.safeGram.encode(value) else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                guard let previous = try? Data(contentsOf: url) else { return }
                if (try? JSONDecoder.safeGram.decode(Element.self, from: previous)) == nil {
                let backup = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
                guard (try? FileManager.default.moveItem(at: url, to: backup)) != nil else { return }
                }
            }
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        }
    }

    public var fileURL: URL { url }
}

/// Previous overlays stored one unscoped set of files. Migration must be an
/// explicit choice because those files do not contain the owning Telegram ID.
public enum SafeGramLegacyMigration {
    public static func copyToAccount(_ accountId: Int64, baseDirectory: URL? = nil) throws -> Int {
        let root = (baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("SafeGram", isDirectory: true)
        let destination = root.appendingPathComponent("account-\(accountId)", isDirectory: true)
        let filenames = ["forensics-events.json", "security-findings.json", "profile-timeline.json", "relationship-radar.json", "identity-samples.json", "canaries.json"]
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var copied = 0
        for name in filenames {
            let source = root.appendingPathComponent(name)
            let target = destination.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path), !FileManager.default.fileExists(atPath: target.path) else { continue }
            let bytes = try Data(contentsOf: source)
            _ = try JSONSerialization.jsonObject(with: bytes)
            try bytes.write(to: target, options: [.atomic, .completeFileProtectionUnlessOpen])
            copied += 1
        }
        return copied
    }
}

private extension JSONEncoder {
    static var safeGram: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var safeGram: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
