import Foundation

public actor LibraryService {
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

    public func loadAll() async throws -> (
        tasks: [NotionListItem],
        bookmarks: [NotionListItem]
    ) {
        guard let destinations = try await repository.load().destinations else {
            throw ClaspError.destinationNotConfigured
        }
        guard let token = try await credentialStore.readToken(), !token.isEmpty else {
            throw ClaspError.credentialNotFound
        }

        async let tasks = notion.fetchItems(
            type: .task,
            destination: destinations.tasks,
            token: token
        )
        async let bookmarks = notion.fetchItems(
            type: .bookmark,
            destination: destinations.bookmarks,
            token: token
        )
        return try await (tasks, bookmarks)
    }

    public func markDone(pageID: String) async throws {
        guard let token = try await credentialStore.readToken(), !token.isEmpty else {
            throw ClaspError.credentialNotFound
        }
        try await notion.markDone(pageID: pageID, token: token)
    }

    public func deletePage(pageID: String) async throws {
        guard let token = try await credentialStore.readToken(), !token.isEmpty else {
            throw ClaspError.credentialNotFound
        }
        try await notion.deletePage(pageID: pageID, token: token)
    }

    public func updateTaskPriority(
        pageID: String,
        priority: TaskPriority
    ) async throws {
        let context = try await taskUpdateContext()
        try await notion.updateTaskPriority(
            pageID: pageID,
            destination: context.destination,
            priority: priority,
            token: context.token
        )
    }

    public func updateTaskDueDate(
        pageID: String,
        dueDate: Date?
    ) async throws {
        let context = try await taskUpdateContext()
        try await notion.updateTaskDueDate(
            pageID: pageID,
            destination: context.destination,
            dueDate: dueDate,
            token: context.token
        )
    }

    public func updateTaskProgress(
        pageID: String,
        progress: TaskProgress
    ) async throws {
        let context = try await taskUpdateContext()
        try await notion.updateTaskProgress(
            pageID: pageID,
            destination: context.destination,
            progress: progress,
            token: context.token
        )
    }

    private func taskUpdateContext() async throws -> (
        destination: DestinationConfiguration,
        token: String
    ) {
        guard let destinations = try await repository.load().destinations else {
            throw ClaspError.destinationNotConfigured
        }
        guard let token = try await credentialStore.readToken(), !token.isEmpty else {
            throw ClaspError.credentialNotFound
        }
        return (destinations.tasks, token)
    }
}
