import Foundation
import Testing
@testable import ClaspCore

@Suite("Notion delivery")
struct NotionDeliveryTests {
    @Test("Creates one page in the supplied managed destination")
    func createsPage() async throws {
        let transport = QueueHTTPTransport([
            .success(jsonResponse(#"{"id":"new-page","url":"https://notion.so/new-page"}"#))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        let page = try await client.deliver(
            fixtureCapture(),
            destination: fixtureDestination(type: .task),
            token: "ntn_test"
        )
        #expect(page.id == "new-page")
        let requests = await transport.capturedRequests()
        #expect(requests.count == 1)
        #expect(requests[0].url.path.hasSuffix("/pages"))
    }

    @Test("Classifies a create transport failure as ambiguous")
    func classifiesAmbiguousCreate() async {
        let transport = QueueHTTPTransport([
            .failure(ClaspError.transportFailure(message: "offline"))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        do {
            _ = try await client.deliver(
                fixtureCapture(),
                destination: fixtureDestination(type: .task),
                token: "ntn_test"
            )
            Issue.record("Expected ambiguous delivery")
        } catch let error as ClaspError {
            #expect(error == .ambiguousDelivery)
        } catch {
            Issue.record("Unexpected error")
        }
    }
}

private func fixtureCapture(delivery: DeliveryState = .pending) -> Capture {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    return Capture(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Task",
        body: "Selected",
        type: .task,
        source: .unknown,
        createdAt: date,
        updatedAt: date,
        delivery: delivery
    )
}
