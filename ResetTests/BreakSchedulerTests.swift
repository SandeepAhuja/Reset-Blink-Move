//
//  BreakSchedulerTests.swift
//
//  The heart of the app's behavior, now fully unit-testable: scheduling,
//  firing, next-fire bookkeeping, pause handling, and status text — all driven
//  through fakes with a fixed clock. No AppKit, no real timers, no notifications.
//

import XCTest
@testable import Reset

final class BreakSchedulerTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private var settings: InMemorySettings!
    private var timers: FakeTimerScheduler!
    private var notifier: FakeNotificationPresenter!
    private var overlay: FakeOverlayPresenter!
    private var rotator: LegTipRotator!

    private func makeScheduler() -> BreakScheduler {
        settings = InMemorySettings()
        timers = FakeTimerScheduler()
        notifier = FakeNotificationPresenter()
        overlay = FakeOverlayPresenter()
        rotator = LegTipRotator()
        var engine = ReminderEngine()
        engine.localize = TestStrings.localize
        let reminders: [Reminder] = [
            EyeReminder(localize: TestStrings.localize),
            LegReminder(localize: TestStrings.localize, rotator: rotator)
        ]
        return BreakScheduler(reminders: reminders,
                              settings: settings,
                              timers: timers,
                              notifier: notifier,
                              overlay: overlay,
                              engine: engine,
                              now: { self.t0 })
    }

    // MARK: apply()

    func testApplySchedulesOneTimerPerReminderWithClampedIntervals() {
        let scheduler = makeScheduler()
        settings.eyeMin = 20
        settings.legMin = 30
        scheduler.apply()

        XCTAssertEqual(timers.activeTokens.count, 2)
        XCTAssertEqual(timers.activeTokens.map(\.interval), [1200, 1800])
        XCTAssertEqual(scheduler.nextFire["eye"], t0.addingTimeInterval(1200))
        XCTAssertEqual(scheduler.nextFire["leg"], t0.addingTimeInterval(1800))
    }

    func testApplyWhenPausedSchedulesNothingAndClearsCountdowns() {
        let scheduler = makeScheduler()
        scheduler.apply()
        settings.paused = true
        scheduler.apply()

        XCTAssertTrue(timers.activeTokens.isEmpty)
        XCTAssertTrue(scheduler.nextFire.isEmpty)
        XCTAssertEqual(scheduler.statusText(), "Reminders paused")
    }

    func testReapplyCancelsPreviousTimers() {
        let scheduler = makeScheduler()
        scheduler.apply()
        scheduler.apply()
        XCTAssertEqual(timers.cancelCount, 2)      // first pair cancelled
        XCTAssertEqual(timers.activeTokens.count, 2)
    }

    // MARK: firing

    func testBothTimersFiringPresentNotificationsAndPops() {
        let scheduler = makeScheduler()
        settings.eyeBreakSec = 20
        settings.showOverlay = true
        scheduler.apply()
        timers.fireAll()                                   // fires eye, then leg

        XCTAssertEqual(notifier.presented.count, 2)
        // Both reminders now show a pop.
        XCTAssertEqual(overlay.requests, [
            OverlayRequest(title: "Look away for 20 seconds",
                           subtitle: "Focus on something ~20 feet away",
                           seconds: 20),
            OverlayRequest(title: "Stand up & move",
                           subtitle: "Stand and walk for a minute.",
                           seconds: 30),
        ])
    }

    func testEyeTimerFiringShowsEyePop() {
        let scheduler = makeScheduler()
        settings.eyeBreakSec = 30
        settings.showOverlay = true
        scheduler.apply()

        scheduler.fireNow(id: "eye")

        XCTAssertEqual(notifier.presented.count, 1)
        XCTAssertEqual(notifier.presented.first?.title, "Time for a 20-20-20 break 👁")
        XCTAssertEqual(overlay.requests.count, 1)
        XCTAssertEqual(overlay.requests.first,
                       OverlayRequest(title: "Look away for 30 seconds",
                                      subtitle: "Focus on something ~20 feet away",
                                      seconds: 30))
    }

    func testLegTimerFiringShowsLegPop() {
        let scheduler = makeScheduler()
        settings.showOverlay = true
        scheduler.apply()

        scheduler.fireNow(id: "leg")

        XCTAssertEqual(notifier.presented.count, 1)
        XCTAssertEqual(notifier.presented.first?.title, "Leg care: Stand up & move 🦵")
        XCTAssertEqual(overlay.requests.count, 1)
        XCTAssertEqual(overlay.requests.first,
                       OverlayRequest(title: "Stand up & move",
                                      subtitle: "Stand and walk for a minute.",
                                      seconds: 30))
    }

    func testOverlaySuppressedWhenShowOverlayOff() {
        let scheduler = makeScheduler()
        settings.showOverlay = false
        scheduler.apply()
        timers.fireAll()
        XCTAssertTrue(overlay.requests.isEmpty)            // neither reminder pops
        XCTAssertEqual(notifier.presented.count, 2)        // notifications still fire
    }

    func testFireNowByIdFiresJustThatReminder() {
        let scheduler = makeScheduler()
        scheduler.apply()                       // apply() does not fire anything
        XCTAssertTrue(notifier.presented.isEmpty)
        scheduler.fireNow(id: "eye")
        XCTAssertEqual(notifier.presented.count, 1)
        XCTAssertEqual(notifier.presented.last?.title, "Time for a 20-20-20 break 👁")
        XCTAssertEqual(overlay.requests.count, 1)
    }

    func testFireNowWithUnknownIdDoesNothing() {
        let scheduler = makeScheduler()
        scheduler.apply()
        scheduler.fireNow(id: "does-not-exist")
        XCTAssertTrue(notifier.presented.isEmpty)
    }

    // MARK: status text

    func testStatusTextShowsBothCountdowns() {
        let scheduler = makeScheduler()
        settings.eyeMin = 20
        settings.legMin = 30
        scheduler.apply()
        XCTAssertEqual(scheduler.statusText(), "Eyes in 20m  ·  Legs in 30m")
    }

    func testStatusChangedCallbackFiresOnApplyAndFire() {
        let scheduler = makeScheduler()
        var count = 0
        scheduler.onStatusChanged = { count += 1 }
        scheduler.apply()               // +1
        scheduler.fireNow(id: "leg")    // +1
        XCTAssertEqual(count, 2)
    }
}
