import Foundation

public actor SettingsService {
    private let repository: any CaptureRepository
    private let credentialStore: any CredentialStore
    private let notion: any NotionServicing

    public init(
        repository: any CaptureRepository,
        credentialStore: any CredentialStore,
        notion: any NotionServicing
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
        self.notion = notion
    }

    public func currentDestinations() async throws -> DestinationSet? {
        try await repository.load().destinations
    }

    public func hasToken() async -> Bool {
        guard let token = try? await credentialStore.readToken() else {
            return false
        }
        return !token.isEmpty
    }

    public func provisionAndSave(
        token: String,
        parentPageID: String
    ) async throws -> DestinationSet {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw ClaspError.credentialNotFound
        }
        let destinations = try await notion.provisionDestinations(
            parentPageID: parentPageID,
            token: trimmedToken
        )
        try await credentialStore.saveToken(trimmedToken)
        try await repository.saveDestinations(destinations)
        return destinations
    }

    public func provisionUsingSavedToken(
        parentPageID: String
    ) async throws -> DestinationSet {
        guard let token = try await credentialStore.readToken(), !token.isEmpty else {
            throw ClaspError.credentialNotFound
        }
        let destinations = try await notion.provisionDestinations(
            parentPageID: parentPageID,
            token: token
        )
        try await repository.saveDestinations(destinations)
        return destinations
    }

    public func revalidate() async throws -> DestinationSet {
        guard let token = try await credentialStore.readToken(), !token.isEmpty else {
            throw ClaspError.credentialNotFound
        }
        guard let existing = try await repository.load().destinations else {
            throw ClaspError.destinationNotConfigured
        }
        let destinations = try await notion.validateDestinations(existing, token: token)
        try await repository.saveDestinations(destinations)
        return destinations
    }

    public func removeConnection() async throws {
        try await credentialStore.deleteToken()
        try await repository.saveDestinations(nil)
    }
}
