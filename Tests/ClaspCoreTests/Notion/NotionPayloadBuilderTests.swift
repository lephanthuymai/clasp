import Foundation
import Testing
@testable import ClaspCore

@Suite("Notion payload builder")
struct NotionPayloadBuilderTests {
    @Test("Builds the requested Tasks database schema")
    func createsTasksDatabase() throws {
        let data = try NotionPayloadBuilder.makeCreateTasksDatabaseBody(
            parentPageID: "parent-id"
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let initial = try #require(root["initial_data_source"] as? [String: Any])
        let properties = try #require(initial["properties"] as? [String: Any])
        #expect(Set(properties.keys)
            == [
                "Name", "Source", "Due Date", "Priority", "Notes",
                "Created Date", "Done", "Progress"
            ])
        let createdDate = try #require(properties["Created Date"] as? [String: Any])
        #expect(createdDate["created_time"] != nil)
        let progress = try #require(properties["Progress"] as? [String: Any])
        let select = try #require(progress["select"] as? [String: Any])
        let options = try #require(select["options"] as? [[String: Any]])
        #expect(options.compactMap { $0["name"] as? String }
            == TaskProgress.allCases.map(\.displayName))
    }

    @Test("Builds the requested Bookmarks database schema")
    func createsBookmarksDatabase() throws {
        let data = try NotionPayloadBuilder.makeCreateBookmarksDatabaseBody(
            parentPageID: "parent-id"
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let initial = try #require(root["initial_data_source"] as? [String: Any])
        let properties = try #require(initial["properties"] as? [String: Any])
        #expect(Set(properties.keys) == ["Name", "Source", "Created Date", "Done"])
    }

    @Test("Searches current Notion data source objects")
    func searchesDataSources() throws {
        let data = try NotionPayloadBuilder.makeDatabaseSearchBody(title: "Clasp Tasks")
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let filter = try #require(root["filter"] as? [String: Any])
        #expect(filter["property"] as? String == "object")
        #expect(filter["value"] as? String == "data_source")
    }

    @Test("Builds a paginated newest-first data source query")
    func queriesDataSource() throws {
        let data = try NotionPayloadBuilder.makeDataSourceQueryBody(
            startCursor: "next-page"
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(root["page_size"] as? Int == 100)
        #expect(root["start_cursor"] as? String == "next-page")
        let sorts = try #require(root["sorts"] as? [[String: Any]])
        #expect(sorts.first?["timestamp"] as? String == "created_time")
        #expect(sorts.first?["direction"] as? String == "descending")
        let filter = try #require(root["filter"] as? [String: Any])
        #expect(filter["property"] as? String == "Done")
        let checkbox = try #require(filter["checkbox"] as? [String: Any])
        #expect(checkbox["equals"] as? Bool == false)
    }

    @Test("Builds mapped task field updates")
    func updatesTaskFields() throws {
        let destination = fixtureDestination(type: .task)
        let priorityData = try NotionPayloadBuilder.makeSetTaskPriorityBody(
            .high,
            destination: destination
        )
        let priorityRoot = try #require(
            JSONSerialization.jsonObject(with: priorityData) as? [String: Any]
        )
        let priorityProperties = try #require(
            priorityRoot["properties"] as? [String: Any]
        )
        let priorityProperty = try #require(
            priorityProperties["priority-id"] as? [String: Any]
        )
        let select = try #require(priorityProperty["select"] as? [String: Any])
        #expect(select["name"] as? String == "High")

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dueDateData = try NotionPayloadBuilder.makeSetTaskDueDateBody(
            date,
            destination: destination
        )
        let dueDateRoot = try #require(
            JSONSerialization.jsonObject(with: dueDateData) as? [String: Any]
        )
        let dueDateProperties = try #require(
            dueDateRoot["properties"] as? [String: Any]
        )
        let dueDateProperty = try #require(
            dueDateProperties["due-id"] as? [String: Any]
        )
        let notionDate = try #require(dueDateProperty["date"] as? [String: Any])
        #expect(notionDate["start"] as? String == "2023-11-14")

        let clearData = try NotionPayloadBuilder.makeSetTaskDueDateBody(
            nil,
            destination: destination
        )
        let clearRoot = try #require(
            JSONSerialization.jsonObject(with: clearData) as? [String: Any]
        )
        let clearProperties = try #require(
            clearRoot["properties"] as? [String: Any]
        )
        let clearProperty = try #require(clearProperties["due-id"] as? [String: Any])
        #expect(clearProperty["date"] is NSNull)

        let progressData = try NotionPayloadBuilder.makeSetTaskProgressBody(
            .completed,
            propertyID: "progress-id"
        )
        let progressRoot = try #require(
            JSONSerialization.jsonObject(with: progressData) as? [String: Any]
        )
        let progressProperties = try #require(
            progressRoot["properties"] as? [String: Any]
        )
        let progressProperty = try #require(
            progressProperties["progress-id"] as? [String: Any]
        )
        let progressSelect = try #require(progressProperty["select"] as? [String: Any])
        #expect(progressSelect["name"] as? String == "Completed")
    }

    @Test("Builds managed Created Date migration and page trash payloads")
    func buildsCreatedDateAndTrashPayloads() throws {
        let createdData = try NotionPayloadBuilder.makeAddCreatedDatePropertyBody()
        let createdRoot = try #require(
            JSONSerialization.jsonObject(with: createdData) as? [String: Any]
        )
        let createdProperties = try #require(
            createdRoot["properties"] as? [String: Any]
        )
        let createdDate = try #require(
            createdProperties["Created Date"] as? [String: Any]
        )
        #expect(createdDate["created_time"] != nil)

        let trashData = try NotionPayloadBuilder.makeTrashPageBody()
        let trashRoot = try #require(
            JSONSerialization.jsonObject(with: trashData) as? [String: Any]
        )
        #expect(trashRoot["in_trash"] as? Bool == true)
    }

    @Test("Routes task fields and links a web source")
    func createsTaskPagePayload() throws {
        let capture = Capture(
            id: UUID(),
            title: "Follow up",
            body: "Reply tomorrow",
            type: .task,
            source: SourceContext(
                applicationName: "Safari",
                sourceURL: URL(string: "https://mail.google.com/mail/u/0/#inbox/thread")
            ),
            dueDate: Date(timeIntervalSince1970: 1_700_000_000),
            priority: .high,
            createdAt: Date(),
            updatedAt: Date()
        )

        let data = try NotionPayloadBuilder.makeCreatePageBody(
            capture: capture,
            destination: fixtureDestination(type: .task)
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let parent = try #require(root["parent"] as? [String: Any])
        #expect(parent["data_source_id"] as? String == "task-data-source-id")
        let properties = try #require(root["properties"] as? [String: Any])
        #expect(Set(properties.keys)
            == [
                "title-id", "source-id", "due-id", "priority-id", "notes-id",
                "progress-id", "Done"
            ])
        let done = try #require(properties["Done"] as? [String: Any])
        #expect(done["checkbox"] as? Bool == false)
        let progress = try #require(properties["progress-id"] as? [String: Any])
        let progressSelect = try #require(progress["select"] as? [String: Any])
        #expect(progressSelect["name"] as? String == "Not Started")
        let source = try #require(properties["source-id"] as? [String: Any])
        let sourceText = try #require(source["rich_text"] as? [[String: Any]])
        let text = try #require(sourceText.first?["text"] as? [String: Any])
        #expect((text["link"] as? [String: Any])?["url"] as? String
            == "https://mail.google.com/mail/u/0/#inbox/thread")
    }

    @Test("Writes file source as a plain path")
    func createsBookmarkPagePayload() throws {
        let capture = Capture(
            id: UUID(),
            title: "Local reference",
            body: "",
            type: .bookmark,
            source: SourceContext(
                applicationName: "Preview",
                sourceURL: URL(fileURLWithPath: "/Users/test/Document.pdf")
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
        let data = try NotionPayloadBuilder.makeCreatePageBody(
            capture: capture,
            destination: fixtureDestination(type: .bookmark)
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let properties = try #require(root["properties"] as? [String: Any])
        #expect(Set(properties.keys) == ["bookmark-title-id", "bookmark-source-id", "Done"])
        let source = try #require(properties["bookmark-source-id"] as? [String: Any])
        let sourceText = try #require(source["rich_text"] as? [[String: Any]])
        let text = try #require(sourceText.first?["text"] as? [String: Any])
        #expect(text["content"] as? String == "/Users/test/Document.pdf")
        #expect(text["link"] == nil)
    }

    @Test("Splits task notes at Notion's 2,000-character limit")
    func splitsLongRichText() throws {
        let capture = Capture(
            id: UUID(),
            title: "Long",
            body: String(repeating: "x", count: 2_001),
            type: .task,
            source: .unknown,
            createdAt: Date(),
            updatedAt: Date()
        )
        let data = try NotionPayloadBuilder.makeCreatePageBody(
            capture: capture,
            destination: fixtureDestination(type: .task)
        )
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let properties = try #require(root["properties"] as? [String: Any])
        let notes = try #require(properties["notes-id"] as? [String: Any])
        let richText = try #require(notes["rich_text"] as? [[String: Any]])
        #expect(richText.count == 2)
    }
}
