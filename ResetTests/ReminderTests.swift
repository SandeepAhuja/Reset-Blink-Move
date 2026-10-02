//
//  ReminderTests.swift
//
//  Each reminder owns its interval and, per firing, its notification + optional
//  overlay. Tested in isolation with a deterministic string table.
//

import XCTest
@testable import Reset

final class ReminderTests: XCTestCase {

    private let settings = InMemorySettings()

    // MARK: EyeReminder

    func testEyeReminderMetadata() {
        let r = EyeReminder(localize: TestStrings.localize)
        XCTAssertEqual(r.id, "eye")
        XCTAssertEqual(r.menuKeyEquivalent, "e")
        XCTAssertEqual(r.statusLabelKey, "status.eyes_in")
    }

    func testEyeReminderIntervalTracksSettings() {
        let r = EyeReminder(localize: TestStrings.localize)
        settings.eyeMin = 25
        XCTAssertEqual(r.intervalMinutes(settings), 25)
    }

    func testEyeReminderFireNotificationAndOverlay() {
        let r = EyeReminder(localize: TestStrings.localize)
        settings.eyeBreakSec = 20
        settings.showOverlay = true
        let firing = r.fire(settings)

        XCTAssertEqual(firing.notification,
                       NotificationContent(title: "Time for a 20-20-20 break 👁",
                                           body: "Look at something ~20 feet (6 m) away for 20 seconds."))
        XCTAssertEqual(firing.overlay,
                       OverlayRequest(title: "Look away for 20 seconds",
                                      subtitle: "Focus on something ~20 feet away",
                                      seconds: 20))
    }

    func testEyeReminderOverlayClampsSecondsAndRespectsShowOverlay() {
        let r = EyeReminder(localize: TestStrings.localize)
        settings.showOverlay = true
        settings.eyeBreakSec = 0
        XCTAssertEqual(r.fire(settings).overlay?.seconds, 1)      // clamped

        settings.showOverlay = false
        XCTAssertNil(r.fire(settings).overlay)                    // suppressed
    }

    // MARK: LegReminder

    func testLegReminderMetadata() {
        let r = LegReminder(localize: TestStrings.localize, rotator: LegTipRotator())
        XCTAssertEqual(r.id, "leg")
        XCTAssertEqual(r.menuKeyEquivalent, "l")
        XCTAssertEqual(r.statusLabelKey, "status.legs_in")
    }

    func testLegReminderIntervalTracksSettings() {
        let r = LegReminder(localize: TestStrings.localize, rotator: LegTipRotator())
        settings.legMin = 45
        XCTAssertEqual(r.intervalMinutes(settings), 45)
    }

    func testLegReminderFireProducesNotificationAndTipOverlay() {
        let r = LegReminder(localize: TestStrings.localize, breakSeconds: 30, rotator: LegTipRotator())
        settings.showOverlay = true
        let firing = r.fire(settings)

        XCTAssertEqual(firing.notification,
                       NotificationContent(title: "Leg care: Stand up & move 🦵",
                                           body: "Stand and walk for a minute."))
        // The pop reuses the same tip and its own countdown length.
        XCTAssertEqual(firing.overlay,
                       OverlayRequest(title: "Stand up & move",
                                      subtitle: "Stand and walk for a minute.",
                                      seconds: 30))
    }

    func testLegReminderOverlaySuppressedWhenShowOverlayOff() {
        let r = LegReminder(localize: TestStrings.localize, rotator: LegTipRotator())
        settings.showOverlay = false
        XCTAssertNil(r.fire(settings).overlay)
    }

    func testLegReminderAdvancesTipOnlyOncePerFire() {
        let r = LegReminder(localize: TestStrings.localize, rotator: LegTipRotator())
        settings.showOverlay = true
        _ = r.fire(settings)                                   // consumes tip 1
        let second = r.fire(settings)                          // must be tip 2, not tip 3
        XCTAssertEqual(second.notification.title, "Leg care: Calf raises 🦵")
        XCTAssertEqual(second.overlay?.title, "Calf raises")
    }

    // MARK: default (non-injected) localization

    func testEyeReminderDefaultLocalizationResolvesBundleStrings() {
        let r = EyeReminder()                     // default localize = NSLocalizedString
        settings.eyeBreakSec = 20
        settings.showOverlay = true
        let firing = r.fire(settings)
        XCTAssertFalse(firing.notification.title.isEmpty)
        XCTAssertTrue(firing.notification.body.contains("20"))
        XCTAssertEqual(firing.overlay?.seconds, 20)
    }

    func testLegReminderDefaultLocalizationResolvesBundleStrings() {
        let r = LegReminder(rotator: LegTipRotator())   // default localize
        settings.showOverlay = true
        let firing = r.fire(settings)
        XCTAssertFalse(firing.notification.title.isEmpty)
        XCTAssertFalse(firing.overlay?.title.isEmpty ?? true)
    }

    // MARK: LegTipRotator

    func testRotatorHasSixDefaultTips() {
        XCTAssertEqual(LegTipRotator.defaultTips.count, 6)
    }

    func testRotatorCyclesAndWraps() {
        let rotator = LegTipRotator()
        let keys = LegTipRotator.defaultTips
        for i in 0..<keys.count {
            XCTAssertEqual(rotator.next().title, keys[i].title)
        }
        XCTAssertEqual(rotator.index, 6)
        XCTAssertEqual(rotator.next().title, keys[0].title)  // wraps
    }
}
