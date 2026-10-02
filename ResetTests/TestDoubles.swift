//
//  TestDoubles.swift
//
//  In-memory fakes for every port, so domain logic (BreakScheduler, reminders)
//  can be tested with no AppKit, no real timers, and no notifications.
//

import Foundation
@testable import Reset

// MARK: Settings

final class InMemorySettings: SettingsProviding {
    var eyeMin = 20
    var legMin = 30
    var eyeBreakSec = 20
    var showOverlay = true
    var playSound = true
    var paused = false
    private(set) var didRegisterDefaults = false
    func registerDefaults() { didRegisterDefaults = true }
}

// MARK: Timer

final class FakeTimerScheduler: RepeatingTimerScheduling {
    final class Token: Cancellable {
        let interval: TimeInterval
        let block: () -> Void
        private(set) var cancelled = false
        init(interval: TimeInterval, block: @escaping () -> Void) {
            self.interval = interval; self.block = block
        }
        func cancel() { cancelled = true }
    }

    private(set) var tokens: [Token] = []
    var activeTokens: [Token] { tokens.filter { !$0.cancelled } }
    var cancelCount: Int { tokens.filter { $0.cancelled }.count }

    func scheduleRepeating(every interval: TimeInterval, _ block: @escaping () -> Void) -> Cancellable {
        let token = Token(interval: interval, block: block)
        tokens.append(token)
        return token
    }

    /// Fires every still-active scheduled timer once, in scheduling order.
    func fireAll() { activeTokens.forEach { $0.block() } }
}

// MARK: Notifications / overlay / login item

final class FakeNotificationPresenter: NotificationPresenting {
    private(set) var presented: [NotificationContent] = []
    func present(_ content: NotificationContent) { presented.append(content) }
}

final class FakeOverlayPresenter: OverlayPresenting {
    private(set) var requests: [OverlayRequest] = []
    func present(_ request: OverlayRequest) { requests.append(request) }
}

final class FakeLoginItem: LoginItemManaging {
    var isEnabled = false
    private(set) var setCalls: [Bool] = []
    func set(_ enabled: Bool) { setCalls.append(enabled); isEnabled = enabled }
}

// MARK: Shared localization table (deterministic, locale-independent)

enum TestStrings {
    static let table: [String: String] = [
        "status.paused":   "Reminders paused",
        "status.eyes_in":  "Eyes in %dm",
        "status.legs_in":  "Legs in %dm",
        "status.running":  "Running",
        "notif.eye.title": "Time for a 20-20-20 break 👁",
        "notif.eye.body":  "Look at something ~20 feet (6 m) away for %d seconds.",
        "notif.leg.title": "Leg care: %@ 🦵",
        "overlay.title":   "Look away for %d seconds",
        "overlay.subtitle": "Focus on something ~20 feet away",
        "leg.tip1.title":  "Stand up & move",
        "leg.tip1.body":   "Stand and walk for a minute.",
        "leg.tip2.title":  "Calf raises",
        "leg.tip2.body":   "Do a few calf raises.",
    ]
    static func localize(_ key: String) -> String { table[key] ?? key }
}
