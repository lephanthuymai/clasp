import Foundation

public enum SelectionFailureReason: String, Equatable, Sendable {
    case permissionDenied
    case noSelection
    case unsupported
    case sourceUnresponsive
}

public enum SelectionOutcome: Equatable, Sendable {
    case success(text: String, source: SourceContext)
    case unavailable(reason: SelectionFailureReason, source: SourceContext)
}

public enum CapturePreparationNotice: Equatable, Sendable {
    case permissionDenied
    case noSelection
    case unsupported
    case sourceUnresponsive

    public var message: String {
        switch self {
        case .permissionDenied:
            "Clasp needs Accessibility access to read the selection. You can still type or paste explicitly."
        case .noSelection:
            "No selected text was available. Type content or choose Paste."
        case .unsupported:
            "This app did not expose its selected text. Type content or choose Paste."
        case .sourceUnresponsive:
            "The source app did not respond. Try again, type content, or choose Paste."
        }
    }
}

public struct PreparedCapture: Equatable, Sendable {
    public var draft: CaptureDraft
    public var notice: CapturePreparationNotice?

    public init(draft: CaptureDraft, notice: CapturePreparationNotice?) {
        self.draft = draft
        self.notice = notice
    }
}

public enum CapturePreparation {
    public static func prepare(from outcome: SelectionOutcome) -> PreparedCapture {
        switch outcome {
        case let .success(text, source):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return PreparedCapture(
                    draft: CaptureDraft(source: source),
                    notice: .noSelection
                )
            }
            return PreparedCapture(
                draft: CaptureDraft(
                    title: CaptureDraft.suggestedTitle(from: trimmed),
                    body: trimmed,
                    source: source
                ),
                notice: nil
            )
        case let .unavailable(reason, source):
            let notice: CapturePreparationNotice = switch reason {
            case .permissionDenied: .permissionDenied
            case .noSelection: .noSelection
            case .unsupported: .unsupported
            case .sourceUnresponsive: .sourceUnresponsive
            }
            return PreparedCapture(
                draft: CaptureDraft(source: source),
                notice: notice
            )
        }
    }
}
