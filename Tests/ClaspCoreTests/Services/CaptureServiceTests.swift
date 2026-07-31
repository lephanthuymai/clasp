import Foundation
import Testing
@testable import ClaspCore

actor InspectingNotionService: NotionServicing {
    let repository: InMemoryCaptureRepository
    var sawPersistedPending = false

    init(repository: InMemoryCaptureRepository) {
        self.repository = repository
    }

    func deliver(
        _ capture: Capture,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> NotionPageReference {
        let stored = try await repository.load().captures.first { $0.id == capture.id }
        sawPersistedPending = stored?.delivery == .delivering || stored?.delivery == .pending
        return NotionPageReference(
            id: "page-id",
            url: URL(string: "https://notion.so/page-id")
        )
    }

    func didSeePersistedPending() -> Bool { sawPersistedPending }
}

actor CountingNotionService: NotionServicing {
    var deliveryCount = 0
    var deliveredDestinationIDs: [String] = []

    func deliver(
        _ capture: Capture,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> NotionPageReference {
        deliveryCount += 1
        deliveredDestinationIDs.append(destination.dataSourceID)
        return NotionPageReference(id: "page", url: nil)
    }

    func count() -> Int { deliveryCount }
    func destinationIDs() -> [String] { deliveredDestinationIDs }
}

@Suite("Capture service")
struct CaptureServiceTests {
    @Test("Enqueue persists pending without waiting for Notion")
    func enqueueDoesNotDeliver() async throws {
        let repository = InMemoryCaptureRepository(
            document: StoreDocument(destinations: fixtureDestinations())
        )
        let notion = CountingNotionService()
        let service = CaptureService(
            repository: repository,
            credentialStore: InMemoryCredentialStore(token: "test-token"),
            notion: notion
        )

        let capture = try await service.enqueue(
            CaptureDraft(title: "Task", body: "Selected")
        )

        #expect(capture.delivery == .pending)
        #expect(await notion.count() == 0)
        #expect(try await repository.load().captures.first?.delivery == .pending)
    }

    @Test("Persists before delivery and records success")
    func persistsBeforeDelivery() async throws {
        let repository = InMemoryCaptureRepository(
            document: StoreDocument(destinations: fixtureDestinations())
        )
        let credentials = InMemoryCredentialStore(token: "ntn_test")
        let notion = InspectingNotionService(repository: repository)
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fixedID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let service = CaptureService(
            repository: repository,
            credentialStore: credentials,
            notion: notion,
            dateProvider: FixedDateProvider(date: fixedDate),
            uuidProvider: FixedUUIDProvider(uuid: fixedID)
        )

        let result = try await service.confirm(
            CaptureDraft(title: "Task", body: "Selected", type: .task)
        )

        #expect(await notion.didSeePersistedPending())
        #expect(result.delivery == .delivered)
        #expect(result.remotePageID == "page-id")
        #expect(try await repository.load().captures.first?.delivery == .delivered)
    }

    @Test("Routes each capture type to its managed database")
    func routesByCaptureType() async throws {
        let repository = InMemoryCaptureRepository(
            document: StoreDocument(destinations: fixtureDestinations())
        )
        let notion = CountingNotionService()
        let service = CaptureService(
            repository: repository,
            credentialStore: InMemoryCredentialStore(token: "ntn_test"),
            notion: notion
        )

        _ = try await service.confirm(
            CaptureDraft(title: "Task", body: "Notes", type: .task)
        )
        _ = try await service.confirm(
            CaptureDraft(title: "Bookmark", body: "", type: .bookmark)
        )

        #expect(
            await notion.destinationIDs()
                == ["task-data-source-id", "bookmark-data-source-id"]
        )
    }
}
