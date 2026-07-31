import Foundation

public enum CaptureType: String, Codable, CaseIterable, Sendable {
    case task
    case bookmark

    public var displayName: String {
        rawValue.capitalized
    }
}

public enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    public var displayName: String {
        rawValue.capitalized
    }
}

public enum TaskProgress: String, Codable, CaseIterable, Sendable {
    case notStarted = "Not Started"
    case working = "Working"
    case waiting = "Waiting"
    case completed = "Completed"
    case failed = "Failed"

    public var displayName: String { rawValue }
}

public struct SourceContext: Codable, Equatable, Sendable {
    public var applicationName: String
    public var bundleIdentifier: String?
    public var processIdentifier: Int32?
    public var sourceURL: URL?

    public init(
        applicationName: String,
        bundleIdentifier: String? = nil,
        processIdentifier: Int32? = nil,
        sourceURL: URL? = nil
    ) {
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.sourceURL = sourceURL
    }

    public static let unknown = SourceContext(applicationName: "Unknown Application")

    public var displaySource: String {
        guard let sourceURL else { return "" }
        return sourceURL.isFileURL ? sourceURL.path : sourceURL.absoluteString
    }
}

public enum DeliveryState: String, Codable, CaseIterable, Sendable {
    case pending
    case delivering
    case delivered
    case failed
}

public enum DeliveryOutcome: String, Codable, Sendable {
    case delivered
    case retryableFailure
    case permanentFailure
    case ambiguous
}

public struct DeliveryAttempt: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var finishedAt: Date?
    public var outcome: DeliveryOutcome
    public var statusCode: Int?
    public var safeMessage: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date? = nil,
        outcome: DeliveryOutcome,
        statusCode: Int? = nil,
        safeMessage: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.outcome = outcome
        self.statusCode = statusCode
        self.safeMessage = safeMessage
    }
}

public struct Capture: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var type: CaptureType
    public var source: SourceContext
    public var dueDate: Date?
    public var priority: TaskPriority?
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var delivery: DeliveryState
    public var remotePageID: String?
    public var remotePageURL: URL?
    public var attempts: [DeliveryAttempt]

    public init(
        id: UUID,
        title: String,
        body: String,
        type: CaptureType,
        source: SourceContext,
        dueDate: Date? = nil,
        priority: TaskPriority? = nil,
        tags: [String] = [],
        createdAt: Date,
        updatedAt: Date,
        delivery: DeliveryState = .pending,
        remotePageID: String? = nil,
        remotePageURL: URL? = nil,
        attempts: [DeliveryAttempt] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.type = type
        self.source = source
        self.dueDate = type == .task ? dueDate : nil
        self.priority = type == .task ? priority : nil
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.delivery = delivery
        self.remotePageID = remotePageID
        self.remotePageURL = remotePageURL
        self.attempts = attempts
    }
}

public struct NotionPropertyReference: Codable, Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct NotionPropertyMap: Codable, Equatable, Sendable {
    public var name: NotionPropertyReference
    public var source: NotionPropertyReference
    public var dueDate: NotionPropertyReference?
    public var priority: NotionPropertyReference?
    public var notes: NotionPropertyReference?
    public var progress: NotionPropertyReference?

    public init(
        name: NotionPropertyReference,
        source: NotionPropertyReference,
        dueDate: NotionPropertyReference? = nil,
        priority: NotionPropertyReference? = nil,
        notes: NotionPropertyReference? = nil,
        progress: NotionPropertyReference? = nil
    ) {
        self.name = name
        self.source = source
        self.dueDate = dueDate
        self.priority = priority
        self.notes = notes
        self.progress = progress
    }
}

public struct DestinationConfiguration: Codable, Equatable, Sendable {
    public var databaseID: String
    public var dataSourceID: String
    public var dataSourceName: String
    public var propertyMap: NotionPropertyMap
    public var validatedAt: Date
    public var apiVersion: String

    public init(
        databaseID: String,
        dataSourceID: String,
        dataSourceName: String,
        propertyMap: NotionPropertyMap,
        validatedAt: Date,
        apiVersion: String = "2026-03-11"
    ) {
        self.databaseID = databaseID
        self.dataSourceID = dataSourceID
        self.dataSourceName = dataSourceName
        self.propertyMap = propertyMap
        self.validatedAt = validatedAt
        self.apiVersion = apiVersion
    }
}

public struct DestinationSet: Codable, Equatable, Sendable {
    public var parentPageID: String
    public var tasks: DestinationConfiguration
    public var bookmarks: DestinationConfiguration
    public var provisionedAt: Date
    public var apiVersion: String

    public init(
        parentPageID: String,
        tasks: DestinationConfiguration,
        bookmarks: DestinationConfiguration,
        provisionedAt: Date,
        apiVersion: String = "2026-03-11"
    ) {
        self.parentPageID = parentPageID
        self.tasks = tasks
        self.bookmarks = bookmarks
        self.provisionedAt = provisionedAt
        self.apiVersion = apiVersion
    }

    public func destination(for type: CaptureType) -> DestinationConfiguration {
        switch type {
        case .task: tasks
        case .bookmark: bookmarks
        }
    }
}

public struct StoreDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var captures: [Capture]
    public var destinations: DestinationSet?

    public init(
        schemaVersion: Int = StoreDocument.currentSchemaVersion,
        captures: [Capture] = [],
        destinations: DestinationSet? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.captures = captures
        self.destinations = destinations
    }
}

public struct NotionPageReference: Equatable, Sendable {
    public var id: String
    public var url: URL?

    public init(id: String, url: URL?) {
        self.id = id
        self.url = url
    }
}

public struct NotionListItem: Identifiable, Equatable, Sendable {
    public var id: String
    public var url: URL?
    public var type: CaptureType
    public var title: String
    public var source: String
    public var notes: String
    public var dueDate: Date?
    public var priority: TaskPriority?
    public var progress: TaskProgress
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: String,
        url: URL?,
        type: CaptureType,
        title: String,
        source: String,
        notes: String = "",
        dueDate: Date? = nil,
        priority: TaskPriority? = nil,
        progress: TaskProgress = .notStarted,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.type = type
        self.title = title
        self.source = source
        self.notes = type == .task ? notes : ""
        self.dueDate = type == .task ? dueDate : nil
        self.priority = type == .task ? priority : nil
        self.progress = type == .task ? progress : .notStarted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var taskID: String {
        let compact = id.filter(\.isHexDigit).uppercased()
        let rawSuffix = String(compact.suffix(8))
        let suffix = String(
            repeating: "0",
            count: max(0, 8 - rawSuffix.count)
        ) + rawSuffix
        return "CLASP-\(suffix)"
    }
}
