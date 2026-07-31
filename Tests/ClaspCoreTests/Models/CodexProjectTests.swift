import ClaspCore
import Foundation
import Testing

@Suite("Codex project catalog")
struct CodexProjectTests {
    @Test("Keeps the default first and deduplicates discovered project folders")
    func buildsProjectOptions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultProject = root.appendingPathComponent(
            "truetest-pm-agenthub",
            isDirectory: true
        )
        let anotherProject = root.appendingPathComponent("another-project", isDirectory: true)
        try FileManager.default.createDirectory(
            at: defaultProject,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: anotherProject,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let options = CodexProjectCatalog.options(
            defaultPath: defaultProject.path,
            discoveredPaths: [
                anotherProject.path,
                defaultProject.path,
                root.appendingPathComponent("missing").path
            ]
        )

        #expect(options.map(\.path) == [defaultProject.path, anotherProject.path])
        #expect(options.map(\.name) == ["truetest-pm-agenthub", "another-project"])
    }
}
