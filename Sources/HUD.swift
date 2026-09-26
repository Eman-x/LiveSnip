import AppKit

/// A small glass toast near the bottom of the screen that confirms what a capture did. It never takes focus.
@MainActor
final class HUD {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func show(symbol: String, title: String, detail: String? = nil) {
        dismissal?.cancel()
        panel?.orderOut(nil)

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        icon.contentTintColor = .labelColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let labels = NSStackView(views: [titleLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        if let detail {
            let detailLabel = NSTextField(labelWithString: detail)
            detailLabel.font = .systemFont(ofSize: 12)
            detailLabel.textColor = .secondaryLabelColor
            detailLabel.lineBreakMode = .byTruncatingTail
            detailLabel.cell?.usesSingleLineMode = true
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320).isActive = true
            labels.addArrangedSubview(detailLabel)
        }

        let content = NSStackView(views: [icon, labels])
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 20)
        // Without this, fittingSize drops the top and bottom insets.
        content.setHuggingPriority(.required, for: .vertical)
        let size = content.fittingSize
        content.frame = NSRect(origin: .zero, size: size)

        let glass = NSGlassEffectView(frame: content.frame)
        glass.cornerRadius = size.height / 2
        glass.contentView = content

        let panel = NSPanel(contentRect: content.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = glass

        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
            let area = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.minY + 80))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        self.panel = panel

        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }
            panel.orderOut(nil)
            if self?.panel === panel { self?.panel = nil }
        }
    }
}
