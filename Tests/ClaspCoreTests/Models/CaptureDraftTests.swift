import Foundation
import Testing
@testable import ClaspCore

@Suite("Capture draft")
struct CaptureDraftTests {
    @Test("Normalizes whitespace, tags, and bookmark due date")
    func normalizesDraft() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let draft = CaptureDraft(
            title: "  Read this  ",
            body: "\nSelected body\n",
            type: .bookmark,
            source: SourceContext(applicationName: "Safari"),
            dueDate: date,
            tags: [" Research ", "research", "", "Read later"]
        )

        let capture = try draft.makeCapture(id: UUID(), now: date)
        #expect(capture.title == "Read this")
        #expect(capture.body == "Selected body")
        #expect(capture.tags == ["Research", "Read later"])
        #expect(capture.dueDate == nil)
    }

    @Test("Rejects empty required fields")
    func rejectsEmptyFields() {
        #expect(throws: ClaspError.invalidTitle) {
            try CaptureDraft(title: " ", body: "Body").makeCapture(id: UUID(), now: Date())
        }
        #expect(throws: ClaspError.invalidBody) {
            try CaptureDraft(title: "Title", body: "\n").makeCapture(id: UUID(), now: Date())
        }
    }

    @Test("Suggests a short title from the first non-empty line")
    func suggestsTitle() {
        let title = CaptureDraft.suggestedTitle(from: "\n  A useful selection\nMore")
        #expect(title == "A useful selection")
    }
}
