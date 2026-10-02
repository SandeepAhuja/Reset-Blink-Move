//
//  PreferencesWindowController.swift
//
//  Programmatic preferences UI. Depends on abstractions injected at init —
//  `SettingsProviding`, `LoginItemManaging`, and two callbacks (re-apply
//  settings / take a break now) — instead of reaching for global singletons or
//  a back-pointer to AppDelegate. Popup selection mapping is delegated to the
//  pure ReminderEngine.
//

import Cocoa

final class PreferencesWindowController: NSWindowController {

    private let settings: SettingsProviding
    private let loginItem: LoginItemManaging
    private let onChange: () -> Void
    private let takeBreak: (String) -> Void

    private var eyePopup: NSPopUpButton!
    private var legPopup: NSPopUpButton!
    private var breakPopup: NSPopUpButton!
    private var overlayCheck: NSButton!
    private var soundCheck: NSButton!
    private var launchCheck: NSButton!
    private var pauseCheck: NSButton!

    let eyeOptions   = [1, 2, 5, 10, 15, 20, 25, 30]
    let legOptions   = [1, 2, 5, 10, 15, 20, 30, 45, 60]
    let breakOptions = [20, 30]

    private let engine = ReminderEngine()

    init(settings: SettingsProviding,
         loginItem: LoginItemManaging,
         onChange: @escaping () -> Void,
         takeBreak: @escaping (String) -> Void) {
        self.settings = settings
        self.loginItem = loginItem
        self.onChange = onChange
        self.takeBreak = takeBreak

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 500),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = NSLocalizedString("prefs.app_name", comment: "")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        refreshFromSettings()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildUI() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 500))

        content.addSubview(label(NSLocalizedString("prefs.app_name", comment: ""), NSRect(x: 24, y: 458, width: 412, height: 28),
                                 size: 18, weight: .semibold))
        content.addSubview(label(NSLocalizedString("prefs.subtitle", comment: ""),
                                 NSRect(x: 24, y: 436, width: 412, height: 18),
                                 size: 11, color: .secondaryLabelColor))

        // EYES
        content.addSubview(sectionHeader(NSLocalizedString("prefs.section.eyes", comment: ""), y: 404))
        content.addSubview(label(NSLocalizedString("prefs.eye_interval", comment: ""), NSRect(x: 24, y: 372, width: 270, height: 20)))
        eyePopup = popup(minuteTitles(eyeOptions), frame: NSRect(x: 300, y: 370, width: 130, height: 26))
        content.addSubview(eyePopup)

        content.addSubview(label(NSLocalizedString("prefs.eye_break_duration", comment: ""), NSRect(x: 24, y: 340, width: 270, height: 20)))
        breakPopup = popup(secondTitles(breakOptions), frame: NSRect(x: 300, y: 338, width: 130, height: 26))
        content.addSubview(breakPopup)

        overlayCheck = check(NSLocalizedString("prefs.show_overlay", comment: ""), y: 312)
        content.addSubview(overlayCheck)
        soundCheck = check(NSLocalizedString("prefs.play_sound", comment: ""), y: 288)
        content.addSubview(soundCheck)

        // LEGS
        content.addSubview(sectionHeader(NSLocalizedString("prefs.section.legs", comment: ""), y: 252))
        content.addSubview(label(NSLocalizedString("prefs.leg_interval", comment: ""), NSRect(x: 24, y: 220, width: 270, height: 20)))
        legPopup = popup(minuteTitles(legOptions), frame: NSRect(x: 300, y: 218, width: 130, height: 26))
        content.addSubview(legPopup)

        // GENERAL
        content.addSubview(sectionHeader(NSLocalizedString("prefs.section.general", comment: ""), y: 182))
        launchCheck = check(NSLocalizedString("prefs.launch_at_login", comment: ""), y: 152)
        content.addSubview(launchCheck)
        pauseCheck = check(NSLocalizedString("prefs.pause_reminders", comment: ""), y: 128)
        content.addSubview(pauseCheck)

        let eyeNow = pushButton(NSLocalizedString("prefs.take_eye_break", comment: ""), frame: NSRect(x: 24, y: 84, width: 185, height: 32),
                                action: #selector(eyeNowTapped))
        content.addSubview(eyeNow)
        let legNow = pushButton(NSLocalizedString("prefs.take_leg_break", comment: ""), frame: NSRect(x: 219, y: 84, width: 185, height: 32),
                                action: #selector(legNowTapped))
        content.addSubview(legNow)

        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        content.addSubview(label(String(format: NSLocalizedString("prefs.version", comment: ""), version),
                                 NSRect(x: 24, y: 46, width: 412, height: 16),
                                 size: 11, color: .secondaryLabelColor))
        content.addSubview(label(NSLocalizedString("prefs.disclaimer", comment: ""),
                                 NSRect(x: 24, y: 26, width: 412, height: 16),
                                 size: 10, color: .tertiaryLabelColor))

        window?.contentView = content
    }

    // MARK: builders

    private func label(_ s: String, _ frame: NSRect, size: CGFloat = 13,
                       weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.frame = frame
        t.font = .systemFont(ofSize: size, weight: weight)
        t.textColor = color
        return t
    }

    private func sectionHeader(_ s: String, y: CGFloat) -> NSTextField {
        label(s, NSRect(x: 24, y: y, width: 412, height: 16), size: 11, weight: .semibold, color: .secondaryLabelColor)
    }

    /// Localized "N min" labels for a set of minute options.
    private func minuteTitles(_ options: [Int]) -> [String] {
        options.map { String(format: NSLocalizedString("popup.minutes_format", comment: ""), $0) }
    }

    /// Localized "N sec" labels for a set of second options.
    private func secondTitles(_ options: [Int]) -> [String] {
        options.map { String(format: NSLocalizedString("popup.seconds_format", comment: ""), $0) }
    }

    private func popup(_ titles: [String], frame: NSRect) -> NSPopUpButton {
        let p = NSPopUpButton(frame: frame, pullsDown: false)
        p.addItems(withTitles: titles)
        p.target = self
        p.action = #selector(controlChanged)
        return p
    }

    private func check(_ title: String, y: CGFloat) -> NSButton {
        let b = NSButton(checkboxWithTitle: title, target: self, action: #selector(controlChanged))
        b.frame = NSRect(x: 24, y: y, width: 412, height: 20)
        return b
    }

    private func pushButton(_ title: String, frame: NSRect, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.frame = frame
        return b
    }

    // MARK: sync

    func refreshFromSettings() {
        select(eyePopup, value: settings.eyeMin, options: eyeOptions)
        select(legPopup, value: settings.legMin, options: legOptions)
        select(breakPopup, value: settings.eyeBreakSec, options: breakOptions)
        overlayCheck.state = settings.showOverlay ? .on : .off
        soundCheck.state   = settings.playSound ? .on : .off
        pauseCheck.state   = settings.paused ? .on : .off
        launchCheck.state  = loginItem.isEnabled ? .on : .off
    }

    private func select(_ p: NSPopUpButton, value: Int, options: [Int]) {
        if let idx = engine.selectedIndex(for: value, in: options) { p.selectItem(at: idx) }
    }

    private func value(_ p: NSPopUpButton, options: [Int], fallback: Int) -> Int {
        engine.value(atIndex: p.indexOfSelectedItem, in: options, fallback: fallback)
    }

    @objc func controlChanged() {
        settings.eyeMin      = value(eyePopup, options: eyeOptions, fallback: 20)
        settings.legMin      = value(legPopup, options: legOptions, fallback: 30)
        settings.eyeBreakSec = value(breakPopup, options: breakOptions, fallback: 20)
        settings.showOverlay = overlayCheck.state == .on
        settings.playSound   = soundCheck.state == .on
        settings.paused      = pauseCheck.state == .on
        loginItem.set(launchCheck.state == .on)
        onChange()
    }

    @objc func eyeNowTapped() { takeBreak("eye") }
    @objc func legNowTapped() { takeBreak("leg") }
}
