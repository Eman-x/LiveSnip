import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Carbon hot keys don't need Accessibility permission.
final class HotKey {
    private let action: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init?(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        self.action = action

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, _, userData in
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData!).takeUnretainedValue()
            // Carbon delivers hot key events on the main thread.
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }
        guard InstallEventHandler(GetApplicationEventTarget(), handler, 1, &pressed,
                                  Unmanaged.passUnretained(self).toOpaque(), &handlerRef) == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x4C53_4E50), id: 1) // "LSNP"
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                                  GetApplicationEventTarget(), 0, &hotKeyRef) == noErr else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
