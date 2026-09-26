import AppKit
import Carbon.HIToolbox

/// A small window that records a new shortcut for Capture Text.
@MainActor
final class ShortcutWindowController: NSWindowController, NSWindowDelegate {
    private let recorder = NSButton()
    private let message = NSTextField(wrappingLabelWithString: "")
    private var shortcut: Shortcut
    private var monitor: Any?
    /// Called before recording, so pressing the current shortcut doesn't start a capture.
    private let beginRecording: () -> Void
    /// Called with the new shortcut, or nil when recording is cancelled.
    /// Returns false if the shortcut couldn't be registered.
    private let finishRecording: (Shortcut?) -> Bool

    init(shortcut: Shortcut, beginRecording: @escaping () -> Void, finishRecording: @escaping (Shortcut?) -> Bool) {
        self.shortcut = shortcut
        self.beginRecording = beginRecording
        self.finishRecording = finishRecording
        super.init(window: NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false))

        let content = makeContent()
        window?.title = "Capture Shortcut"
        window?.isReleasedWhenClosed = false
        window?.delegate = self
        window?.contentView = content
        window?.setContentSize(content.fittingSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        recorder.title = shortcut.displayName
        window?.center()
        NSApp.activate()
        showWindow(nil)
        startRecording()
    }

    func windowWillClose(_ notification: Notification) {
        if monitor != nil { stopRecording(with: nil) }
    }

    private func makeContent() -> NSView {
        let prompt = NSTextField(labelWithString: "Press the keys you want to use for Capture Text.")

        recorder.bezelStyle = .push
        recorder.controlSize = .large
        recorder.font = .systemFont(ofSize: 16, weight: .medium)
        recorder.target = self
        recorder.action = #selector(startRecording)
        recorder.widthAnchor.constraint(equalToConstant: 200).isActive = true

        message.font = .systemFont(ofSize: 11)
        message.alignment = .center
        message.preferredMaxLayoutWidth = prompt.intrinsicContentSize.width

        let standard = NSButton(title: "Use \(Shortcut.standard.displayName)", target: self, action: #selector(useStandard))
        let done = NSButton(title: "Done", target: self, action: #selector(NSWindowController.close))
        done.keyEquivalent = "\r"
        let buttons = NSStackView(views: [standard, done])
        buttons.distribution = .equalSpacing

        let stack = NSStackView(views: [prompt, recorder, message, buttons])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(8, after: recorder)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        // Size the window to the prompt, with every row inside the side insets.
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalTo: prompt.widthAnchor, constant: 48),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
        ])
        return stack
    }

    @objc private func startRecording() {
        guard monitor == nil else { return }
        beginRecording()
        recorder.title = "Type Shortcut…"
        setMessage("Press Esc to cancel.")
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handle(event)
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let held = Shortcut.symbols(for: event.modifierFlags)
            recorder.title = held.isEmpty ? "Type Shortcut…" : held
        } else if event.keyCode == UInt16(kVK_Escape) {
            stopRecording(with: nil)
        } else if let newShortcut = Shortcut(event: event) {
            stopRecording(with: newShortcut)
        } else {
            setMessage("Include ⌘, ⌥, or ⌃ so the shortcut doesn't get in the way of typing.", isError: true)
        }
    }

    @objc private func useStandard() {
        stopRecording(with: .standard)
    }

    private func stopRecording(with newShortcut: Shortcut?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil

        if finishRecording(newShortcut), let newShortcut {
            shortcut = newShortcut
            setMessage("Saved. Press \(newShortcut.displayName) to capture text.")
        } else if let newShortcut {
            setMessage("Another app is already using \(newShortcut.displayName).", isError: true)
        } else {
            setMessage("Click the shortcut to change it.")
        }
        recorder.title = shortcut.displayName
    }

    private func setMessage(_ text: String, isError: Bool = false) {
        message.stringValue = text
        message.textColor = isError ? .systemRed : .secondaryLabelColor
    }
}
