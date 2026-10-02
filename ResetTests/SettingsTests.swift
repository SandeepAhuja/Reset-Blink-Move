//
//  SettingsTests.swift
//
//  Exercises UserDefaultsSettings against an isolated, per-test suite so the
//  machine's real preferences are never read or written.
//

import XCTest
@testable import Reset

final class UserDefaultsSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: UserDefaultsSettings!

    override func setUpWithError() throws {
        suiteName = "ResetTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        settings = UserDefaultsSettings(store: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRegisterDefaultsProvidesShippingValues() {
        settings.registerDefaults()
        XCTAssertEqual(settings.eyeMin, 20)
        XCTAssertEqual(settings.legMin, 30)
        XCTAssertEqual(settings.eyeBreakSec, 20)
        XCTAssertTrue(settings.showOverlay)
        XCTAssertTrue(settings.playSound)
        XCTAssertFalse(settings.paused)
    }

    func testRegisterDefaultsDoesNotOverrideAnExplicitValue() {
        settings.eyeMin = 25
        settings.registerDefaults()          // registration is only a fallback
        XCTAssertEqual(settings.eyeMin, 25)
    }

    func testIntegerSettersRoundTrip() {
        settings.eyeMin = 15
        settings.legMin = 60
        settings.eyeBreakSec = 30
        XCTAssertEqual(settings.eyeMin, 15)
        XCTAssertEqual(settings.legMin, 60)
        XCTAssertEqual(settings.eyeBreakSec, 30)
    }

    func testBoolSettersRoundTrip() {
        settings.showOverlay = false
        settings.playSound = false
        settings.paused = true
        XCTAssertFalse(settings.showOverlay)
        XCTAssertFalse(settings.playSound)
        XCTAssertTrue(settings.paused)
    }

    func testWritesLandInStoreUnderExpectedKeys() {
        settings.eyeMin = 25
        settings.paused = true
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsSettings.Keys.eyeMin), 25)
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsSettings.Keys.paused))
    }

    func testKeyRawValues() {
        XCTAssertEqual(UserDefaultsSettings.Keys.eyeMin, "eyeIntervalMin")
        XCTAssertEqual(UserDefaultsSettings.Keys.legMin, "legIntervalMin")
        XCTAssertEqual(UserDefaultsSettings.Keys.eyeBreakSec, "eyeBreakSec")
        XCTAssertEqual(UserDefaultsSettings.Keys.showOverlay, "showOverlay")
        XCTAssertEqual(UserDefaultsSettings.Keys.playSound, "playSound")
        XCTAssertEqual(UserDefaultsSettings.Keys.paused, "paused")
    }
}
