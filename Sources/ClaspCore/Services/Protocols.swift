import Foundation

public protocol CaptureRepository: Sendable {
    func load() async throws -> StoreDocument
    func save(_ document: StoreDocument) async throws
    func upsert(_ capture: Capture) async throws
    func deleteCapture(id: UUID) async throws
    func saveDestinations(_ destinations: DestinationSet?) async throws
}

public protocol CredentialStore: Sendable {
    func readToken() async throws -> String?
    func saveToken(_ token: String) async throws
    func deleteToken() async throws
}

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
}

public struct HTTPRequest: Sendable {
    public var method: HTTPMethod
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol DateProviding: Sendable {
    func now() -> Date
}

public struct SystemDateProvider: DateProviding {
    public init() {}
    public func now() -> Date { Date() }
}

public protocol UUIDProviding: Sendable {
    func makeUUID() -> UUID
}

public struct SystemUUIDProvider: UUIDProviding {
    public init() {}
    public func makeUUID() -> UUID { UUID() }
}

public protocol NotionServicing: Sendable {
    func provisionDestinations(
        parentPageID: String,
        token: String
    ) async throws -> DestinationSet

    func validateDestinations(
        _ destinations: DestinationSet,
        token: String
    ) async throws -> DestinationSet

    func deliver(
        _ capture: Capture,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> NotionPageReference

    func fetchItems(
        type: CaptureType,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> [NotionListItem]

    func markDone(pageID: String, token: String) async throws

    func deletePage(pageID: String, token: String) async throws

    func updateTaskPriority(
        pageID: String,
        destination: DestinationConfiguration,
        priority: TaskPriority,
        token: String
    ) async throws

    func updateTaskDueDate(
        pageID: String,
        destination: DestinationConfiguration,
        dueDate: Date?,
        token: String
    ) async throws

    func updateTaskProgress(
        pageID: String,
        destination: DestinationConfiguration,
        progress: TaskProgress,
        token: String
    ) async throws
}

public protocol SelectionReading: Sendable {
    func readSelection() async -> SelectionOutcome
}
