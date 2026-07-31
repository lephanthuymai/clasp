import Foundation
import Testing
@testable import ClaspCore

@Suite("Source location resolver")
struct SourceLocationResolverTests {
    @Test("Normalizes an absolute file path")
    func normalizesFilePath() throws {
        let url = try #require(SourceLocationResolver.normalize("/Users/test/Notes.md"))
        #expect(url.isFileURL)
        #expect(url.path == "/Users/test/Notes.md")
    }

    @Test("Prefers a Slack message permalink over a channel URL")
    func prefersSlackPermalink() throws {
        let channel = try #require(
            URL(string: "https://workspace.slack.com/archives/C123")
        )
        let message = try #require(
            URL(string: "https://workspace.slack.com/archives/C123/p1720000000000000")
        )

        #expect(
            SourceLocationResolver.bestURL(
                from: [channel, message],
                bundleIdentifier: "com.tinyspeck.slackmacgap"
            ) == message
        )
    }

    @Test("Prefers a Gmail thread URL over an unrelated browser link")
    func prefersGmailThread() throws {
        let unrelated = try #require(URL(string: "https://example.com"))
        let gmail = try #require(
            URL(string: "https://mail.google.com/mail/u/0/#inbox/FMfcgzExample")
        )

        #expect(
            SourceLocationResolver.bestURL(
                from: [unrelated, gmail],
                bundleIdentifier: "com.google.Chrome"
            ) == gmail
        )
    }
}
