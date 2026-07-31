import ClaspCore
import Foundation
import Testing

@Suite("Notion list item ordering")
struct NotionListItemOrderingTests {
    @Test("Sorts tasks by priority and then earliest due date")
    func sortsTasks() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let items = [
            task("low", priority: .low, dueDate: now),
            task("medium-later", priority: .medium, dueDate: now.addingTimeInterval(86_400)),
            task("high-undated", priority: .high),
            task("none", priority: nil, dueDate: now),
            task("high-sooner", priority: .high, dueDate: now),
            task("medium-sooner", priority: .medium, dueDate: now)
        ]

        let sorted = NotionListItemOrdering.tasksByPriorityAndDueDate(items)

        #expect(sorted.map(\.id) == [
            "high-sooner", "high-undated",
            "medium-sooner", "medium-later",
            "low", "none"
        ])
    }

    @Test("Preserves source order when priority and due date match")
    func preservesTieOrder() {
        let items = [
            task("first", priority: .medium),
            task("second", priority: .medium)
        ]

        let sorted = NotionListItemOrdering.tasksByPriorityAndDueDate(items)

        #expect(sorted.map(\.id) == ["first", "second"])
    }

    private func task(
        _ id: String,
        priority: TaskPriority?,
        dueDate: Date? = nil
    ) -> NotionListItem {
        NotionListItem(
            id: id,
            url: nil,
            type: .task,
            title: id,
            source: "",
            dueDate: dueDate,
            priority: priority
        )
    }
}
