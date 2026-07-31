import Foundation

public enum NotionPayloadBuilder {
    public static func makeCreateTasksDatabaseBody(parentPageID: String) throws -> Data {
        try makeCreateDatabaseBody(
            parentPageID: parentPageID,
            title: "Clasp Tasks",
            properties: [
                "Name": ["title": [:]],
                "Source": ["rich_text": [:]],
                "Due Date": ["date": [:]],
                "Priority": [
                    "select": [
                        "options": [
                            ["name": "Low", "color": "gray"],
                            ["name": "Medium", "color": "yellow"],
                            ["name": "High", "color": "red"]
                        ]
                    ]
                ],
                "Notes": ["rich_text": [:]],
                "Created Date": ["created_time": [:]],
                "Done": ["checkbox": [:]],
                "Progress": progressProperty()
            ]
        )
    }

    public static func makeCreateBookmarksDatabaseBody(parentPageID: String) throws -> Data {
        try makeCreateDatabaseBody(
            parentPageID: parentPageID,
            title: "Clasp Bookmarks",
            properties: [
                "Name": ["title": [:]],
                "Source": ["rich_text": [:]],
                "Created Date": ["created_time": [:]],
                "Done": ["checkbox": [:]]
            ]
        )
    }

    public static func makeDatabaseSearchBody(title: String) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "query": title,
                "filter": ["property": "object", "value": "data_source"],
                "page_size": 100
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeDataSourceQueryBody(startCursor: String? = nil) throws -> Data {
        var body: [String: Any] = [
            "page_size": 100,
            "filter": [
                "property": "Done",
                "checkbox": ["equals": false]
            ],
            "sorts": [[
                "timestamp": "created_time",
                "direction": "descending"
            ]]
        ]
        if let startCursor {
            body["start_cursor"] = startCursor
        }
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    public static func makeCreatePageBody(
        capture: Capture,
        destination: DestinationConfiguration
    ) throws -> Data {
        let map = destination.propertyMap
        var properties: [String: Any] = [
            map.name.id: ["title": try richText(capture.title)],
            map.source.id: ["rich_text": try sourceRichText(capture.source.sourceURL)],
            "Done": ["checkbox": false]
        ]

        if capture.type == .task {
            guard let dueDateProperty = map.dueDate,
                  let priorityProperty = map.priority,
                  let notesProperty = map.notes
            else {
                throw ClaspError.incompatibleSchema([])
            }
            properties[notesProperty.id] = ["rich_text": try richText(capture.body)]
            let dueDateValue: Any = capture.dueDate
                .map { ["start": dateOnly($0)] }
                ?? NSNull()
            let priorityValue: Any = capture.priority
                .map { ["name": $0.displayName] }
                ?? NSNull()
            properties[dueDateProperty.id] = ["date": dueDateValue]
            properties[priorityProperty.id] = ["select": priorityValue]
            properties[map.progress?.id ?? "Progress"] = [
                "select": ["name": TaskProgress.notStarted.displayName]
            ]
        }

        return try JSONSerialization.data(
            withJSONObject: [
                "parent": [
                    "type": "data_source_id",
                    "data_source_id": destination.dataSourceID
                ],
                "properties": properties
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeAddDonePropertyBody() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "properties": ["Done": ["checkbox": [:]]]
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeAddCreatedDatePropertyBody() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "properties": ["Created Date": ["created_time": [:]]]
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeAddProgressPropertyBody() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "properties": ["Progress": progressProperty()]
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeSetDoneBody() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "properties": ["Done": ["checkbox": true]]
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeTrashPageBody() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: ["in_trash": true],
            options: [.sortedKeys]
        )
    }

    public static func makeSetTaskPriorityBody(
        _ priority: TaskPriority,
        destination: DestinationConfiguration
    ) throws -> Data {
        guard let property = destination.propertyMap.priority else {
            throw ClaspError.incompatibleSchema([])
        }
        return try JSONSerialization.data(
            withJSONObject: [
                "properties": [
                    property.id: ["select": ["name": priority.displayName]]
                ]
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeSetTaskDueDateBody(
        _ dueDate: Date?,
        destination: DestinationConfiguration
    ) throws -> Data {
        guard let property = destination.propertyMap.dueDate else {
            throw ClaspError.incompatibleSchema([])
        }
        let date: Any = dueDate.map { ["start": dateOnly($0)] } ?? NSNull()
        return try JSONSerialization.data(
            withJSONObject: [
                "properties": [
                    property.id: ["date": date]
                ]
            ],
            options: [.sortedKeys]
        )
    }

    public static func makeSetTaskProgressBody(
        _ progress: TaskProgress,
        propertyID: String
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "properties": [
                    propertyID: ["select": ["name": progress.displayName]]
                ]
            ],
            options: [.sortedKeys]
        )
    }

    private static func makeCreateDatabaseBody(
        parentPageID: String,
        title: String,
        properties: [String: Any]
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "parent": ["type": "page_id", "page_id": parentPageID],
                "title": [[
                    "type": "text",
                    "text": ["content": title]
                ]],
                "is_inline": false,
                "initial_data_source": ["properties": properties]
            ],
            options: [.sortedKeys]
        )
    }

    private static func progressProperty() -> [String: Any] {
        [
            "select": [
                "options": [
                    ["name": TaskProgress.notStarted.displayName, "color": "gray"],
                    ["name": TaskProgress.working.displayName, "color": "blue"],
                    ["name": TaskProgress.waiting.displayName, "color": "yellow"],
                    ["name": TaskProgress.completed.displayName, "color": "green"],
                    ["name": TaskProgress.failed.displayName, "color": "red"]
                ]
            ]
        ]
    }

    private static func sourceRichText(_ url: URL?) throws -> [[String: Any]] {
        guard let url else { return [] }
        if url.isFileURL {
            return try richText(url.path)
        }
        let value = url.absoluteString
        return [[
            "type": "text",
            "text": [
                "content": String(value.prefix(2_000)),
                "link": ["url": String(value.prefix(2_000))]
            ]
        ]]
    }

    private static func richText(_ text: String) throws -> [[String: Any]] {
        var remaining = text[...]
        var result: [[String: Any]] = []
        while !remaining.isEmpty {
            guard result.count < 100 else {
                throw ClaspError.contentTooLong
            }
            let end = remaining.index(
                remaining.startIndex,
                offsetBy: min(2_000, remaining.count)
            )
            result.append([
                "type": "text",
                "text": ["content": String(remaining[..<end])]
            ])
            remaining = remaining[end...]
        }
        return result
    }

    private static func dateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
