import AppKit

/// The Permissions tab: a green check when screen recording is allowed, or a way to allow it.
@MainActor
final class PermissionsViewController: NSViewController {
    private let isAllowed: () -> Bool
    private let statusIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let openSettings = NSButton(title: "Open System Settings", target: nil, action: nil)
    private let restart = NSStackView()
    private var timer: Timer?

    init(isAllowed: @escaping () -> Bool = { ScreenRecording.isAllowed }) {
        self.isAllowed = isAllowed
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let heading = NSTextField(labelWithString: "LiveSnip needs one permission to work.")
        heading.font = .systemFont(ofSize: 13, weight: .semibold)

        let icon = NSImageView(image: NSImage(systemSymbolName: "rectangle.dashed.badge.record", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 22, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = NSTextField(labelWithString: "Screen Recording")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        statusIcon.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        let status = NSStackView(views: [statusIcon, statusLabel])
        status.spacing = 4
        let titleRow = NSStackView(views: [title, NSView(), status])
        titleRow.distribution = .fill

        let detail = NSTextField(wrappingLabelWithString: "Lets LiveSnip read the area you select. Nothing is recorded or sent anywhere.")
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.preferredMaxLayoutWidth = 300
        openSettings.target = self
        openSettings.action = #selector(openScreenRecordingSettings)

        let text = NSStackView(views: [titleRow, detail, openSettings])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        text.setCustomSpacing(10, after: detail)
        let row = NSStackView(views: [icon, text])
        row.alignment = .top
        row.distribution = .fill
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        let card = CardView()
        card.addSubview(row)

        let hint = NSTextField(labelWithString: "Turned it on? It applies after LiveSnip restarts.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        let restartButton = NSButton(title: "Restart LiveSnip", target: self, action: #selector(restartApp))
        restartButton.controlSize = .small
        restart.setViews([hint, restartButton], in: .leading)
        restart.spacing = 10

        let stack = NSStackView(views: [heading, card, restart])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 420),
            card.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            // Margins as constraints: a stack view's own insets are dropped across its axis when it sizes itself.
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            titleRow.widthAnchor.constraint(equalTo: text.widthAnchor),
            detail.widthAnchor.constraint(equalTo: text.widthAnchor),
        ])
        view = stack
        refresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        // Pick up the change when someone comes back from System Settings.
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let isAllowed = isAllowed()
        statusIcon.image = NSImage(systemSymbolName: isAllowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                                   accessibilityDescription: nil)
        statusIcon.contentTintColor = isAllowed ? .systemGreen : .systemOrange
        statusLabel.stringValue = isAllowed ? "Allowed" : "Not allowed"
        statusLabel.textColor = isAllowed ? .systemGreen : .systemOrange
        openSettings.isHidden = isAllowed
        restart.isHidden = isAllowed
        if !isAllowed { ScreenRecording.awaitingConfirmation = true }
        // The tab is shorter once the button and restart hint are hidden.
        if isViewLoaded { preferredContentSize = view.fittingSize }
    }

    @objc private func openScreenRecordingSettings() {
        ScreenRecording.openSettings()
    }

    @objc private func restartApp() {
        ScreenRecording.relaunch()
    }
}

/// A rounded, filled panel whose colors follow light and dark mode.
private final class CardView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}
