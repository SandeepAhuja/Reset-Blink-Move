//
//  BreakScheduler.swift
//
//  The application's high-level policy: decides when each reminder fires,
//  tracks the next-fire time, and produces the status-line text. It depends
//  only on abstractions (SettingsProviding + the ports + a `[Reminder]` + an
//  injectable clock), so the entire policy is unit-testable with fakes — no
//  AppKit, no real timers, no notifications.
//

import Foundation

final class BreakScheduler {

    let reminders: [Reminder]

    private let settings: SettingsProviding
    private let timers: RepeatingTimerScheduling
    private let notifier: NotificationPresenting
    private let overlay: OverlayPresenting
    private let engine: ReminderEngine
    private let now: () -> Date

    private var tokens: [String: Cancellable] = [:]
    private(set) var nextFire: [String: Date] = [:]

    /// Called whenever the status text may have changed (fire, (re)schedule).
    var onStatusChanged: (() -> Void)?

    init(reminders: [Reminder],
         settings: SettingsProviding,
         timers: RepeatingTimerScheduling,
         notifier: NotificationPresenting,
         overlay: OverlayPresenting,
         engine: ReminderEngine = ReminderEngine(),
         now: @escaping () -> Date = Date.init) {
        self.reminders = reminders
        self.settings = settings
        self.timers = timers
        self.notifier = notifier
        self.overlay = overlay
        self.engine = engine
        self.now = now
    }

    /// (Re)schedules every reminder from current settings. Cancels existing
    /// timers first; when paused, schedules nothing and clears the countdowns.
    func apply() {
        tokens.values.forEach { $0.cancel() }
        tokens.removeAll()

        guard !settings.paused else {
            nextFire.removeAll()
            onStatusChanged?()
            return
        }

        for reminder in reminders {
            let interval = engine.interval(minutes: reminder.intervalMinutes(settings))
            nextFire[reminder.id] = now().addingTimeInterval(interval)
            tokens[reminder.id] = timers.scheduleRepeating(every: interval) { [weak self] in
                self?.fire(reminder)
            }
        }
        onStatusChanged?()
    }

    /// Fires the reminder with `id` immediately (menu / preferences "now" action).
    func fireNow(id: String) {
        guard let reminder = reminders.first(where: { $0.id == id }) else { return }
        fire(reminder)
    }

    private func fire(_ reminder: Reminder) {
        nextFire[reminder.id] = now().addingTimeInterval(engine.interval(minutes: reminder.intervalMinutes(settings)))
        let firing = reminder.fire(settings)
        notifier.present(firing.notification)
        if let request = firing.overlay {
            overlay.present(request)
        }
        onStatusChanged?()
    }

    /// The current status-line text (paused note, countdowns, or "running").
    func statusText() -> String {
        let entries: [(labelKey: String, date: Date)] = reminders.compactMap { reminder in
            guard let date = nextFire[reminder.id] else { return nil }
            return (reminder.statusLabelKey, date)
        }
        return engine.statusText(paused: settings.paused, entries: entries, now: now())
    }
}
