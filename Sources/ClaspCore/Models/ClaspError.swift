import Foundation

public enum ClaspError: LocalizedError, Equatable, Sendable {
    case invalidTitle
    case invalidBody
    case invalidURL
    case contentTooLong
    case storeCorrupted
    case unsupportedStoreVersion(Int)
    case credentialNotFound
    case keychainFailure(Int32)
    case invalidResponse
    case authenticationFailed
    case accessDenied
    case destinationNotFound
    case multipleDataSources([NotionDataSourceSummary])
    case incompatibleSchema([SchemaIssue])
    case rateLimited(retryAfter: TimeInterval?)
    case retryableServiceFailure(statusCode: Int)
    case permanentServiceFailure(statusCode: Int, message: String)
    case transportFailure(message: String)
    case ambiguousDelivery
    case destinationNotConfigured

    public var errorDescription: String? {
        switch self {
        case .invalidTitle:
            "Add a title before saving."
        case .invalidBody:
            "Add some content before saving."
        case .invalidURL:
            "Source must be a web URL or an absolute file path."
        case .contentTooLong:
            "The selected content is too long for one Notion item."
        case .storeCorrupted:
            "Clasp could not read its local capture store."
        case let .unsupportedStoreVersion(version):
            "This capture store uses unsupported version \(version)."
        case .credentialNotFound:
            "Add your Notion integration token in Settings."
        case .keychainFailure:
            "Clasp could not access the token in Keychain."
        case .invalidResponse:
            "Notion returned an unreadable response."
        case .authenticationFailed:
            "The Notion token is invalid or expired."
        case .accessDenied:
            "Share the Notion parent page and enable Read, Insert, and Update content for the integration."
        case .destinationNotFound:
            "The Notion parent page or a Clasp database could not be found."
        case .multipleDataSources:
            "This database has multiple data sources. Choose one in Settings."
        case .incompatibleSchema:
            "The Notion data source does not have the required Clasp fields."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                "Notion is busy. Try again in \(Int(retryAfter.rounded(.up))) seconds."
            } else {
                "Notion is busy. Try again shortly."
            }
        case .retryableServiceFailure:
            "Notion is temporarily unavailable. The capture remains safe in Clasp."
        case let .permanentServiceFailure(_, message):
            message
        case .transportFailure:
            "The network request failed. The capture remains safe in Clasp."
        case .ambiguousDelivery:
            "Clasp could not confirm whether Notion accepted this capture. Check Notion before retrying."
        case .destinationNotConfigured:
            "Create the Clasp Tasks and Bookmarks databases in Settings before delivering captures."
        }
    }
}

public struct SchemaIssue: Codable, Equatable, Hashable, Sendable {
    public var propertyName: String
    public var expectedType: String
    public var actualType: String?
    public var message: String

    public init(
        propertyName: String,
        expectedType: String,
        actualType: String?,
        message: String
    ) {
        self.propertyName = propertyName
        self.expectedType = expectedType
        self.actualType = actualType
        self.message = message
    }
}

public struct NotionDataSourceSummary: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
