import Foundation

public actor FileCaptureStore: CaptureRepository {
    public let fileURL: URL
    public let backupURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private var cachedDocument: StoreDocument?

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let resolvedURL: URL
        if let fileURL {
            resolvedURL = fileURL
        } else {
            let root = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            resolvedURL = root
                .appendingPathComponent("Clasp", isDirectory: true)
                .appendingPathComponent("clasp-store.json")
        }
        self.fileURL = resolvedURL
        self.backupURL = resolvedURL.appendingPathExtension("backup")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() async throws -> StoreDocument {
        if let cachedDocument {
            return cachedDocument
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            let document = StoreDocument()
            cachedDocument = document
            return document
        }

        do {
            let document = try decodeDocument(at: fileURL)
            cachedDocument = document
            return document
        } catch {
            guard fileManager.fileExists(atPath: backupURL.path),
                  let backup = try? decodeDocument(at: backupURL)
            else {
                throw ClaspError.storeCorrupted
            }
            cachedDocument = backup
            return backup
        }
    }

    public func save(_ document: StoreDocument) async throws {
        guard document.schemaVersion == StoreDocument.currentSchemaVersion else {
            throw ClaspError.unsupportedStoreVersion(document.schemaVersion)
        }

        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        if fileManager.fileExists(atPath: fileURL.path) {
            if fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: backupURL)
            }
            try? fileManager.copyItem(at: fileURL, to: backupURL)
        }

        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: [.atomic])
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        cachedDocument = document
    }

    public func upsert(_ capture: Capture) async throws {
        var document = try await load()
        if let index = document.captures.firstIndex(where: { $0.id == capture.id }) {
            document.captures[index] = capture
        } else {
            document.captures.append(capture)
        }
        document.captures.sort { $0.createdAt > $1.createdAt }
        try await save(document)
    }

    public func deleteCapture(id: UUID) async throws {
        var document = try await load()
        document.captures.removeAll { $0.id == id }
        try await save(document)
    }

    public func saveDestinations(_ destinations: DestinationSet?) async throws {
        var document = try await load()
        document.destinations = destinations
        try await save(document)
    }

    private func decodeDocument(at url: URL) throws -> StoreDocument {
        let data = try Data(contentsOf: url)
        if let document = try? decoder.decode(StoreDocument.self, from: data),
           document.schemaVersion == StoreDocument.currentSchemaVersion {
            return document
        }
        let legacy = try decoder.decode(LegacyStoreDocument.self, from: data)
        guard legacy.schemaVersion == 1 else {
            throw ClaspError.unsupportedStoreVersion(legacy.schemaVersion)
        }
        return StoreDocument(captures: legacy.captures)
    }
}

private struct LegacyStoreDocument: Decodable {
    var schemaVersion: Int
    var captures: [Capture]
}
