import Foundation

enum ClaspPresentationMode: String, CaseIterable, Identifiable {
    case mini
    case medium
    case maximum

    private static let defaultsKey = "clasp.presentationMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mini: "Mini"
        case .medium: "Medium"
        case .maximum: "Maximum"
        }
    }

    var helpText: String {
        switch self {
        case .mini: "Menu bar only"
        case .medium: "Compact window"
        case .maximum: "Full-size window"
        }
    }

    static func saved(defaults: UserDefaults = .standard) -> ClaspPresentationMode {
        guard let rawValue = defaults.string(forKey: defaultsKey),
              let mode = ClaspPresentationMode(rawValue: rawValue) else {
            return .medium
        }
        return mode
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
