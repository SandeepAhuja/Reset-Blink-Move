//
//  RealTimerSchedulerTests.swift
//
//  Unit tests for the Timer-backed RepeatingTimerScheduling adapter. Uses short
//  intervals and spins the run loop, so they are fast and deterministic.
//

import XCTest
@testable import Reset

final class RealTimerSchedulerTests: XCTestCase {

    func testScheduleRepeatingFiresTheBlock() {
        let scheduler = RealTimerScheduler()
        var fires = 0
        let token = scheduler.scheduleRepeating(every: 0.05) { fires += 1 }
        RunLoop.current.run(until: Date().addingTimeInterval(0.22))
        token.cancel()
        XCTAssertGreaterThanOrEqual(fires, 2, "a 0.05s repeating timer should fire several times in 0.22s")
    }

    func testCancelStopsFiring() {
        let scheduler = RealTimerScheduler()
        var fires = 0
        let token = scheduler.scheduleRepeating(every: 0.05) { fires += 1 }
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        XCTAssertGreaterThan(fires, 0, "should have fired before cancel")

        token.cancel()
        let afterCancel = fires
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(fires, afterCancel, "must not fire after cancel()")
    }
}
