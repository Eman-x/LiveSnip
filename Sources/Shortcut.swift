import AppKit
import Carbon.HIToolbox

/// A key combination for Capture Text, saved in UserDefaults and registered as a Carbon hot key.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt
    /// What a menu item needs to show the shortcut.
    var keyEquivalent: String
    /// The key as people see it, for example "2", "F5", or "Space".
    var keyLabel: String

    /// ⇧⌘2, the same default as TextSniper.
    static let standard = Shortcut(keyCode: UInt16(kVK_ANSI_2), modifierFlags: NSEvent.ModifierFlags([.shift, .command]).rawValue,
                                   keyEquivalent: "2", keyLabel: "2")

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierFlags) }

    var carbonModifiers: Int {
        [(NSEvent.ModifierFlags.command, cmdKey), (.shift, shiftKey), (.option, optionKey), (.control, controlKey)]
            .reduce(0) { modifiers.contains($1.0) ? $0 | $1.1 : $0 }
    }

    /// For example "⇧⌘2".
    var displayName: String { Self.symbols(for: modifiers) + keyLabel }

    /// Modifier symbols in the order macOS menus show them.
    static func symbols(for modifiers: NSEvent.ModifierFlags) -> String {
        [(NSEvent.ModifierFlags.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { modifiers.contains($0.0) }.map(\.1).joined()
    }

    /// Reads a shortcut from a key press. Returns nil unless it uses ⌘, ⌥, or ⌃ (or is a function key),
    /// so the shortcut can't take over a key you type with.
    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let keyCode = Int(event.keyCode)
        guard Self.functionKeys.contains(keyCode) || !modifiers.isDisjoint(with: [.command, .option, .control]) else { return nil }

        if let label = Self.keyLabels[keyCode] {
            guard let keyEquivalent = event.charactersIgnoringModifiers, !keyEquivalent.isEmpty else { return nil }
            self.init(keyCode: event.keyCode, modifierFlags: modifiers.rawValue, keyEquivalent: keyEquivalent, keyLabel: label)
        } else {
            // Applying ⌘ makes layouts like Arabic report the Latin key that shortcuts use.
            guard let character = event.characters(byApplyingModifiers: .command), character.count == 1,
                  !character.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return nil }
            self.init(keyCode: event.keyCode, modifierFlags: modifiers.rawValue,
                      keyEquivalent: character.lowercased(), keyLabel: character.uppercased())
        }
    }

    private init(keyCode: UInt16, modifierFlags: UInt, keyEquivalent: String, keyLabel: String) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.keyEquivalent = keyEquivalent
        self.keyLabel = keyLabel
    }

    private static let functionKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                                       kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]

    /// Names for keys that don't type a character.
    private static let keyLabels: [Int: String] = {
        var labels = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
                      kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
                      kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟"]
        for (index, key) in functionKeys.enumerated() { labels[key] = "F\(index + 1)" }
        return labels
    }()
}

extension Shortcut {
    private static let defaultsKey = "shortcut"

    static var saved: Shortcut {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else { return .standard }
        return shortcut
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
