//
//  AppDelegate.swift
//
//  Composition root + status-bar UI. The no-arg initializer builds the
//  production object graph (concrete adapters) and hands it to a designated
//  initializer that stores only abstractions — so tests can construct an
//  AppDelegate with fakes. All scheduling policy lives in BreakScheduler; this
//  class only wires collaborators and owns the menu-bar item.
//

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let settings: SettingsProviding
    private let loginItem: LoginItemManaging
    private let notificationPresenter: NotificationPresenting
    private let scheduler: BreakScheduler

    private var statusItem: NSStatusItem!
    private var statusLineItem: NSMenuItem?
    private var refreshTimer: Timer?

    private lazy var prefs: PreferencesWindowController = {
        PreferencesWindowController(
            settings: settings,
            loginItem: loginItem,
            onChange: { [weak self] in self?.scheduler.apply() },
            takeBreak: { [weak self] id in self?.scheduler.fireNow(id: id) }
        )
    }()

    // MARK: Composition

    init(settings: SettingsProviding,
         loginItem: LoginItemManaging,
         notificationPresenter: NotificationPresenting,
         scheduler: BreakScheduler) {
        self.settings = settings
        self.loginItem = loginItem
        self.notificationPresenter = notificationPresenter
        self.scheduler = scheduler
        super.init()
    }

    /// Production graph.
    override convenience init() {
        let settings = UserDefaultsSettings()
        let notifier = UserNotificationPresenter(settings: settings)
        let overlay = OverlayWindowPresenter()
        let reminders: [Reminder] = [
            EyeReminder(),
            LegReminder(rotator: LegTipRotator())
        ]
        let scheduler = BreakScheduler(reminders: reminders,
                                       settings: settings,
                                       timers: RealTimerScheduler(),
                                       notifier: notifier,
                                       overlay: overlay)
        self.init(settings: settings,
                  loginItem: LoginItem(),
                  notificationPresenter: notifier,
                  scheduler: scheduler)
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.registerDefaults()
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        scheduler.onStatusChanged = { [weak self] in self?.updateStatusLine() }
        scheduler.apply()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateStatusLine()
        }
    }

    // MARK: Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "eye", accessibilityDescription: localize("prefs.app_name")) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "👁"
            }
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusLine = NSMenuItem(title: scheduler.statusText(), action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        statusLineItem = statusLine
        menu.addItem(statusLine)

        menu.addItem(.separator())
        for reminder in scheduler.reminders {
            let item = NSMenuItem(title: localize(reminder.menuTitleKey),
                                  action: #selector(triggerReminder(_:)),
                                  keyEquivalent: reminder.menuKeyEquivalent)
            item.target = self
            item.representedObject = reminder.id
            menu.addItem(item)
        }
        menu.addItem(.separator())
        addItem(menu, localize("menu.preferences"), #selector(showPreferences), ",")
        menu.addItem(.separator())
        addItem(menu, localize("menu.quit"), #selector(quit), "q")

        statusItem.menu = menu
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ sel: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func updateStatusLine() { statusLineItem?.title = scheduler.statusText() }

    private func localize(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    // MARK: Menu actions

    @objc func triggerReminder(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        scheduler.fireNow(id: id)
    }

    @objc private func showPreferences() {
        prefs.refreshFromSettings()
        NSApp.activate(ignoringOtherApps: true)
        prefs.showWindow(nil)
        prefs.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
