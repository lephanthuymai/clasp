import Foundation

public actor CaptureService {
    private let repository: any CaptureRepository
    private let credentialStore: any CredentialStore
    private let notion: any NotionServicing
    private let dateProvider: any DateProviding
    private let uuidProvider: any UUIDProviding

    public init(
        repository: any CaptureRepository,
        credentialStore: any CredentialStore,
        notion: any NotionServicing,
        dateProvider: any DateProviding = SystemDateProvider(),
        uuidProvider: any UUIDProviding = SystemUUIDProvider()
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
        self.notion = notion
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
    }

    public func confirm(_ draft: CaptureDraft) async throws -> Capture {
        let capture = try await enqueue(draft)
        return await attemptDelivery(capture)
    }

    public func enqueue(_ draft: CaptureDraft) async throws -> Capture {
        let capture = try draft.makeCapture(
            id: uuidProvider.makeUUID(),
            now: dateProvider.now()
        )
        try await repository.upsert(capture)
        return capture
    }

    public func attemptDelivery(_ original: Capture) async -> Capture {
        var capture = original
        let start = dateProvider.now()
        capture.delivery = .delivering
        capture.updatedAt = start
        try? await repository.upsert(capture)

        do {
            let document = try await repository.load()
            guard let destinations = document.destinations else {
                throw ClaspError.destinationNotConfigured
            }
            let destination = destinations.destination(for: capture.type)
            guard let token = try await credentialStore.readToken(), !token.isEmpty else {
                throw ClaspError.credentialNotFound
            }
            let page = try await notion.deliver(
                capture,
                destination: destination,
                token: token
            )
            capture.delivery = .delivered
            capture.remotePageID = page.id
            capture.remotePageURL = page.url
            capture.updatedAt = dateProvider.now()
            capture.attempts.append(
                DeliveryAttempt(
                    startedAt: start,
                    finishedAt: capture.updatedAt,
                    outcome: .delivered
                )
            )
        } catch {
            let claspError = (error as? ClaspError)
                ?? .transportFailure(message: "Delivery failed.")
            let retryable = isRetryable(claspError)
            capture.delivery = retryable ? .pending : .failed
            capture.updatedAt = dateProvider.now()
            capture.attempts.append(
                DeliveryAttempt(
                    startedAt: start,
                    finishedAt: capture.updatedAt,
                    outcome: retryable ? .retryableFailure : .permanentFailure,
                    statusCode: statusCode(for: claspError),
                    safeMessage: claspError.localizedDescription
                )
            )
        }

        capture.attempts = Array(capture.attempts.suffix(20))
        try? await repository.upsert(capture)
        return capture
    }

    private func isRetryable(_ error: ClaspError) -> Bool {
        switch error {
        case .rateLimited, .retryableServiceFailure, .transportFailure, .ambiguousDelivery:
            true
        default:
            false
        }
    }

    private func statusCode(for error: ClaspError) -> Int? {
        switch error {
        case let .retryableServiceFailure(statusCode):
            statusCode
        case let .permanentServiceFailure(statusCode, _):
            statusCode
        default:
            nil
        }
    }
}
