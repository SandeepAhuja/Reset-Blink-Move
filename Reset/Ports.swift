//
//  Ports.swift
//
//  Abstractions (ports) for every side-effecting collaborator the domain needs.
//  The domain (BreakScheduler, reminders) depends only on these protocols, never
//  on Timer / UNUserNotificationCenter / NSPanel / SMAppService directly
//  (Dependency Inversion). Concrete adapters live in their own files and are
//  wired together by AppDelegate (the composition root). Each protocol is small
//  and single-purpose (Interface Segregation).
//

import Foundation

/// A handle that cancels ongoing scheduled work (e.g. a repeating timer).
protocol Cancellable: AnyObject {
    func cancel()
}

/// Schedules repeating work. Abstracts `Timer`.
protocol RepeatingTimerScheduling: AnyObject {
    func scheduleRepeating(every interval: TimeInterval, _ block: @escaping () -> Void) -> Cancellable
}

/// Delivers a user notification. Abstracts `UNUserNotificationCenter`.
protocol NotificationPresenting: AnyObject {
    func present(_ content: NotificationContent)
}

/// Shows the eye-break overlay. Abstracts the `NSPanel` presentation.
protocol OverlayPresenting: AnyObject {
    func present(_ request: OverlayRequest)
}

/// Reads/writes the "launch at login" state. Abstracts `SMAppService`.
protocol LoginItemManaging {
    var isEnabled: Bool { get }
    func set(_ enabled: Bool)
}
