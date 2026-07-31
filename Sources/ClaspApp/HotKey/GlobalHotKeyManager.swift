import Carbon
import Foundation

struct GlobalShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var keyLabel: String
    var command: Bool
    var control: Bool
    var option: Bool
    var shift: Bool

    static let `default` = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_C),
        keyLabel: "C",
        command: true,
        control: false,
        option: true,
        shift: false
    )

    static let availableKeys: [(label: String, code: UInt32)] = [
        ("C", UInt32(kVK_ANSI_C)),
        ("L", UInt32(kVK_ANSI_L)),
        ("B", UInt32(kVK_ANSI_B)),
        ("K", UInt32(kVK_ANSI_K)),
        ("Space", UInt32(kVK_Space))
    ]

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if command { value |= UInt32(cmdKey) }
        if control { value |= UInt32(controlKey) }
        if option { value |= UInt32(optionKey) }
        if shift { value |= UInt32(shiftKey) }
        return value
    }

    var isValid: Bool {
        command || control
    }

    var displayName: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        parts.append(keyLabel)
        return parts.joined()
    }
}

final class GlobalHotKeyManager: @unchecked Sendable {
    static let defaultsKey = "ClaspGlobalShortcut"

    var onPressed: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private let signature: OSType = 0x434C5350 // CLSP

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                manager.onPressed?()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ shortcut: GlobalShortcut) -> Bool {
        guard shortcut.isValid else { return false }
        unregister()
        let identifier = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status == noErr {
            save(shortcut)
            return true
        }
        hotKey = nil
        return false
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    func savedShortcut() -> GlobalShortcut {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let shortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data)
        else {
            return .default
        }
        return shortcut
    }

    private func save(_ shortcut: GlobalShortcut) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
