import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let keepLineBreaksKey = "keepLineBreaks"

    private let hud = HUD()
    private var statusItem: NSStatusItem!
    private let captureItem = NSMenuItem(title: "Capture Text", action: #selector(AppDelegate.captureText), keyEquivalent: "")
    private var shortcut = Shortcut.saved
    private var hotKey: HotKey?
    private var isCapturing = false
    private var requestedScreenAccess = false

    private lazy var shortcutWindow = ShortcutWindowController(
        shortcut: shortcut,
        beginRecording: { [weak self] in self?.hotKey = nil },
        finishRecording: { [weak self] in self?.finishRecording($0) ?? false })

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.keepLineBreaksKey: true])

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "LiveSnip")
        statusItem.menu = makeMenu()

        if registerHotKey() {
            hud.show(symbol: "text.viewfinder", title: "LiveSnip is running",
                     detail: "Press \(shortcut.displayName) to capture text")
        } else {
            hud.show(symbol: "exclamationmark.triangle", title: "\(shortcut.displayName) is already in use",
                     detail: "Open LiveSnip again to pick another shortcut")
        }
    }

    /// Opening LiveSnip while it's running shows the shortcut window, which helps when the
    /// menu bar is too full to show the icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showShortcutWindow()
        return false
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        captureItem.target = self
        menu.addItem(captureItem)
        menu.addItem(.separator())

        let lineBreaks = NSMenuItem(title: "Keep Line Breaks", action: #selector(toggleLineBreaks(_:)), keyEquivalent: "")
        lineBreaks.state = UserDefaults.standard.bool(forKey: Self.keepLineBreaksKey) ? .on : .off
        lineBreaks.target = self
        menu.addItem(lineBreaks)

        let changeShortcut = NSMenuItem(title: "Change Shortcut…", action: #selector(showShortcutWindow), keyEquivalent: "")
        changeShortcut.target = self
        menu.addItem(changeShortcut)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit LiveSnip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func showShortcutWindow() {
        shortcutWindow.show()
    }

    /// Registers the current shortcut, replacing the previous registration.
    @discardableResult
    private func registerHotKey() -> Bool {
        hotKey = nil
        hotKey = HotKey(keyCode: Int(shortcut.keyCode), modifiers: shortcut.carbonModifiers) { [weak self] in
            self?.captureText()
        }
        captureItem.keyEquivalent = shortcut.keyEquivalent
        captureItem.keyEquivalentModifierMask = shortcut.modifiers
        return hotKey != nil
    }

    /// Switches to a newly recorded shortcut, keeping the current one if another app already uses it.
    /// With nil (recording was cancelled), it turns the current shortcut back on.
    private func finishRecording(_ newShortcut: Shortcut?) -> Bool {
        guard let newShortcut, newShortcut != shortcut else { return registerHotKey() }

        let previous = shortcut
        shortcut = newShortcut
        if registerHotKey() {
            shortcut.save()
            return true
        }
        shortcut = previous
        registerHotKey()
        return false
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
