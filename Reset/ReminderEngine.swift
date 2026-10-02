//
//  ReminderEngine.swift
//
//  Pure, framework-free scheduling math and status-line formatting. No AppKit,
//  no UserNotifications, no clock of its own — time is passed in and strings go
//  through the injectable `localize` hook, so every function is deterministic
//  and fully unit-tested.
//

import Foundation

struct ReminderEngine {

    /// Localization hook. Production uses the app bundle; tests inject a table.
    var localize: (String) -> String = { NSLocalizedString($0, comment: "") }

    /// Timer interval (seconds) for a reminder configured in `minutes`.
    /// Never fires faster than once a minute.
    func interval(minutes: Int) -> TimeInterval {
        TimeInterval(max(1, minutes) * 60)
    }

    /// The instant a reminder scheduled `minutes` from `now` will fire.
    func nextFire(minutes: Int, from now: Date = Date()) -> Date {
        now.addingTimeInterval(interval(minutes: minutes))
    }

    /// Whole minutes (rounded up, clamped at 0) from `now` until `date`.
    func minutesUntil(_ date: Date, from now: Date = Date()) -> Int {
        max(0, Int(ceil(date.timeIntervalSince(now) / 60.0)))
    }

    /// The menu's status line: paused note, per-reminder countdowns, or "running".
    func statusText(paused: Bool,
                    entries: [(labelKey: String, date: Date)],
                    now: Date = Date()) -> String {
        if paused { return localize("status.paused") }
        guard !entries.isEmpty else { return localize("status.running") }
        return entries
            .map { String(format: localize($0.labelKey), minutesUntil($0.date, from: now)) }
            .joined(separator: "  ·  ")
    }

    // MARK: Preferences popup <-> value mapping

    /// Index of `value` within `options`, or nil if absent.
    func selectedIndex(for value: Int, in options: [Int]) -> Int? {
        options.firstIndex(of: value)
    }

    /// Option value at `index`, or `fallback` when the index is out of range.
    func value(atIndex index: Int, in options: [Int], fallback: Int) -> Int {
        options.indices.contains(index) ? options[index] : fallback
    }
}
