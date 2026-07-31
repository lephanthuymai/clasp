import Foundation

public actor DeliveryCoordinator {
    private let repository: any CaptureRepository
    private let captureService: CaptureService

    public init(
        repository: any CaptureRepository,
        captureService: CaptureService
    ) {
        self.repository = repository
        self.captureService = captureService
    }

    @discardableResult
    public func recoverInterruptedDeliveries() async throws -> [Capture] {
        var document = try await repository.load()
        var changed = false
        for index in document.captures.indices
        where document.captures[index].delivery == .delivering {
            document.captures[index].delivery = .pending
            changed = true
        }
        if changed {
            try await repository.save(document)
        }
        return document.captures
    }

    public func retry(id: UUID) async throws -> Capture {
        let document = try await repository.load()
        guard var capture = document.captures.first(where: { $0.id == id }) else {
            throw ClaspError.destinationNotFound
        }
        guard capture.delivery != .delivered else {
            return capture
        }
        capture.delivery = .pending
        try await repository.upsert(capture)
        return await captureService.attemptDelivery(capture)
    }

    public func retryAll() async throws -> [Capture] {
        let document = try await repository.load()
        var results: [Capture] = []
        for capture in document.captures
        where capture.delivery == .pending || capture.delivery == .failed {
            results.append(try await retry(id: capture.id))
        }
        return results
    }

    public func delete(id: UUID) async throws {
        try await repository.deleteCapture(id: id)
    }
}
