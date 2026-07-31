import Foundation
import Testing
@testable import ClaspCore

actor StubNotionService: NotionServicing {
    var validationResult: Result<DestinationSet, Error>

    init(validationResult: Result<DestinationSet, Error>) {
        self.validationResult = validationResult
    }

    func provisionDestinations(
        parentPageID: String,
        token: String
    ) async throws -> DestinationSet {
        try validationResult.get()
    }

    func validateDestinations(
        _ destinations: DestinationSet,
        token: String
    ) async throws -> DestinationSet {
        try validationResult.get()
    }

    func deliver(
        _ capture: Capture,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> NotionPageReference {
        NotionPageReference(id: "page", url: nil)
    }
}

@Suite("Settings service")
struct SettingsServiceTests {
    @Test("Persists credentials only after successful validation")
    func savesAfterValidation() async throws {
        let repository = InMemoryCaptureRepository()
        let credentials = InMemoryCredentialStore()
        let service = SettingsService(
            repository: repository,
            credentialStore: credentials,
            notion: StubNotionService(validationResult: .success(fixtureDestinations()))
        )

        let saved = try await service.provisionAndSave(
            token: " ntn_test ",
            parentPageID: "parent"
        )
        #expect(saved == fixtureDestinations())
        #expect(try await credentials.readToken() == "ntn_test")
        #expect(try await repository.load().destinations == fixtureDestinations())
    }

    @Test("Does not replace credentials after failed validation")
    func doesNotSaveInvalidConnection() async {
        let repository = InMemoryCaptureRepository()
        let credentials = InMemoryCredentialStore(token: "old")
        let service = SettingsService(
            repository: repository,
            credentialStore: credentials,
            notion: StubNotionService(validationResult: .failure(ClaspError.authenticationFailed))
        )

        do {
            _ = try await service.provisionAndSave(
                token: "new",
                parentPageID: "parent"
            )
            Issue.record("Expected validation failure")
        } catch {
            let storedToken = try? await credentials.readToken()
            #expect(storedToken == "old")
        }
    }
}
