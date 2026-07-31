import Foundation
import Testing
@testable import ClaspCore

@Suite("Delivery coordinator")
struct DeliveryCoordinatorTests {
    @Test("Recovers interrupted delivery to pending")
    func recoversInterruptedDelivery() async throws {
        let capture = fixtureCoordinatorCapture(delivery: .delivering)
        let repository = InMemoryCaptureRepository(
            document: StoreDocument(captures: [capture], destinations: fixtureDestinations())
        )
        let service = CaptureService(
            repository: repository,
            credentialStore: InMemoryCredentialStore(),
            notion: StubNotionService(validationResult: .success(fixtureDestinations()))
        )
        let coordinator = DeliveryCoordinator(
            repository: repository,
            captureService: service
        )

        let recovered = try await coordinator.recoverInterruptedDeliveries()
        #expect(recovered.first?.delivery == .pending)
        #expect(try await repository.load().captures.first?.delivery == .pending)
    }

    @Test("Manual retry returns a delivered capture")
    func retriesFailedCapture() async throws {
        let capture = fixtureCoordinatorCapture(delivery: .failed)
        let repository = InMemoryCaptureRepository(
            document: StoreDocument(captures: [capture], destinations: fixtureDestinations())
        )
        let credentials = InMemoryCredentialStore(token: "ntn_test")
        let notion = StubNotionService(validationResult: .success(fixtureDestinations()))
        let service = CaptureService(
            repository: repository,
            credentialStore: credentials,
            notion: notion
        )
        let coordinator = DeliveryCoordinator(
            repository: repository,
            captureService: service
        )

        let result = try await coordinator.retry(id: capture.id)
        #expect(result.delivery == .delivered)
    }
}

private func fixtureCoordinatorCapture(delivery: DeliveryState) -> Capture {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    return Capture(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        title: "Task",
        body: "Body",
        type: .task,
        source: .unknown,
        createdAt: date,
        updatedAt: date,
        delivery: delivery
    )
}
