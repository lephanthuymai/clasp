import Testing
@testable import ClaspCore

@Suite("Capture preparation")
struct CapturePreparationTests {
    @Test("Maps selected text into an editable draft")
    func mapsSelection() {
        let source = SourceContext(applicationName: "Safari")
        let prepared = CapturePreparation.prepare(
            from: .success(text: "\nUseful text\nMore", source: source)
        )
        #expect(prepared.draft.title == "Useful text")
        #expect(prepared.draft.body == "Useful text\nMore")
        #expect(prepared.draft.source == source)
        #expect(prepared.notice == nil)
    }

    @Test(
        "Maps each unavailable result to an empty transparent fallback",
        arguments: [
            SelectionFailureReason.permissionDenied,
            .noSelection,
            .unsupported,
            .sourceUnresponsive
        ]
    )
    func mapsUnavailable(reason: SelectionFailureReason) {
        let prepared = CapturePreparation.prepare(
            from: .unavailable(reason: reason, source: .unknown)
        )
        #expect(prepared.draft.body.isEmpty)
        #expect(prepared.notice != nil)
    }
}
