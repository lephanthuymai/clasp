import Foundation
import Testing
@testable import ClaspCore

@Suite("File capture store")
struct FileCaptureStoreTests {
    @Test("Round-trips captures with owner-only permissions")
    func roundTripsCaptureAndDestination() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("store.json")
        let store = FileCaptureStore(fileURL: url)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let capture = Capture(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Read this",
            body: "Selected text",
            type: .bookmark,
            source: SourceContext(applicationName: "Safari"),
            createdAt: date,
            updatedAt: date
        )

        try await store.upsert(capture)
        let loaded = try await store.load()

        #expect(loaded.captures == [capture])
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
    }

    @Test("Loads the last-known-good backup when primary data is corrupted")
    func loadsBackupWhenPrimaryIsCorrupted() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("store.json")
        let store = FileCaptureStore(fileURL: url)
        try await store.save(StoreDocument())
        try await store.save(StoreDocument(captures: []))
        try Data("not json".utf8).write(to: url, options: .atomic)

        let reloadedStore = FileCaptureStore(fileURL: url)
        let loaded = try await reloadedStore.load()
        #expect(loaded.schemaVersion == StoreDocument.currentSchemaVersion)
    }

    @Test("Rejects unsupported schema versions")
    func rejectsUnsupportedSchemaVersion() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileCaptureStore(fileURL: url)

        do {
            try await store.save(StoreDocument(schemaVersion: 99))
            Issue.record("Expected unsupported version")
        } catch let error as ClaspError {
            #expect(error == .unsupportedStoreVersion(99))
        }
    }

    @Test("Migrates version 1 by preserving captures and clearing old destination")
    func migratesVersionOne() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("store.json")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let capture = Capture(
            id: UUID(),
            title: "Legacy",
            body: "Preserve me",
            type: .task,
            source: .unknown,
            createdAt: date,
            updatedAt: date
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let currentData = try encoder.encode(StoreDocument(captures: [capture]))
        var object = try #require(
            JSONSerialization.jsonObject(with: currentData) as? [String: Any]
        )
        object["schemaVersion"] = 1
        object.removeValue(forKey: "destinations")
        object["destination"] = ["databaseID": "legacy"]
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        let migrated = try await FileCaptureStore(fileURL: url).load()

        #expect(migrated.schemaVersion == 2)
        #expect(migrated.captures == [capture])
        #expect(migrated.destinations == nil)
    }
}
