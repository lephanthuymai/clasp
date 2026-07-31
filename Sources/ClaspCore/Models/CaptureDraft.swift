import Foundation

public struct CaptureDraft: Equatable, Sendable {
    public var title: String
    public var body: String
    public var type: CaptureType
    public var source: SourceContext
    public var dueDate: Date?
    public var priority: TaskPriority?
    public var tags: [String]

    public init(
        title: String = "",
        body: String = "",
        type: CaptureType = .task,
        source: SourceContext = .unknown,
        dueDate: Date? = nil,
        priority: TaskPriority? = .medium,
        tags: [String] = []
    ) {
        self.title = title
        self.body = body
        self.type = type
        self.source = source
        self.dueDate = dueDate
        self.priority = priority
        self.tags = tags
    }

    public func makeCapture(id: UUID, now: Date) throws -> Capture {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw ClaspError.invalidTitle
        }
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type == .bookmark || !normalizedBody.isEmpty else {
            throw ClaspError.invalidBody
        }

        var seen = Set<String>()
        let normalizedTags = tags.compactMap { tag -> String? in
            let value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }

        return Capture(
            id: id,
            title: String(normalizedTitle.prefix(2_000)),
            body: normalizedBody,
            type: type,
            source: source,
            dueDate: type == .task ? dueDate : nil,
            priority: type == .task ? priority : nil,
            tags: Array(normalizedTags.prefix(100)),
            createdAt: now,
            updatedAt: now
        )
    }

    public static func suggestedTitle(from text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        return String(firstLine.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
    }

    public static func parseTags(_ text: String) -> [String] {
        text.split(separator: ",").map(String.init)
    }
}
