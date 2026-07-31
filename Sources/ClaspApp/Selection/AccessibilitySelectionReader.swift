import AppKit
import ApplicationServices
import ClaspCore
import Foundation

final class AccessibilitySelectionReader: SelectionReading, @unchecked Sendable {
    private struct SourceSnapshot: Sendable {
        var processIdentifier: pid_t
        var applicationName: String
        var bundleIdentifier: String?

        var context: SourceContext {
            SourceContext(
                applicationName: applicationName,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: processIdentifier
            )
        }
    }

    func readSelection() async -> SelectionOutcome {
        let snapshot = await MainActor.run {
            let app = NSWorkspace.shared.frontmostApplication
            return SourceSnapshot(
                processIdentifier: app?.processIdentifier ?? 0,
                applicationName: app?.localizedName ?? "Unknown Application",
                bundleIdentifier: app?.bundleIdentifier
            )
        }

        guard AXIsProcessTrusted() else {
            return .unavailable(reason: .permissionDenied, source: snapshot.context)
        }
        guard snapshot.processIdentifier != 0 else {
            return .unavailable(reason: .noSelection, source: snapshot.context)
        }

        let accessibilityOutcome = await Task.detached(priority: .userInitiated) {
            Self.readSelection(from: snapshot)
        }.value
        if case .success = accessibilityOutcome {
            return accessibilityOutcome
        }
        if let copiedText = await Self.copySelectedText(
            from: snapshot.processIdentifier
        ) {
            var source: SourceContext = switch accessibilityOutcome {
            case let .success(_, source), let .unavailable(_, source):
                source
            }
            if snapshot.bundleIdentifier == "com.tinyspeck.slackmacgap" {
                let processIdentifier = snapshot.processIdentifier
                source.sourceURL = await Task.detached(priority: .userInitiated) {
                    Self.slackMessageURL(
                        processIdentifier: processIdentifier,
                        matching: copiedText
                    )
                }.value ?? source.sourceURL
            }
            return .success(text: copiedText, source: source)
        }
        return accessibilityOutcome
    }

    @discardableResult
    static func requestPermissionPrompt() -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    private static func readSelection(from snapshot: SourceSnapshot) -> SelectionOutcome {
        let appElement = AXUIElementCreateApplication(snapshot.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.6)

        var focusedValue: CFTypeRef?
        let focusError = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusError == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            let reason: SelectionFailureReason = focusError == .cannotComplete
                ? .sourceUnresponsive
                : .unsupported
            return .unavailable(reason: reason, source: snapshot.context)
        }

        let focusedElement = unsafeDowncast(focusedValue, to: AXUIElement.self)
        guard let selectedText = selectedText(
            appElement: appElement,
            focusedElement: focusedElement
        ) else {
            var context = snapshot.context
            context.sourceURL = bestEffortURL(
                appElement: appElement,
                focusedElement: focusedElement,
                bundleIdentifier: snapshot.bundleIdentifier
            )
            return .unavailable(reason: .unsupported, source: context)
        }
        var context = snapshot.context
        context.sourceURL = bestEffortURL(
            appElement: appElement,
            focusedElement: focusedElement,
            bundleIdentifier: snapshot.bundleIdentifier
        )
        if snapshot.bundleIdentifier == "com.tinyspeck.slackmacgap" {
            context.sourceURL = slackMessageURL(
                appElement: appElement,
                matching: selectedText
            ) ?? context.sourceURL
        }
        return .success(text: selectedText, source: context)
    }

    private static func selectedText(
        appElement: AXUIElement,
        focusedElement: AXUIElement
    ) -> String? {
        var candidates: [AXUIElement] = []
        appendAncestors(of: focusedElement, to: &candidates)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let window = elementAttribute(appElement, attribute) {
                candidates.append(window)
            }
        }
        candidates.append(appElement)

        for element in candidates {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                &value
            ) == .success,
                let text = value as? String
            else {
                continue
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    @MainActor
    private static func copySelectedText(from processIdentifier: pid_t) async -> String? {
        let pasteboard = NSPasteboard.general
        let originalItems = snapshotPasteboard(pasteboard)
        let markerType = NSPasteboard.PasteboardType("com.clasp.capture-marker")
        let marker = UUID().uuidString

        pasteboard.clearContents()
        pasteboard.setString(marker, forType: markerType)

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: 8,
            keyDown: true
        ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: 8,
                keyDown: false
            )
        else {
            restorePasteboard(pasteboard, from: originalItems)
            return nil
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)

        try? await Task.sleep(for: .milliseconds(180))
        let copiedText = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let markerRemains = pasteboard.string(forType: markerType) == marker
        restorePasteboard(pasteboard, from: originalItems)

        guard !markerRemains, let copiedText, !copiedText.isEmpty else {
            return nil
        }
        return copiedText
    }

    @MainActor
    private static func snapshotPasteboard(
        _ pasteboard: NSPasteboard
    ) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    @MainActor
    private static func restorePasteboard(
        _ pasteboard: NSPasteboard,
        from snapshots: [[NSPasteboard.PasteboardType: Data]]
    ) {
        pasteboard.clearContents()
        let items = snapshots.map { snapshot in
            let item = NSPasteboardItem()
            for (type, data) in snapshot {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private static func bestEffortURL(
        appElement: AXUIElement,
        focusedElement: AXUIElement,
        bundleIdentifier: String?
    ) -> URL? {
        var elements: [AXUIElement] = []
        if let hitElement = elementAtSelection(
            appElement: appElement,
            focusedElement: focusedElement
        ) {
            appendAncestors(of: hitElement, to: &elements)
        }
        appendAncestors(of: focusedElement, to: &elements)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let window = elementAttribute(appElement, attribute) {
                elements.append(window)
            }
        }

        var urls = elements.compactMap(urlAttribute)
        if bundleIdentifier == "com.tinyspeck.slackmacgap"
            || urls.contains(where: { $0.host?.hasSuffix("slack.com") == true }) {
            for element in elements.prefix(6) {
                urls.append(contentsOf: descendantURLs(from: element, depth: 3, limit: 120))
            }
        }
        return SourceLocationResolver.bestURL(
            from: deduplicated(urls),
            bundleIdentifier: bundleIdentifier
        )
    }

    private static func urlAttribute(_ element: AXUIElement) -> URL? {
        for attribute in [kAXURLAttribute, kAXDocumentAttribute] {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                element,
                attribute as CFString,
                &value
            ) == .success else {
                continue
            }
            if let url = value as? URL {
                return url
            }
            if let string = value as? String,
               let url = SourceLocationResolver.normalize(string) {
                return url
            }
        }
        return nil
    }

    private static func slackMessageURL(
        processIdentifier: pid_t,
        matching selectedText: String
    ) -> URL? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.6)
        return slackMessageURL(appElement: appElement, matching: selectedText)
    }

    private static func slackMessageURL(
        appElement: AXUIElement,
        matching selectedText: String
    ) -> URL? {
        let needle = normalizedMatchText(selectedText)
        guard needle.count >= 4 else { return nil }

        var queue: [(AXUIElement, Int)] = [(appElement, 0)]
        var visited = 0
        while !queue.isEmpty, visited < 1_500 {
            let (element, depth) = queue.removeFirst()
            visited += 1

            if elementMatchesSelection(element, needle: needle) {
                var current: AXUIElement? = element
                for _ in 0..<4 {
                    guard let candidate = current else { break }
                    let urls = descendantURLs(from: candidate, depth: 2, limit: 100)
                        .filter(SourceLocationResolver.isSlackPermalink)
                    if let permalink = SourceLocationResolver.bestURL(
                        from: urls,
                        bundleIdentifier: "com.tinyspeck.slackmacgap"
                    ) {
                        return permalink
                    }
                    current = elementAttribute(candidate, kAXParentAttribute)
                }
            }

            guard depth < 14 else { continue }
            queue.append(contentsOf: children(of: element).map { ($0, depth + 1) })
        }
        return nil
    }

    private static func elementMatchesSelection(
        _ element: AXUIElement,
        needle: String
    ) -> Bool {
        for attribute in [
            kAXValueAttribute,
            kAXTitleAttribute,
            kAXDescriptionAttribute
        ] {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                element,
                attribute as CFString,
                &value
            ) == .success,
                let string = value as? String
            else {
                continue
            }
            let candidate = normalizedMatchText(string)
            if candidate.contains(needle)
                || (candidate.count >= 12 && needle.contains(candidate)) {
                return true
            }
        }
        return false
    }

    private static func normalizedMatchText(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenValue
        ) == .success,
            let children = childrenValue as? [AXUIElement]
        else {
            return []
        }
        return children
    }

    private static func elementAtSelection(
        appElement: AXUIElement,
        focusedElement: AXUIElement
    ) -> AXUIElement? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success,
            let rangeValue
        else {
            return nil
        }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        ) == .success,
            let boundsValue,
            CFGetTypeID(boundsValue) == AXValueGetTypeID()
        else {
            return nil
        }
        var bounds = CGRect.zero
        guard AXValueGetValue(
            unsafeDowncast(boundsValue, to: AXValue.self),
            .cgRect,
            &bounds
        ) else {
            return nil
        }
        var hitElement: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            appElement,
            Float(bounds.midX),
            Float(bounds.midY),
            &hitElement
        ) == .success else {
            return nil
        }
        return hitElement
    }

    private static func appendAncestors(
        of element: AXUIElement,
        to elements: inout [AXUIElement]
    ) {
        var current: AXUIElement? = element
        for _ in 0..<12 {
            guard let value = current else { break }
            elements.append(value)
            current = elementAttribute(value, kAXParentAttribute)
        }
    }

    private static func elementAttribute(
        _ element: AXUIElement,
        _ attribute: String
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func descendantURLs(
        from root: AXUIElement,
        depth: Int,
        limit: Int
    ) -> [URL] {
        var result: [URL] = []
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var visited = 0
        while !queue.isEmpty, visited < limit {
            let (element, currentDepth) = queue.removeFirst()
            visited += 1
            if let url = urlAttribute(element) {
                result.append(url)
            }
            guard currentDepth < depth else { continue }
            queue.append(contentsOf: children(of: element).map {
                ($0, currentDepth + 1)
            })
        }
        return result
    }

    private static func deduplicated(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}
