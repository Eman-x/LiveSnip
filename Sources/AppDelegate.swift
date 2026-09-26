import AppKit
import Carbon.HIToolbox

/// The capture shortcut: ⇧⌘2, the same default as TextSniper. Change these values together.
private enum Shortcut {
    static let keyCode = kVK_ANSI_2
    static let modifiers = cmdKey | shiftKey
    static let menuKey = "2"
    static let menuModifiers: NSEvent.ModifierFlags = [.command, .shift]
    static let display = "⇧⌘2"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let keepLineBreaksKey = "keepLineBreaks"

    private let hud = HUD()
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var isCapturing = false
    private var requestedScreenAccess = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.keepLineBreaksKey: true])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "LiveSnip")
        statusItem.menu = makeMenu()

        hotKey = HotKey(keyCode: Shortcut.keyCode, modifiers: Shortcut.modifiers) { [weak self] in
            self?.captureText()
        }
        if hotKey == nil {
            hud.show(symbol: "exclamationmark.triangle", title: "\(Shortcut.display) is already in use",
                     detail: "Capture from the menu bar icon instead")
        } else {
            hud.show(symbol: "text.viewfinder", title: "LiveSnip is running",
                     detail: "Press \(Shortcut.display) to capture text")
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let capture = NSMenuItem(title: "Capture Text", action: #selector(captureText), keyEquivalent: Shortcut.menuKey)
        capture.keyEquivalentModifierMask = Shortcut.menuModifiers
        capture.target = self
        menu.addItem(capture)
        menu.addItem(.separator())

        let lineBreaks = NSMenuItem(title: "Keep Line Breaks", action: #selector(toggleLineBreaks(_:)), keyEquivalent: "")
        lineBreaks.state = UserDefaults.standard.bool(forKey: Self.keepLineBreaksKey) ? .on : .off
        lineBreaks.target = self
        menu.addItem(lineBreaks)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit LiveSnip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func toggleLineBreaks(_ item: NSMenuItem) {
        let keep = item.state != .on
        UserDefaults.standard.set(keep, forKey: Self.keepLineBreaksKey)
        item.state = keep ? .on : .off
    }

    @objc private func captureText() {
        guard !isCapturing, hasScreenAccess() else { return }
        isCapturing = true

        let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("LiveSnip-\(UUID().uuidString).png")
        let screencapture = Process()
        screencapture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i: drag to select (Space switches to window mode, Esc cancels), -x: no sound, -o: no window shadow.
        screencapture.arguments = ["-i", "-x", "-o", imageURL.path]
        screencapture.terminationHandler = { _ in
            Task { @MainActor in await self.copyText(from: imageURL) }
        }
        do {
            try screencapture.run()
        } catch {
            isCapturing = false
            hud.show(symbol: "exclamationmark.triangle", title: "Couldn't start the screen capture",
                     detail: error.localizedDescription)
        }
    }

    private func copyText(from imageURL: URL) async {
        defer {
            isCapturing = false
            try? FileManager.default.removeItem(at: imageURL)
        }
        // No image means the selection was cancelled.
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return }

        do {
            let transcript = try await LiveText.recognize(imageAt: imageURL)
            let singleLine = transcript.split(whereSeparator: \.isNewline).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            guard !singleLine.isEmpty else {
                hud.show(symbol: "text.magnifyingglass", title: "No text found")
                return
            }

            let keepLineBreaks = UserDefaults.standard.bool(forKey: Self.keepLineBreaksKey)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(keepLineBreaks ? transcript : singleLine, forType: .string)
            hud.show(symbol: "checkmark.circle", title: "Text copied", detail: singleLine)
        } catch {
            hud.show(symbol: "exclamationmark.triangle", title: "Couldn't read the text",
                     detail: error.localizedDescription)
        }
    }

    /// Screen recording permission lets the capture include other apps' windows, not just the wallpaper.
    private func hasScreenAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }

        if requestedScreenAccess {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        } else {
            requestedScreenAccess = true
            CGRequestScreenCaptureAccess()
        }
        hud.show(symbol: "lock", title: "Allow screen recording",
                 detail: "Turn on LiveSnip in System Settings, then reopen it")
        return false
    }
}
