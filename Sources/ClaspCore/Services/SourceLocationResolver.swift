import Foundation

public enum SourceLocationResolver {
    public static func normalize(_ rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value)
        }
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        guard ["https", "http", "file", "slack"].contains(scheme) else {
            return nil
        }
        return url
    }

    public static func bestURL(
        from candidates: [URL],
        bundleIdentifier: String?
    ) -> URL? {
        candidates.enumerated().max {
            score($0.element, bundleIdentifier: bundleIdentifier, order: $0.offset)
                < score($1.element, bundleIdentifier: bundleIdentifier, order: $1.offset)
        }?.element
    }

    public static func isSlackPermalink(_ url: URL) -> Bool {
        if url.scheme?.lowercased() == "slack" {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.contains(where: { $0.name == "message" }) == true
        }
        guard url.host?.lowercased().hasSuffix("slack.com") == true else {
            return false
        }
        let components = url.pathComponents
        return components.contains("archives")
            && components.contains(where: {
                $0.first == "p" && $0.dropFirst().allSatisfy(\.isNumber)
            })
    }

    private static func score(
        _ url: URL,
        bundleIdentifier: String?,
        order: Int
    ) -> Int {
        var value = max(0, 20 - order)
        let host = url.host?.lowercased() ?? ""
        if isSlackPermalink(url) {
            value += 200
        } else if host.hasSuffix("slack.com") {
            value += 90
        }
        if host == "mail.google.com" {
            value += 180
        }
        if url.isFileURL {
            value += 150
        }
        if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            value += 70
        }
        if bundleIdentifier == "com.tinyspeck.slackmacgap", isSlackPermalink(url) {
            value += 30
        }
        return value
    }
}
