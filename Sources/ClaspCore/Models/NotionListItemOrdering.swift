import Foundation

public enum NotionListItemOrdering {
    public static func tasksByPriorityAndDueDate(
        _ items: [NotionListItem]
    ) -> [NotionListItem] {
        items.enumerated()
            .sorted { left, right in
                let leftPriority = priorityRank(left.element.priority)
                let rightPriority = priorityRank(right.element.priority)
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }

                switch (left.element.dueDate, right.element.dueDate) {
                case let (leftDate?, rightDate?) where leftDate != rightDate:
                    return leftDate < rightDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return left.offset < right.offset
                }
            }
            .map(\.element)
    }

    private static func priorityRank(_ priority: TaskPriority?) -> Int {
        switch priority {
        case .high: 0
        case .medium: 1
        case .low: 2
        case nil: 3
        }
    }
}
