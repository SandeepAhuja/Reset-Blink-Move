//
//  ResetTests.swift  ->  ReminderEngine unit tests
//
//  Pure scheduling math and status-line formatting. A fixed clock and an
//  injected string table keep every assertion independent of wall-clock time
//  and locale.
//

import XCTest
@testable import Reset

final class ReminderEngineTests: XCTestCase {

    private func makeEngine() -> ReminderEngine {
        var e = ReminderEngine()
        e.localize = TestStrings.localize
        return e
    }

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    // MARK: interval(minutes:)

    func testIntervalConvertsMinutesToSeconds() {
        let e = makeEngine()
        XCTAssertEqual(e.interval(minutes: 20), 1200)
        XCTAssertEqual(e.interval(minutes: 30), 1800)
        XCTAssertEqual(e.interval(minutes: 1), 60)
    }

    func testIntervalClampsNonPositiveMinutesToOne() {
        let e = makeEngine()
        XCTAssertEqual(e.interval(minutes: 0), 60)
        XCTAssertEqual(e.interval(minutes: -5), 60)
    }

    // MARK: nextFire(minutes:from:)

    func testNextFireAddsClampedInterval() {
        let e = makeEngine()
        XCTAssertEqual(e.nextFire(minutes: 20, from: t0), t0.addingTimeInterval(1200))
        XCTAssertEqual(e.nextFire(minutes: 0, from: t0), t0.addingTimeInterval(60))
    }

    // MARK: minutesUntil(_:from:)

    func testMinutesUntilRoundsUp() {
        let e = makeEngine()
        XCTAssertEqual(e.minutesUntil(t0.addingTimeInterval(1200), from: t0), 20)
        XCTAssertEqual(e.minutesUntil(t0.addingTimeInterval(90),   from: t0), 2)   // ceil(1.5)
        XCTAssertEqual(e.minutesUntil(t0.addingTimeInterval(1),    from: t0), 1)   // ceil(0.016)
        XCTAssertEqual(e.minutesUntil(t0.addingTimeInterval(60),   from: t0), 1)
    }

    func testMinutesUntilClampsPastAndNowToZero() {
        let e = makeEngine()
        XCTAssertEqual(e.minutesUntil(t0, from: t0), 0)
        XCTAssertEqual(e.minutesUntil(t0.addingTimeInterval(-500), from: t0), 0)
    }

    // MARK: statusText(paused:entries:now:)

    func testStatusTextPaused() {
        let e = makeEngine()
        let s = e.statusText(paused: true,
                             entries: [("status.eyes_in", t0.addingTimeInterval(1200))],
                             now: t0)
        XCTAssertEqual(s, "Reminders paused")
    }

    func testStatusTextRunningWhenNoEntries() {
        let e = makeEngine()
        XCTAssertEqual(e.statusText(paused: false, entries: [], now: t0), "Running")
    }

    func testStatusTextSingleEntry() {
        let e = makeEngine()
        let s = e.statusText(paused: false,
                             entries: [("status.eyes_in", t0.addingTimeInterval(1200))],
                             now: t0)
        XCTAssertEqual(s, "Eyes in 20m")
    }

    func testStatusTextMultipleEntriesJoined() {
        let e = makeEngine()
        let s = e.statusText(paused: false,
                             entries: [("status.eyes_in", t0.addingTimeInterval(1200)),
                                       ("status.legs_in", t0.addingTimeInterval(1800))],
                             now: t0)
        XCTAssertEqual(s, "Eyes in 20m  ·  Legs in 30m")
    }

    // MARK: popup <-> value mapping

    func testSelectedIndexFindsOptionOrNil() {
        let e = makeEngine()
        let eyeOptions = [15, 20, 25, 30]
        XCTAssertEqual(e.selectedIndex(for: 15, in: eyeOptions), 0)
        XCTAssertEqual(e.selectedIndex(for: 30, in: eyeOptions), 3)
        XCTAssertNil(e.selectedIndex(for: 99, in: eyeOptions))
    }

    func testValueAtIndexReturnsOptionOrFallback() {
        let e = makeEngine()
        let legOptions = [30, 45, 60]
        XCTAssertEqual(e.value(atIndex: 0, in: legOptions, fallback: 30), 30)
        XCTAssertEqual(e.value(atIndex: 2, in: legOptions, fallback: 30), 60)
        XCTAssertEqual(e.value(atIndex: -1, in: legOptions, fallback: 30), 30)   // nothing selected
        XCTAssertEqual(e.value(atIndex: 99, in: legOptions, fallback: 30), 30)
        XCTAssertEqual(e.value(atIndex: 0, in: [], fallback: 42), 42)
    }
}
