import ClaspCore
import Foundation
import Testing

@Suite("Codex task handoff")
struct CodexTaskHandoffTests {
    @Test("Includes the Notion task link and keeps Done separate from Progress")
    func buildsLifecycleAwarePrompt() {
        let item = NotionListItem(
            id: "2ab1cf9f-0000-0000-0000-000000000000",
            url: URL(string: "https://www.notion.so/2ab1cf9f000000000000000000000000"),
            type: .task,
            title: "Review environment cleanup",
            source: "https://mail.google.com/example",
            notes: "Prepare a customer-facing response",
            priority: .high
        )

        let prompt = CodexTaskHandoff.prompt(
            for: item,
            instruction: "Check the implementation"
        )

        #expect(prompt.contains("Notion task: https://www.notion.so/2ab1cf9f000000000000000000000000"))
        #expect(prompt.contains("Do not change the Notion Done checkbox"))
        #expect(prompt.contains(CodexTaskOutcome.completed.marker))
        #expect(prompt.contains(CodexTaskOutcome.waiting.marker))
        #expect(prompt.contains(CodexTaskOutcome.failed.marker))
    }

    @Test("Recognizes only an explicit completion declaration")
    func parsesExplicitOutcome() {
        #expect(CodexTaskOutcome.declared(in: "Work finished.") == nil)
        #expect(CodexTaskOutcome.declared(
            in: "Work finished.\n\(CodexTaskOutcome.completed.marker)"
        ) == .completed)
        #expect(CodexTaskOutcome.declared(
            in: "I need access.\n\(CodexTaskOutcome.waiting.marker)"
        ) == .waiting)
    }
}
