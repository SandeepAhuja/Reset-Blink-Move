//
//  Reminder.swift
//
//  The `Reminder` protocol is the app's Open/Closed seam: the scheduler drives a
//  `[Reminder]`, so a new kind of break (hydration, posture, …) is added by
//  writing a new conformer — no change to BreakScheduler, AppDelegate, or the
//  menu. Each reminder owns its interval source and, in one `fire(_:)` call,
//  produces both the notification and the optional overlay to show.
//
//  Computing both in a single call matters for LegReminder: its rotating tip is
//  advanced exactly once per firing and reused for the notification and the pop.
//

import Foundation

/// Localized strings for one delivered notification.
struct NotificationContent: Equatable {
    let title: String
    let body: String
}

/// A request to show the break overlay for `seconds` with the given copy.
struct OverlayRequest: Equatable {
    let title: String
    let subtitle: String
    let seconds: Int
}

/// Everything to present when a reminder fires: a notification and, when the
/// overlay is enabled, an overlay request.
struct ReminderFiring: Equatable {
    let notification: NotificationContent
    let overlay: OverlayRequest?
}

protocol Reminder {
    /// Stable identifier (used for menu actions and next-fire bookkeeping).
    var id: String { get }
    /// Localization key for the "take this break now" menu item.
    var menuTitleKey: String { get }
    /// Menu key equivalent (e.g. "e").
    var menuKeyEquivalent: String { get }
    /// Localization key for the status-line countdown (e.g. "status.eyes_in").
    var statusLabelKey: String { get }

    /// How many minutes between firings, read from settings.
    func intervalMinutes(_ settings: SettingsProviding) -> Int
    /// The content to present for one firing (advances any per-fire state).
    func fire(_ settings: SettingsProviding) -> ReminderFiring
}

// MARK: - Eye reminder (20-20-20)

struct EyeReminder: Reminder {
    var localize: (String) -> String = { NSLocalizedString($0, comment: "") }

    let id = "eye"
    let menuTitleKey = "menu.eye_break_now"
    let menuKeyEquivalent = "e"
    let statusLabelKey = "status.eyes_in"

    func intervalMinutes(_ settings: SettingsProviding) -> Int { settings.eyeMin }

    func fire(_ settings: SettingsProviding) -> ReminderFiring {
        let notification = NotificationContent(
            title: localize("notif.eye.title"),
            body: String(format: localize("notif.eye.body"), settings.eyeBreakSec)
        )
        let overlay = settings.showOverlay
            ? OverlayRequest(title: String(format: localize("overlay.title"), settings.eyeBreakSec),
                             subtitle: localize("overlay.subtitle"),
                             seconds: max(1, settings.eyeBreakSec))
            : nil
        return ReminderFiring(notification: notification, overlay: overlay)
    }
}

// MARK: - Leg reminder (rotating tips)

/// Cursor over the leg-care tips. A reference type so a value-type `LegReminder`
/// can advance it from a non-mutating method.
final class LegTipRotator {
    static let defaultTips: [(title: String, body: String)] = [
        ("leg.tip1.title", "leg.tip1.body"),
        ("leg.tip2.title", "leg.tip2.body"),
        ("leg.tip3.title", "leg.tip3.body"),
        ("leg.tip4.title", "leg.tip4.body"),
        ("leg.tip5.title", "leg.tip5.body"),
        ("leg.tip6.title", "leg.tip6.body"),
    ]

    let tips: [(title: String, body: String)]
    private(set) var index = 0

    init(tips: [(title: String, body: String)] = LegTipRotator.defaultTips) {
        self.tips = tips
    }

    /// Returns the next tip's string keys and advances the (wrapping) cursor.
    func next() -> (title: String, body: String) {
        let tip = tips[index % tips.count]
        index += 1
        return tip
    }
}

struct LegReminder: Reminder {
    var localize: (String) -> String = { NSLocalizedString($0, comment: "") }
    /// Countdown length (seconds) for the leg-break overlay. Not a user setting
    /// today, but injectable so it is easy to make one later.
    var breakSeconds: Int = 30
    let rotator: LegTipRotator

    let id = "leg"
    let menuTitleKey = "menu.leg_break_now"
    let menuKeyEquivalent = "l"
    let statusLabelKey = "status.legs_in"

    func intervalMinutes(_ settings: SettingsProviding) -> Int { settings.legMin }

    func fire(_ settings: SettingsProviding) -> ReminderFiring {
        let tip = rotator.next()
        let tipTitle = localize(tip.title)
        let tipBody = localize(tip.body)
        let notification = NotificationContent(
            title: String(format: localize("notif.leg.title"), tipTitle),
            body: tipBody
        )
        // Same tip drives the pop, so the notification and overlay always agree.
        let overlay = settings.showOverlay
            ? OverlayRequest(title: tipTitle, subtitle: tipBody, seconds: max(1, breakSeconds))
            : nil
        return ReminderFiring(notification: notification, overlay: overlay)
    }
}
