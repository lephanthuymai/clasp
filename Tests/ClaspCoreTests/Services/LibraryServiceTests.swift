import Foundation
import Testing
@testable import ClaspCore

actor LibraryNotionStub: NotionServicing {
    private var donePageIDs: [String] = []
    private var deletedPageIDs: [String] = []
    private var priorityUpdates: [(String, TaskPriority)] = []
    private var dueDateUpdates: [(String, Date?)] = []
    private var progressUpdates: [(String, TaskProgress)] = []

    func deliver(
        _ capture: Capture,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> NotionPageReference {
        NotionPageReference(id: "page", url: nil)
    }

    func fetchItems(
        type: CaptureType,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> [NotionListItem] {
        [
            NotionListItem(
                id: "\(type.rawValue)-page",
                url: URL(string: "https://www.notion.so/\(type.rawValue)-page"),
                type: type,
                title: type == .task ? "Task from Notion" : "Bookmark from Notion",
                source: "https://example.com"
            )
        ]
    }

    func markDone(pageID: String, token: String) async throws {
        donePageIDs.append(pageID)
    }

    func deletePage(pageID: String, token: String) async throws {
        deletedPageIDs.append(pageID)
    }

    func updateTaskPriority(
        pageID: String,
        destination: DestinationConfiguration,
        priority: TaskPriority,
        token: String
    ) async throws {
        priorityUpdates.append((pageID, priority))
    }

    func updateTaskDueDate(
        pageID: String,
        destination: DestinationConfiguration,
        dueDate: Date?,
        token: String
    ) async throws {
        dueDateUpdates.append((pageID, dueDate))
    }

    func updateTaskProgress(
        pageID: String,
        destination: DestinationConfiguration,
        progress: TaskProgress,
        token: String
    ) async throws {
        progressUpdates.append((pageID, progress))
    }

    func markedPageIDs() -> [String] {
        donePageIDs
    }

    func trashedPageIDs() -> [String] {
        deletedPageIDs
    }

    func updatedPriorities() -> [(String, TaskPriority)] {
        priorityUpdates
    }

    func updatedDueDates() -> [(String, Date?)] {
        dueDateUpdates
    }

    func updatedProgress() -> [(String, TaskProgress)] {
        progressUpdates
    }
}

@Suite("Library service")
struct LibraryServiceTests {
    @Test("Loads each managed Notion data source")
    func loadsAllDestinations() async throws {
        let repository = InMemoryCaptureRepository(
            document: StoreDocument(destinations: fixtureDestinations())
        )
        let service = LibraryService(
            repository: repository,
            credentialStore: InMemoryCredentialStore(token: "ntn_test"),
            notion: LibraryNotionStub()
        )

        let result = try await service.loadAll()

        #expect(result.tasks.map(\.title) == ["Task from Notion"])
        #expect(result.bookmarks.map(\.title) == ["Bookmark from Notion"])
    }

    @Test("Marks a remote item done with the saved token")
    func marksDone() async throws {
        let notion = LibraryNotionStub()
        let service = LibraryService(
            repository: InMemoryCaptureRepository(),
            credentialStore: InMemoryCredentialStore(token: "ntn_test"),
            notion: notion
        )

        try await service.markDone(pageID: "page-id")

        #expect(await notion.markedPageIDs() == ["page-id"])
    }

    @Test("Moves a remote item to Notion Trash with the saved token")
    func deletesPage() async throws {
        let notion = LibraryNotionStub()
        let service = LibraryService(
            repository: InMemoryCaptureRepository(),
            credentialStore: InMemoryCredentialStore(token: "ntn_test"),
            notion: notion
        )

        try await service.deletePage(pageID: "page-id")

        #expect(await notion.trashedPageIDs() == ["page-id"])
    }

    @Test("Updates task fields with the saved destination and token")
    func updatesTaskFields() async throws {
        let notion = LibraryNotionStub()
        let service = LibraryService(
            repository: InMemoryCaptureRepository(
                document: StoreDocument(destinations: fixtureDestinations())
            ),
            credentialStore: InMemoryCredentialStore(token: "ntn_test"),
            notion: notion
        )
        let dueDate = Date(timeIntervalSince1970: 1_700_000_000)

        try await service.updateTaskPriority(pageID: "page-id", priority: .high)
        try await service.updateTaskDueDate(pageID: "page-id", dueDate: dueDate)
        try await service.updateTaskDueDate(pageID: "page-id", dueDate: nil)
        try await service.updateTaskProgress(pageID: "page-id", progress: .working)

        let priorities = await notion.updatedPriorities()
        #expect(priorities.count == 1)
        #expect(priorities[0].0 == "page-id")
        #expect(priorities[0].1 == .high)

        let dueDates = await notion.updatedDueDates()
        #expect(dueDates.count == 2)
        #expect(dueDates[0].0 == "page-id")
        #expect(dueDates[0].1 == dueDate)
        #expect(dueDates[1].0 == "page-id")
        #expect(dueDates[1].1 == nil)

        let progress = await notion.updatedProgress()
        #expect(progress.count == 1)
        #expect(progress[0].0 == "page-id")
        #expect(progress[0].1 == .working)
    }
}
