import Foundation
import Testing
@testable import ClaspCore

actor QueueHTTPTransport: HTTPTransport {
    var responses: [Result<HTTPResponse, Error>]
    var requests: [HTTPRequest] = []

    init(_ responses: [Result<HTTPResponse, Error>]) {
        self.responses = responses
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw ClaspError.transportFailure(message: "No fixture response.")
        }
        return try responses.removeFirst().get()
    }

    func capturedRequests() -> [HTTPRequest] { requests }
}

@Suite("Notion client")
struct NotionClientTests {
    @Test("Creates and validates both managed databases")
    func provisionsDestinations() async throws {
        let transport = QueueHTTPTransport([
            .success(jsonResponse(#"{"id":"parent"}"#)),
            .success(jsonResponse(#"{"results":[]}"#)),
            .success(jsonResponse(taskDatabaseJSON)),
            .success(jsonResponse(taskDatabaseJSON)),
            .success(jsonResponse(taskDataSourceJSON)),
            .success(jsonResponse(#"{"results":[]}"#)),
            .success(jsonResponse(bookmarkDatabaseJSON)),
            .success(jsonResponse(bookmarkDatabaseJSON)),
            .success(jsonResponse(bookmarkDataSourceJSON))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!,
            dateProvider: FixedDateProvider(date: Date(timeIntervalSince1970: 1_700_000_000))
        )

        let destinations = try await client.provisionDestinations(
            parentPageID: "dddddddddddddddddddddddddddddddd",
            token: "ntn_test"
        )

        #expect(destinations.tasks.propertyMap.notes?.id == "notes-id")
        #expect(destinations.bookmarks.propertyMap.source.id == "bookmark-source-id")
        let requests = await transport.capturedRequests()
        #expect(requests.count == 9)
        #expect(requests.filter { $0.url.path.hasSuffix("/databases") }.count == 2)
        #expect(requests.allSatisfy { $0.headers["Notion-Version"] == "2026-03-11" })
    }

    @Test("Reuses an exact managed database under the parent page")
    func reusesExistingDatabase() async throws {
        let search = """
        {
          "results":[{
            "id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            "parent":{"type":"database_id","database_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"},
            "database_parent":{"type":"page_id","page_id":"dddddddd-dddd-dddd-dddd-dddddddddddd"},
            "title":[{"plain_text":"Clasp Tasks"}]
          }]
        }
        """
        let transport = QueueHTTPTransport([
            .success(jsonResponse(#"{"id":"parent"}"#)),
            .success(jsonResponse(search)),
            .success(jsonResponse(taskDatabaseJSON)),
            .success(jsonResponse(taskDataSourceJSON)),
            .success(jsonResponse(#"{"results":[]}"#)),
            .success(jsonResponse(bookmarkDatabaseJSON)),
            .success(jsonResponse(bookmarkDatabaseJSON)),
            .success(jsonResponse(bookmarkDataSourceJSON))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        _ = try await client.provisionDestinations(
            parentPageID: "dddddddddddddddddddddddddddddddd",
            token: "ntn_test"
        )

        let creates = await transport.capturedRequests().filter {
            $0.url.path.hasSuffix("/databases")
        }
        #expect(creates.count == 1)
    }

    @Test("Uses the current data source search filter")
    func usesCurrentSearchFilter() async throws {
        let transport = QueueHTTPTransport([
            .success(jsonResponse(#"{"id":"parent"}"#)),
            .success(jsonResponse(#"{"results":[]}"#)),
            .success(jsonResponse(taskDatabaseJSON)),
            .success(jsonResponse(taskDatabaseJSON)),
            .success(jsonResponse(taskDataSourceJSON)),
            .success(jsonResponse(#"{"results":[]}"#)),
            .success(jsonResponse(bookmarkDatabaseJSON)),
            .success(jsonResponse(bookmarkDatabaseJSON)),
            .success(jsonResponse(bookmarkDataSourceJSON))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        _ = try await client.provisionDestinations(
            parentPageID: "dddddddddddddddddddddddddddddddd",
            token: "ntn_test"
        )

        let searchRequests = await transport.capturedRequests().filter {
            $0.url.path.hasSuffix("/search")
        }
        #expect(searchRequests.count == 2)
        for request in searchRequests {
            let body = try #require(request.body)
            let root = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let filter = try #require(root["filter"] as? [String: Any])
            #expect(filter["value"] as? String == "data_source")
        }
    }

    @Test("Loads and projects task entries from a data source")
    func fetchesTaskItems() async throws {
        let response = """
        {
          "results":[{
            "id":"page-id",
            "url":"https://www.notion.so/page-id",
            "created_time":"2026-07-30T18:00:00.000Z",
            "last_edited_time":"2026-07-30T19:00:00.000Z",
            "properties":{
              "Name":{"id":"title-id","type":"title","title":[{"plain_text":"Follow up"}]},
              "Source":{"id":"source-id","type":"rich_text","rich_text":[{"plain_text":"https://example.com"}]},
              "Due Date":{"id":"due-id","type":"date","date":{"start":"2026-08-01"}},
              "Priority":{"id":"priority-id","type":"select","select":{"name":"High"}},
              "Notes":{"id":"notes-id","type":"rich_text","rich_text":[{"plain_text":"Call the team"}]},
              "Progress":{"id":"progress-id","type":"select","select":{"name":"Working"}}
            }
          }],
          "has_more":false,
          "next_cursor":null
        }
        """
        let transport = QueueHTTPTransport([
            .success(jsonResponse(taskDataSourceJSON)),
            .success(jsonResponse(response))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        let items = try await client.fetchItems(
            type: .task,
            destination: fixtureDestination(type: .task),
            token: "ntn_test"
        )

        #expect(items.count == 1)
        #expect(items[0].title == "Follow up")
        #expect(items[0].source == "https://example.com")
        #expect(items[0].notes == "Call the team")
        #expect(items[0].priority == .high)
        #expect(items[0].progress == .working)
        #expect(items[0].taskID == "CLASP-00000AED")
        #expect(items[0].dueDate != nil)
        let requests = await transport.capturedRequests()
        #expect(requests.last?.url.path
            == "/v1/data_sources/task-data-source-id/query")
    }

    @Test("Marks a Notion page done")
    func marksDone() async throws {
        let transport = QueueHTTPTransport([
            .success(jsonResponse(#"{"id":"dddddddd-dddd-dddd-dddd-dddddddddddd"}"#))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        try await client.markDone(
            pageID: "dddddddddddddddddddddddddddddddd",
            token: "ntn_test"
        )

        let request = try #require(await transport.capturedRequests().first)
        #expect(request.method == .patch)
        #expect(request.url.path
            == "/v1/pages/dddddddd-dddd-dddd-dddd-dddddddddddd")
        let body = try #require(request.body)
        let root = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let properties = try #require(root["properties"] as? [String: Any])
        let done = try #require(properties["Done"] as? [String: Any])
        #expect(done["checkbox"] as? Bool == true)
    }

    @Test("Moves a Notion page to Trash")
    func deletesPage() async throws {
        let transport = QueueHTTPTransport([
            .success(jsonResponse(#"{"id":"dddddddd-dddd-dddd-dddd-dddddddddddd","in_trash":true}"#))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        try await client.deletePage(
            pageID: "dddddddddddddddddddddddddddddddd",
            token: "ntn_test"
        )

        let request = try #require(await transport.capturedRequests().first)
        #expect(request.method == .patch)
        #expect(request.url.path
            == "/v1/pages/dddddddd-dddd-dddd-dddd-dddddddddddd")
        let body = try #require(request.body)
        let root = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(root["in_trash"] as? Bool == true)
    }

    @Test("Updates mapped task properties")
    func updatesTaskProperties() async throws {
        let transport = QueueHTTPTransport([
            .success(jsonResponse(#"{"id":"dddddddd-dddd-dddd-dddd-dddddddddddd"}"#)),
            .success(jsonResponse(#"{"id":"dddddddd-dddd-dddd-dddd-dddddddddddd"}"#)),
            .success(jsonResponse(taskDataSourceJSON)),
            .success(jsonResponse(#"{"id":"dddddddd-dddd-dddd-dddd-dddddddddddd"}"#))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )
        let destination = fixtureDestination(type: .task)

        try await client.updateTaskPriority(
            pageID: "dddddddddddddddddddddddddddddddd",
            destination: destination,
            priority: .low,
            token: "ntn_test"
        )
        try await client.updateTaskDueDate(
            pageID: "dddddddddddddddddddddddddddddddd",
            destination: destination,
            dueDate: nil,
            token: "ntn_test"
        )
        try await client.updateTaskProgress(
            pageID: "dddddddddddddddddddddddddddddddd",
            destination: destination,
            progress: .waiting,
            token: "ntn_test"
        )

        let requests = await transport.capturedRequests()
        #expect(requests.count == 4)
        #expect(requests.filter { $0.method == .patch }.count == 3)
        #expect([requests[0], requests[1], requests[3]].allSatisfy {
            $0.url.path == "/v1/pages/dddddddd-dddd-dddd-dddd-dddddddddddd"
        })

        let priorityBody = try #require(requests[0].body)
        let priorityRoot = try #require(
            JSONSerialization.jsonObject(with: priorityBody) as? [String: Any]
        )
        let priorityProperties = try #require(
            priorityRoot["properties"] as? [String: Any]
        )
        let priorityProperty = try #require(
            priorityProperties["priority-id"] as? [String: Any]
        )
        let select = try #require(priorityProperty["select"] as? [String: Any])
        #expect(select["name"] as? String == "Low")

        let dueDateBody = try #require(requests[1].body)
        let dueDateRoot = try #require(
            JSONSerialization.jsonObject(with: dueDateBody) as? [String: Any]
        )
        let dueDateProperties = try #require(
            dueDateRoot["properties"] as? [String: Any]
        )
        let dueDateProperty = try #require(
            dueDateProperties["due-id"] as? [String: Any]
        )
        #expect(dueDateProperty["date"] is NSNull)

        let progressBody = try #require(requests[3].body)
        let progressRoot = try #require(
            JSONSerialization.jsonObject(with: progressBody) as? [String: Any]
        )
        let progressProperties = try #require(
            progressRoot["properties"] as? [String: Any]
        )
        let progressProperty = try #require(
            progressProperties["progress-id"] as? [String: Any]
        )
        let progressSelect = try #require(progressProperty["select"] as? [String: Any])
        #expect(progressSelect["name"] as? String == "Waiting")
    }

    @Test("Adds Done to an existing managed data source before querying")
    func addsMissingDoneProperty() async throws {
        let withoutDone = """
        {
          "id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
          "properties":{
            "Name":{"id":"title-id","type":"title"},
            "Source":{"id":"source-id","type":"rich_text"},
            "Due Date":{"id":"due-id","type":"date"},
            "Priority":{"id":"priority-id","type":"select","select":{"options":[]}},
            "Notes":{"id":"notes-id","type":"rich_text"},
            "Created Date":{"id":"created-id","type":"created_time"}
          }
        }
        """
        let transport = QueueHTTPTransport([
            .success(jsonResponse(withoutDone)),
            .success(jsonResponse(taskDataSourceJSON)),
            .success(jsonResponse(
                #"{"results":[],"has_more":false,"next_cursor":null}"#
            ))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        _ = try await client.fetchItems(
            type: .task,
            destination: fixtureDestination(type: .task),
            token: "ntn_test"
        )

        let requests = await transport.capturedRequests()
        #expect(requests.count == 3)
        #expect(requests[1].method == .patch)
        #expect(requests[1].url.path
            == "/v1/data_sources/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
        let body = try #require(requests[1].body)
        let root = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let properties = try #require(root["properties"] as? [String: Any])
        #expect(properties["Done"] != nil)
    }

    @Test("Adds Created Date to an existing managed data source before querying")
    func addsMissingCreatedDateProperty() async throws {
        let withoutCreatedDate = """
        {
          "id":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
          "properties":{
            "Name":{"id":"bookmark-title-id","type":"title"},
            "Source":{"id":"bookmark-source-id","type":"rich_text"},
            "Done":{"id":"bookmark-done-id","type":"checkbox"}
          }
        }
        """
        let transport = QueueHTTPTransport([
            .success(jsonResponse(withoutCreatedDate)),
            .success(jsonResponse(bookmarkDataSourceJSON)),
            .success(jsonResponse(
                #"{"results":[],"has_more":false,"next_cursor":null}"#
            ))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        _ = try await client.fetchItems(
            type: .bookmark,
            destination: fixtureDestination(type: .bookmark),
            token: "ntn_test"
        )

        let requests = await transport.capturedRequests()
        #expect(requests.count == 3)
        #expect(requests[1].method == .patch)
        let body = try #require(requests[1].body)
        let root = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let properties = try #require(root["properties"] as? [String: Any])
        let createdDate = try #require(
            properties["Created Date"] as? [String: Any]
        )
        #expect(createdDate["created_time"] != nil)
    }

    @Test("Adds Progress to an existing Tasks data source before querying")
    func addsMissingProgressProperty() async throws {
        let withoutProgress = """
        {
          "id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
          "properties":{
            "Name":{"id":"title-id","type":"title"},
            "Source":{"id":"source-id","type":"rich_text"},
            "Due Date":{"id":"due-id","type":"date"},
            "Priority":{"id":"priority-id","type":"select","select":{"options":[
              {"name":"Low"},{"name":"Medium"},{"name":"High"}
            ]}},
            "Notes":{"id":"notes-id","type":"rich_text"},
            "Created Date":{"id":"created-id","type":"created_time"},
            "Done":{"id":"done-id","type":"checkbox"}
          }
        }
        """
        let transport = QueueHTTPTransport([
            .success(jsonResponse(withoutProgress)),
            .success(jsonResponse(taskDataSourceJSON)),
            .success(jsonResponse(
                #"{"results":[],"has_more":false,"next_cursor":null}"#
            ))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        _ = try await client.fetchItems(
            type: .task,
            destination: fixtureDestination(type: .task),
            token: "ntn_test"
        )

        let requests = await transport.capturedRequests()
        #expect(requests.count == 3)
        #expect(requests[1].method == .patch)
        let body = try #require(requests[1].body)
        let root = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let properties = try #require(root["properties"] as? [String: Any])
        let progress = try #require(properties["Progress"] as? [String: Any])
        let select = try #require(progress["select"] as? [String: Any])
        let options = try #require(select["options"] as? [[String: Any]])
        #expect(options.compactMap { $0["name"] as? String }
            == TaskProgress.allCases.map(\.displayName))
    }

    @Test("Reports incompatible managed schema")
    func reportsSchemaIssues() async {
        let invalid = """
        {
          "id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
          "properties":{
            "Name":{"id":"title-id","type":"rich_text"},
            "Created Date":{"id":"created-id","type":"created_time"},
            "Done":{"id":"done-id","type":"checkbox"},
            "Progress":{"id":"progress-id","type":"select","select":{"options":[
              {"name":"Not Started"},{"name":"Working"},{"name":"Waiting"},
              {"name":"Completed"},{"name":"Failed"}
            ]}}
          }
        }
        """
        let transport = QueueHTTPTransport([
            .success(jsonResponse(taskDatabaseJSON)),
            .success(jsonResponse(invalid))
        ])
        let client = NotionClient(
            transport: transport,
            baseURL: URL(string: "https://example.test/v1")!
        )

        do {
            _ = try await client.validateDestinations(
                fixtureDestinationsForValidation(),
                token: "ntn_test"
            )
            Issue.record("Expected schema issues")
        } catch let error as ClaspError {
            guard case let .incompatibleSchema(issues) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(issues.contains { $0.propertyName == "Name" })
            #expect(issues.contains { $0.propertyName == "Notes" })
        } catch {
            Issue.record("Unexpected error")
        }
    }
}

func jsonResponse(_ text: String, statusCode: Int = 200) -> HTTPResponse {
    HTTPResponse(statusCode: statusCode, body: Data(text.utf8))
}

private func fixtureDestinationsForValidation() -> DestinationSet {
    DestinationSet(
        parentPageID: "dddddddd-dddd-dddd-dddd-dddddddddddd",
        tasks: DestinationConfiguration(
            databaseID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            dataSourceID: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
            dataSourceName: "Clasp Tasks",
            propertyMap: fixtureTaskPropertyMap(),
            validatedAt: Date()
        ),
        bookmarks: DestinationConfiguration(
            databaseID: "cccccccc-cccc-cccc-cccc-cccccccccccc",
            dataSourceID: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
            dataSourceName: "Clasp Bookmarks",
            propertyMap: fixtureBookmarkPropertyMap(),
            validatedAt: Date()
        ),
        provisionedAt: Date()
    )
}

private let taskDatabaseJSON = """
{
  "id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "data_sources":[
    {"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","name":"Clasp Tasks"}
  ]
}
"""

private let bookmarkDatabaseJSON = """
{
  "id":"cccccccc-cccc-cccc-cccc-cccccccccccc",
  "data_sources":[
    {"id":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee","name":"Clasp Bookmarks"}
  ]
}
"""

private let taskDataSourceJSON = """
{
  "id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
  "properties":{
    "Name":{"id":"title-id","type":"title"},
    "Source":{"id":"source-id","type":"rich_text"},
    "Due Date":{"id":"due-id","type":"date"},
    "Priority":{"id":"priority-id","type":"select","select":{"options":[
      {"name":"Low"},{"name":"Medium"},{"name":"High"}
    ]}},
    "Notes":{"id":"notes-id","type":"rich_text"}
    ,"Created Date":{"id":"created-id","type":"created_time"}
    ,"Done":{"id":"done-id","type":"checkbox"}
    ,"Progress":{"id":"progress-id","type":"select","select":{"options":[
      {"name":"Not Started"},{"name":"Working"},{"name":"Waiting"},
      {"name":"Completed"},{"name":"Failed"}
    ]}}
  }
}
"""

private let bookmarkDataSourceJSON = """
{
  "id":"eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
  "properties":{
    "Name":{"id":"bookmark-title-id","type":"title"},
    "Source":{"id":"bookmark-source-id","type":"rich_text"}
    ,"Created Date":{"id":"bookmark-created-id","type":"created_time"}
    ,"Done":{"id":"bookmark-done-id","type":"checkbox"}
  }
}
"""
