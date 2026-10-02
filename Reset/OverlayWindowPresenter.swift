//
//  OverlayWindowPresenter.swift
//
//  Production adapter for `OverlayPresenting`. Owns the break overlay panel, its
//  countdown timer, and the Skip button. The title and subtitle wrap, and the
//  panel's height is computed from the actual text (each label sizes itself via
//  `fittingSize`), so long copy — e.g. a leg tip body — is never trimmed. Width
//  is fixed; text reflows within it.
//
//  Layout is built by the static `buildOverlay(_:…)` factory so it can be
//  inspected/snapshotted in tests without showing a real window.
//

import Cocoa

final class OverlayWindowPresenter: NSObject, OverlayPresenting {

    private var panel: NSPanel?
    private var countdownLabel: NSTextField?
    private var timer: Timer?
    private var remaining = 0

    /// True while the overlay panel is on screen.
    var isShowing: Bool { panel != nil }

    private let skipTitle: () -> String

    // Layout constants.
    private static let contentWidth: CGFloat = 380   // text wrap width
    private static let sidePadding: CGFloat = 24

    init(skipTitle: @escaping () -> String = { NSLocalizedString("overlay.skip", comment: "") }) {
        self.skipTitle = skipTitle
    }

    /// A built overlay: the content view, the panel size it needs, and its labels.
    struct Built {
        let view: NSVisualEffectView
        let size: NSSize
        let title: NSTextField
        let subtitle: NSTextField
        let countdown: NSTextField
    }

    func present(_ request: OverlayRequest) {
        if panel != nil { return }
        guard let screen = NSScreen.main else { return }

        let built = Self.buildOverlay(request, skipTitle: skipTitle(),
                                      target: self, skipAction: #selector(dismiss))
        countdownLabel = built.countdown

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: built.size),
                            styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = built.view

        let sf = screen.frame
        panel.setFrameOrigin(NSPoint(x: sf.midX - built.size.width / 2, y: sf.midY - built.size.height / 2))
        panel.orderFrontRegardless()

        self.panel = panel
        remaining = request.seconds
        built.countdown.stringValue = "\(remaining)"

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remaining -= 1
            if self.remaining <= 0 { self.dismiss() }
            else { self.countdownLabel?.stringValue = "\(self.remaining)" }
        }
    }

    @objc func dismiss() {
        timer?.invalidate(); timer = nil
        panel?.orderOut(nil); panel = nil
        countdownLabel = nil
    }

    // MARK: Layout

    /// Builds the overlay content sized to its text. Title and subtitle wrap and
    /// the total height follows the content, so no line is ever clipped.
    static func buildOverlay(_ request: OverlayRequest, skipTitle: String,
                             target: AnyObject?, skipAction: Selector?) -> Built {
        let contentWidth = Self.contentWidth
        let pad = Self.sidePadding
        let panelWidth = contentWidth + pad * 2

        let title = wrappingLabel(request.title,
                                  font: .systemFont(ofSize: 20, weight: .semibold),
                                  color: .white, width: contentWidth)
        let subtitle = wrappingLabel(request.subtitle,
                                     font: .systemFont(ofSize: 13),
                                     color: NSColor.white.withAlphaComponent(0.8), width: contentWidth)

        let countdown = NSTextField(labelWithString: "\(request.seconds)")
        countdown.font = .monospacedDigitSystemFont(ofSize: 56, weight: .bold)
        countdown.alignment = .center
        countdown.textColor = .white
        let countdownH: CGFloat = 64

        let skip = NSButton(title: skipTitle, target: target, action: skipAction)
        skip.bezelStyle = .rounded
        skip.sizeToFit()
        let skipW = max(80, ceil(skip.frame.width))
        let skipH: CGFloat = 28

        let gapTitleSub: CGFloat = 6
        let gapSubCount: CGFloat = 18
        let gapCountSkip: CGFloat = 16

        let titleH = title.frame.height
        let subH = subtitle.frame.height
        let totalH = pad + titleH + gapTitleSub + subH + gapSubCount
                     + countdownH + gapCountSkip + skipH + pad

        // Position top-to-bottom (AppKit origin is bottom-left).
        var cursorTop = totalH - pad
        title.frame    = NSRect(x: pad, y: cursorTop - titleH, width: contentWidth, height: titleH)
        cursorTop -= (titleH + gapTitleSub)
        subtitle.frame = NSRect(x: pad, y: cursorTop - subH, width: contentWidth, height: subH)
        cursorTop -= (subH + gapSubCount)
        countdown.frame = NSRect(x: pad, y: cursorTop - countdownH, width: contentWidth, height: countdownH)
        skip.frame = NSRect(x: (panelWidth - skipW) / 2, y: pad, width: skipW, height: skipH)

        let size = NSSize(width: panelWidth, height: totalH)
        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        container.addSubview(title)
        container.addSubview(subtitle)
        container.addSubview(countdown)
        container.addSubview(skip)

        return Built(view: container, size: size, title: title, subtitle: subtitle, countdown: countdown)
    }

    /// A center-aligned label that word-wraps within `width`, sized (by the label
    /// itself) to the exact height its text needs — so no line is ever clipped.
    static func wrappingLabel(_ string: String, font: NSFont, color: NSColor, width: CGFloat) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: string)
        label.isSelectable = false
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.font = font
        label.textColor = color
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = width
        label.setFrameSize(NSSize(width: width, height: 0))
        label.setFrameSize(NSSize(width: width, height: ceil(label.fittingSize.height)))
        return label
    }

    /// Height a wrapping label needs for `string` in `font` at `width`.
    static func textHeight(_ string: String, font: NSFont, width: CGFloat) -> CGFloat {
        wrappingLabel(string, font: font, color: .white, width: width).frame.height
    }
}
