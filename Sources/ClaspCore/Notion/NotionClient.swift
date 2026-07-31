import Foundation

public actor NotionClient: NotionServicing {
    public static let apiVersion = "2026-03-11"

    private enum ManagedKind {
        case tasks
        case bookmarks

        var title: String {
            switch self {
            case .tasks: "Clasp Tasks"
            case .bookmarks: "Clasp Bookmarks"
            }
        }
    }

    private let transport: any HTTPTransport
    private let baseURL: URL
    private let dateProvider: any DateProviding
    private let decoder = JSONDecoder()

    public init(
        transport: any HTTPTransport,
        baseURL: URL = URL(string: "https://api.notion.com/v1")!,
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.transport = transport
        self.baseURL = baseURL
        self.dateProvider = dateProvider
    }

    public func provisionDestinations(
        parentPageID: String,
        token: String
    ) async throws -> DestinationSet {
        let parentID = try normalizeIdentifier(parentPageID)
        _ = try await send(method: .get, path: "pages/\(parentID)", token: token)

        let tasks = try await findOrCreate(.tasks, parentPageID: parentID, token: token)
        let bookmarks = try await findOrCreate(.bookmarks, parentPageID: parentID, token: token)
        return DestinationSet(
            parentPageID: parentID,
            tasks: tasks,
            bookmarks: bookmarks,
            provisionedAt: dateProvider.now(),
            apiVersion: Self.apiVersion
        )
    }

    public func validateDestinations(
        _ destinations: DestinationSet,
        token: String
    ) async throws -> DestinationSet {
        let tasks = try await resolveDestination(
            databaseID: destinations.tasks.databaseID,
            kind: .tasks,
            token: token
        )
        let bookmarks = try await resolveDestination(
            databaseID: destinations.bookmarks.databaseID,
            kind: .bookmarks,
            token: token
        )
        return DestinationSet(
            parentPageID: destinations.parentPageID,
            tasks: tasks,
            bookmarks: bookmarks,
            provisionedAt: dateProvider.now(),
            apiVersion: Self.apiVersion
        )
    }

    public func deliver(
        _ capture: Capture,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> NotionPageReference {
        let body = try NotionPayloadBuilder.makeCreatePageBody(
            capture: capture,
            destination: destination
        )
        do {
            let response = try await send(
                method: .post,
                path: "pages",
                token: token,
                body: body,
                ambiguousOnServerFailure: true
            )
            let page = try decoder.decode(PageResponse.self, from: response.body)
            return NotionPageReference(id: page.id, url: page.url.flatMap(URL.init(string:)))
        } catch let error as ClaspError {
            switch error {
            case .transportFailure, .retryableServiceFailure:
                throw ClaspError.ambiguousDelivery
            default:
                throw error
            }
        }
    }

    public func fetchItems(
        type: CaptureType,
        destination: DestinationConfiguration,
        token: String
    ) async throws -> [NotionListItem] {
        var source = try await retrieveAndEnsureManagedProperties(
            dataSourceID: destination.dataSourceID,
            token: token
        )
        if type == .task {
            source = try await ensureProgress(source, token: token)
        }
        var items: [NotionListItem] = []
        var cursor: String?

        repeat {
            let response = try await send(
                method: .post,
                path: "data_sources/\(destination.dataSourceID)/query",
                token: token,
                body: try NotionPayloadBuilder.makeDataSourceQueryBody(
                    startCursor: cursor
                )
            )
            let page = try decoder.decode(DataSourceQueryResponse.self, from: response.body)
            items.append(contentsOf: page.results.map {
                project(
                    $0,
                    type: type,
                    propertyMap: destination.propertyMap
                )
            })
            cursor = page.hasMore ? page.nextCursor : nil
        } while cursor != nil && items.count < 10_000

        return items
    }

    public func markDone(pageID: String, token: String) async throws {
        let normalizedPageID = try normalizeIdentifier(pageID)
        _ = try await send(
            method: .patch,
            path: "pages/\(normalizedPageID)",
            token: token,
            body: try NotionPayloadBuilder.makeSetDoneBody()
        )
    }

    public func deletePage(pageID: String, token: String) async throws {
        let normalizedPageID = try normalizeIdentifier(pageID)
        _ = try await send(
            method: .patch,
            path: "pages/\(normalizedPageID)",
            token: token,
            body: try NotionPayloadBuilder.makeTrashPageBody()
        )
    }

    public func updateTaskPriority(
        pageID: String,
        destination: DestinationConfiguration,
        priority: TaskPriority,
        token: String
    ) async throws {
        let normalizedPageID = try normalizeIdentifier(pageID)
        _ = try await send(
            method: .patch,
            path: "pages/\(normalizedPageID)",
            token: token,
            body: try NotionPayloadBuilder.makeSetTaskPriorityBody(
                priority,
                destination: destination
            )
        )
    }

    public func updateTaskDueDate(
        pageID: String,
        destination: DestinationConfiguration,
        dueDate: Date?,
        token: String
    ) async throws {
        let normalizedPageID = try normalizeIdentifier(pageID)
        _ = try await send(
            method: .patch,
            path: "pages/\(normalizedPageID)",
            token: token,
            body: try NotionPayloadBuilder.makeSetTaskDueDateBody(
                dueDate,
                destination: destination
            )
        )
    }

    public func updateTaskProgress(
        pageID: String,
        destination: DestinationConfiguration,
        progress: TaskProgress,
        token: String
    ) async throws {
        let normalizedPageID = try normalizeIdentifier(pageID)
        let source = try await retrieveAndEnsureManagedProperties(
            dataSourceID: destination.dataSourceID,
            token: token
        )
        let upgraded = try await ensureProgress(source, token: token)
        guard let property = upgraded.properties["Progress"] else {
            throw ClaspError.invalidResponse
        }
        _ = try await send(
            method: .patch,
            path: "pages/\(normalizedPageID)",
            token: token,
            body: try NotionPayloadBuilder.makeSetTaskProgressBody(
                progress,
                propertyID: property.id
            )
        )
    }

    private func findOrCreate(
        _ kind: ManagedKind,
        parentPageID: String,
        token: String
    ) async throws -> DestinationConfiguration {
        if let existingID = try await findDatabase(
            named: kind.title,
            parentPageID: parentPageID,
            token: token
        ) {
            return try await resolveDestination(
                databaseID: existingID,
                kind: kind,
                token: token
            )
        }

        let body: Data
        switch kind {
        case .tasks:
            body = try NotionPayloadBuilder.makeCreateTasksDatabaseBody(
                parentPageID: parentPageID
            )
        case .bookmarks:
            body = try NotionPayloadBuilder.makeCreateBookmarksDatabaseBody(
                parentPageID: parentPageID
            )
        }
        let response = try await send(
            method: .post,
            path: "databases",
            token: token,
            body: body
        )
        let created = try decoder.decode(CreatedDatabaseResponse.self, from: response.body)
        return try await resolveDestination(
            databaseID: created.id,
            kind: kind,
            token: token
        )
    }

    private func findDatabase(
        named title: String,
        parentPageID: String,
        token: String
    ) async throws -> String? {
        let response = try await send(
            method: .post,
            path: "search",
            token: token,
            body: try NotionPayloadBuilder.makeDatabaseSearchBody(title: title)
        )
        let results = try decoder.decode(DatabaseSearchResponse.self, from: response.body)
        return results.results.first { result in
            guard let databaseID = result.parent.databaseID,
                  let resultParentPageID = result.databaseParent?.pageID
            else {
                return false
            }
            return !databaseID.isEmpty
                && result.plainTitle == title
                && compactIdentifier(resultParentPageID)
                    == compactIdentifier(parentPageID)
        }?.parent.databaseID
    }

    private func resolveDestination(
        databaseID: String,
        kind: ManagedKind,
        token: String
    ) async throws -> DestinationConfiguration {
        let normalizedDatabaseID = try normalizeIdentifier(databaseID)
        let databaseResponse = try await send(
            method: .get,
            path: "databases/\(normalizedDatabaseID)",
            token: token
        )
        let database = try decoder.decode(DatabaseResponse.self, from: databaseResponse.body)
        guard let dataSource = database.dataSources.first else {
            throw ClaspError.destinationNotFound
        }
        let sourceResponse = try await send(
            method: .get,
            path: "data_sources/\(dataSource.id)",
            token: token
        )
        let decodedSource = try decoder.decode(
            DataSourceResponse.self,
            from: sourceResponse.body
        )
        var source = try await ensureCreatedDate(decodedSource, token: token)
        source = try await ensureDone(source, token: token)
        if kind == .tasks {
            source = try await ensureProgress(source, token: token)
        }
        return DestinationConfiguration(
            databaseID: normalizedDatabaseID,
            dataSourceID: source.id,
            dataSourceName: kind.title,
            propertyMap: try validateProperties(source.properties, kind: kind),
            validatedAt: dateProvider.now(),
            apiVersion: Self.apiVersion
        )
    }

    private func validateProperties(
        _ properties: [String: PropertySchema],
        kind: ManagedKind
    ) throws -> NotionPropertyMap {
        var required = [("Name", "title"), ("Source", "rich_text")]
        if kind == .tasks {
            required += [
                ("Due Date", "date"),
                ("Priority", "select"),
                ("Notes", "rich_text"),
                ("Progress", "select")
            ]
        }
        required += [
            ("Created Date", "created_time"),
            ("Done", "checkbox")
        ]

        var issues: [SchemaIssue] = []
        var references: [String: NotionPropertyReference] = [:]
        for (name, type) in required {
            guard let property = properties[name] else {
                issues.append(
                    SchemaIssue(
                        propertyName: name,
                        expectedType: type,
                        actualType: nil,
                        message: "\(kind.title) needs \(name) as \(type)."
                    )
                )
                continue
            }
            guard property.type == type else {
                issues.append(
                    SchemaIssue(
                        propertyName: name,
                        expectedType: type,
                        actualType: property.type,
                        message: "\(name) must be \(type)."
                    )
                )
                continue
            }
            references[name] = NotionPropertyReference(id: property.id, name: name)
        }

        if kind == .tasks, let priority = properties["Priority"] {
            let options = Set((priority.select?.options ?? []).map(\.name))
            for expected in ["Low", "Medium", "High"] where !options.contains(expected) {
                issues.append(
                    SchemaIssue(
                        propertyName: "Priority",
                        expectedType: "select",
                        actualType: "select",
                        message: "Priority needs the \(expected) option."
                    )
                )
            }
        }
        if kind == .tasks, let progress = properties["Progress"] {
            let options = Set((progress.select?.options ?? []).map(\.name))
            for expected in TaskProgress.allCases.map(\.displayName)
                where !options.contains(expected) {
                issues.append(
                    SchemaIssue(
                        propertyName: "Progress",
                        expectedType: "select",
                        actualType: "select",
                        message: "Progress needs the \(expected) option."
                    )
                )
            }
        }
        guard issues.isEmpty else {
            throw ClaspError.incompatibleSchema(issues)
        }
        return NotionPropertyMap(
            name: references["Name"]!,
            source: references["Source"]!,
            dueDate: references["Due Date"],
            priority: references["Priority"],
            notes: references["Notes"],
            progress: references["Progress"]
        )
    }

    private func retrieveAndEnsureManagedProperties(
        dataSourceID: String,
        token: String
    ) async throws -> DataSourceResponse {
        let response = try await send(
            method: .get,
            path: "data_sources/\(dataSourceID)",
            token: token
        )
        let source = try decoder.decode(DataSourceResponse.self, from: response.body)
        let withCreatedDate = try await ensureCreatedDate(source, token: token)
        return try await ensureDone(withCreatedDate, token: token)
    }

    private func ensureCreatedDate(
        _ source: DataSourceResponse,
        token: String
    ) async throws -> DataSourceResponse {
        if let createdDate = source.properties["Created Date"] {
            guard createdDate.type == "created_time" else {
                throw ClaspError.incompatibleSchema([
                    SchemaIssue(
                        propertyName: "Created Date",
                        expectedType: "created_time",
                        actualType: createdDate.type,
                        message: "Created Date must be created_time."
                    )
                ])
            }
            return source
        }

        let response = try await send(
            method: .patch,
            path: "data_sources/\(source.id)",
            token: token,
            body: try NotionPayloadBuilder.makeAddCreatedDatePropertyBody()
        )
        let updated = try decoder.decode(DataSourceResponse.self, from: response.body)
        guard updated.properties["Created Date"]?.type == "created_time" else {
            throw ClaspError.invalidResponse
        }
        return updated
    }

    private func ensureDone(
        _ source: DataSourceResponse,
        token: String
    ) async throws -> DataSourceResponse {
        if let done = source.properties["Done"] {
            guard done.type == "checkbox" else {
                throw ClaspError.incompatibleSchema([
                    SchemaIssue(
                        propertyName: "Done",
                        expectedType: "checkbox",
                        actualType: done.type,
                        message: "Done must be checkbox."
                    )
                ])
            }
            return source
        }

        let response = try await send(
            method: .patch,
            path: "data_sources/\(source.id)",
            token: token,
            body: try NotionPayloadBuilder.makeAddDonePropertyBody()
        )
        let updated = try decoder.decode(DataSourceResponse.self, from: response.body)
        guard updated.properties["Done"]?.type == "checkbox" else {
            throw ClaspError.invalidResponse
        }
        return updated
    }

    private func ensureProgress(
        _ source: DataSourceResponse,
        token: String
    ) async throws -> DataSourceResponse {
        if let progress = source.properties["Progress"] {
            guard progress.type == "select" else {
                throw ClaspError.incompatibleSchema([
                    SchemaIssue(
                        propertyName: "Progress",
                        expectedType: "select",
                        actualType: progress.type,
                        message: "Progress must be select."
                    )
                ])
            }
            let options = Set((progress.select?.options ?? []).map(\.name))
            let missing = TaskProgress.allCases.map(\.displayName).filter {
                !options.contains($0)
            }
            guard missing.isEmpty else {
                throw ClaspError.incompatibleSchema(
                    missing.map {
                        SchemaIssue(
                            propertyName: "Progress",
                            expectedType: "select",
                            actualType: "select",
                            message: "Progress needs the \($0) option."
                        )
                    }
                )
            }
            return source
        }

        let response = try await send(
            method: .patch,
            path: "data_sources/\(source.id)",
            token: token,
            body: try NotionPayloadBuilder.makeAddProgressPropertyBody()
        )
        let updated = try decoder.decode(DataSourceResponse.self, from: response.body)
        guard updated.properties["Progress"]?.type == "select" else {
            throw ClaspError.invalidResponse
        }
        return updated
    }

    private func project(
        _ page: QueryPage,
        type: CaptureType,
        propertyMap: NotionPropertyMap
    ) -> NotionListItem {
        let properties = page.properties
        func value(for reference: NotionPropertyReference) -> QueryPropertyValue? {
            properties[reference.name]
                ?? properties.values.first(where: { $0.id == reference.id })
        }

        let title = value(for: propertyMap.name)?.plainText ?? ""
        let source = value(for: propertyMap.source)?.plainText ?? ""
        let notes = propertyMap.notes
            .flatMap { value(for: $0)?.plainText } ?? ""
        let dueDate = propertyMap.dueDate
            .flatMap { value(for: $0)?.date?.start }
            .flatMap(parseNotionDate)
        let priority = propertyMap.priority
            .flatMap { value(for: $0)?.select?.name }
            .flatMap { TaskPriority(rawValue: $0.lowercased()) }
        let progressName = propertyMap.progress
            .flatMap { value(for: $0)?.select?.name }
            ?? properties["Progress"]?.select?.name
        let progress = progressName.flatMap(TaskProgress.init(rawValue:)) ?? .notStarted

        return NotionListItem(
            id: page.id,
            url: page.url.flatMap(URL.init(string:)),
            type: type,
            title: title,
            source: source,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            progress: progress,
            createdAt: parseNotionDate(page.createdTime),
            updatedAt: parseNotionDate(page.lastEditedTime)
        )
    }

    private func parseNotionDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func send(
        method: HTTPMethod,
        path: String,
        token: String,
        body: Data? = nil,
        ambiguousOnServerFailure: Bool = false
    ) async throws -> HTTPResponse {
        let request = HTTPRequest(
            method: method,
            url: baseURL.appendingPathComponent(path),
            headers: [
                "Authorization": "Bearer \(token)",
                "Notion-Version": Self.apiVersion,
                "Content-Type": "application/json"
            ],
            body: body
        )
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw classify(response, ambiguousOnServerFailure: ambiguousOnServerFailure)
        }
        return response
    }

    private func classify(
        _ response: HTTPResponse,
        ambiguousOnServerFailure: Bool
    ) -> ClaspError {
        switch response.statusCode {
        case 401: .authenticationFailed
        case 403: .accessDenied
        case 404: .destinationNotFound
        case 409, 502, 503, 504:
            .retryableServiceFailure(statusCode: response.statusCode)
        case 429, 529:
            .rateLimited(
                retryAfter: response.headers["retry-after"].flatMap(TimeInterval.init)
            )
        case 500 where ambiguousOnServerFailure: .ambiguousDelivery
        case 500: .retryableServiceFailure(statusCode: response.statusCode)
        default:
            .permanentServiceFailure(
                statusCode: response.statusCode,
                message: "Notion rejected the request. Recreate or revalidate Clasp databases."
            )
        }
    }

    private func normalizeIdentifier(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathCandidate = URL(string: trimmed)?.pathComponents.last ?? trimmed
        let hex = pathCandidate.filter(\.isHexDigit)
        guard hex.count >= 32 else {
            throw ClaspError.destinationNotFound
        }
        let compact = String(hex.suffix(32)).lowercased()
        let sections = [8, 4, 4, 4, 12]
        var index = compact.startIndex
        var values: [String] = []
        for length in sections {
            let end = compact.index(index, offsetBy: length)
            values.append(String(compact[index..<end]))
            index = end
        }
        return values.joined(separator: "-")
    }

    private func compactIdentifier(_ value: String) -> String {
        value.filter(\.isHexDigit).lowercased()
    }
}

private struct DatabaseResponse: Decodable {
    var id: String
    var dataSources: [NotionDataSourceSummary]

    enum CodingKeys: String, CodingKey {
        case id
        case dataSources = "data_sources"
    }
}

private struct CreatedDatabaseResponse: Decodable {
    var id: String
}

private struct DataSourceResponse: Decodable {
    var id: String
    var properties: [String: PropertySchema]
}

private struct PropertySchema: Decodable {
    var id: String
    var type: String
    var select: OptionContainer?
}

private struct OptionContainer: Decodable {
    var options: [PropertyOption]
}

private struct PropertyOption: Decodable {
    var name: String
}

private struct DatabaseSearchResponse: Decodable {
    var results: [DatabaseSearchResult]
}

private struct DatabaseSearchResult: Decodable {
    var id: String
    var parent: SearchParent
    var databaseParent: SearchParent?
    var title: [SearchTitle]

    enum CodingKeys: String, CodingKey {
        case id
        case parent
        case databaseParent = "database_parent"
        case title
    }

    var plainTitle: String {
        title.map(\.plainText).joined()
    }
}

private struct SearchParent: Decodable {
    var pageID: String?
    var databaseID: String?

    enum CodingKeys: String, CodingKey {
        case pageID = "page_id"
        case databaseID = "database_id"
    }
}

private struct SearchTitle: Decodable {
    var plainText: String

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
    }
}

private struct DataSourceQueryResponse: Decodable {
    var results: [QueryPage]
    var hasMore: Bool
    var nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

private struct QueryPage: Decodable {
    var id: String
    var url: String?
    var createdTime: String
    var lastEditedTime: String
    var properties: [String: QueryPropertyValue]

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case properties
    }
}

private struct QueryPropertyValue: Decodable {
    var id: String?
    var title: [QueryRichText]?
    var richText: [QueryRichText]?
    var date: QueryDate?
    var select: QuerySelect?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case richText = "rich_text"
        case date
        case select
    }

    var plainText: String {
        (title ?? richText ?? []).map(\.plainText).joined()
    }
}

private struct QueryRichText: Decodable {
    var plainText: String

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
    }
}

private struct QueryDate: Decodable {
    var start: String
}

private struct QuerySelect: Decodable {
    var name: String
}

private struct PageResponse: Decodable {
    var id: String
    var url: String?
}
