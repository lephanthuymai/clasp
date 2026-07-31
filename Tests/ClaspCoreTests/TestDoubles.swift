import Foundation
@testable import ClaspCore

actor InMemoryCaptureRepository: CaptureRepository {
    var document: StoreDocument

    init(document: StoreDocument = StoreDocument()) {
        self.document = document
    }

    func load() async throws -> StoreDocument { document }
    func save(_ document: StoreDocument) async throws { self.document = document }

    func upsert(_ capture: Capture) async throws {
        if let index = document.captures.firstIndex(where: { $0.id == capture.id }) {
            document.captures[index] = capture
        } else {
            document.captures.append(capture)
        }
    }

    func deleteCapture(id: UUID) async throws {
        document.captures.removeAll { $0.id == id }
    }

    func saveDestinations(_ destinations: DestinationSet?) async throws {
        document.destinations = destinations
    }
}

actor InMemoryCredentialStore: CredentialStore {
    var token: String?
    init(token: String? = nil) { self.token = token }
    func readToken() async throws -> String? { token }
    func saveToken(_ token: String) async throws { self.token = token }
    func deleteToken() async throws { token = nil }
}

struct FixedDateProvider: DateProviding {
    let date: Date
    func now() -> Date { date }
}

struct FixedUUIDProvider: UUIDProviding {
    let uuid: UUID
    func makeUUID() -> UUID { uuid }
}

func fixtureTaskPropertyMap() -> NotionPropertyMap {
    NotionPropertyMap(
        name: .init(id: "title-id", name: "Name"),
        source: .init(id: "source-id", name: "Source"),
        dueDate: .init(id: "due-id", name: "Due Date"),
        priority: .init(id: "priority-id", name: "Priority"),
        notes: .init(id: "notes-id", name: "Notes"),
        progress: .init(id: "progress-id", name: "Progress")
    )
}

func fixtureBookmarkPropertyMap() -> NotionPropertyMap {
    NotionPropertyMap(
        name: .init(id: "bookmark-title-id", name: "Name"),
        source: .init(id: "bookmark-source-id", name: "Source")
    )
}

func fixtureDestination(type: CaptureType = .task) -> DestinationConfiguration {
    DestinationConfiguration(
        databaseID: type == .task ? "task-database-id" : "bookmark-database-id",
        dataSourceID: type == .task ? "task-data-source-id" : "bookmark-data-source-id",
        dataSourceName: type == .task ? "Clasp Tasks" : "Clasp Bookmarks",
        propertyMap: type == .task ? fixtureTaskPropertyMap() : fixtureBookmarkPropertyMap(),
        validatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

func fixtureDestinations() -> DestinationSet {
    DestinationSet(
        parentPageID: "parent-page-id",
        tasks: fixtureDestination(type: .task),
        bookmarks: fixtureDestination(type: .bookmark),
        provisionedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

extension NotionServicing {
    func provisionDestinations(
        parentPageID: String,
        token: String
    ) async throws -> DestinationSet {
        fixtureDestinations()
    }

    func validateDestinations(
        _ destinations: DestinationSet,
        token: String
    ) async throws -> DestinationSet {
        destinations
    }

    func fetchItems(
        type: CaptureType,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> [NotionListItem] {
        []
    }

    func markDone(pageID: String, token: String) async throws {}

    func deletePage(pageID: String, token: String) async throws {}

    func updateTaskPriority(
        pageID: String,
        destination: DestinationConfiguration,
        priority: TaskPriority,
        token: String
    ) async throws {}

    func updateTaskDueDate(
        pageID: String,
        destination: DestinationConfiguration,
        dueDate: Date?,
        token: String
    ) async throws {}

    func updateTaskProgress(
        pageID: String,
        destination: DestinationConfiguration,
        progress: TaskProgress,
        token: String
    ) async throws {}
}
