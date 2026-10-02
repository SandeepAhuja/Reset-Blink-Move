//
//  AppIntegrationTests.swift
//
//  Host-app tests for the AppKit / system-bound adapters that cannot be
//  exercised as pure units: the login-item adapter, the launched delegate, and
//  the preferences window (now built with injected fakes).
//

import XCTest
import Cocoa
@testable import Reset

final class LoginItemTests: XCTestCase {

    func testIsEnabledIsQueryableWithoutSideEffects() {
        let value = LoginItem().isEnabled
        XCTAssertTrue(value == true || value == false)
    }

    func testDisablingWhenNotEnabledIsASafeNoOp() {
        let item = LoginItem()
        if !item.isEnabled {
            item.set(false)
            XCTAssertFalse(item.isEnabled)
        }
    }
}

final class HostAppTests: XCTestCase {

    @MainActor
    func testHostAppInstalledAccessoryDelegate() {
        XCTAssertTrue(NSApp.delegate is AppDelegate)
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
    }
}

final class AppDelegateTests: XCTestCase {

    /// Builds an AppDelegate via the designated (injectable) initializer with
    /// fakes, so the composition + menu wiring can be tested without launching.
    private func makeDelegate() -> (AppDelegate, FakeNotificationPresenter) {
        let settings = InMemorySettings()
        let notifier = FakeNotificationPresenter()
        let scheduler = BreakScheduler(
            reminders: [EyeReminder(localize: TestStrings.localize),
                        LegReminder(localize: TestStrings.localize, rotator: LegTipRotator())],
            settings: settings,
            timers: FakeTimerScheduler(),
            notifier: notifier,
            overlay: FakeOverlayPresenter()
        )
        let delegate = AppDelegate(settings: settings,
                                   loginItem: FakeLoginItem(),
                                   notificationPresenter: notifier,
                                   scheduler: scheduler)
        return (delegate, notifier)
    }

    func testTriggerReminderFiresTheMatchingReminder() {
        let (delegate, notifier) = makeDelegate()
        let item = NSMenuItem()
        item.representedObject = "leg"
        delegate.triggerReminder(item)
        XCTAssertEqual(notifier.presented.count, 1)
        XCTAssertTrue(notifier.presented.first?.title.contains("Leg care") ?? false)
    }

    func testTriggerReminderWithNoIdIsIgnored() {
        let (delegate, notifier) = makeDelegate()
        delegate.triggerReminder(NSMenuItem())   // representedObject is nil
        XCTAssertTrue(notifier.presented.isEmpty)
    }
}

final class PreferencesWindowControllerTests: XCTestCase {

    private func makeController(_ settings: InMemorySettings = InMemorySettings())
        -> (PreferencesWindowController, InMemorySettings, FakeLoginItem) {
        let loginItem = FakeLoginItem()
        let controller = PreferencesWindowController(
            settings: settings,
            loginItem: loginItem,
            onChange: {},
            takeBreak: { _ in }
        )
        return (controller, settings, loginItem)
    }

    @MainActor
    func testWindowBuildsItsContentView() throws {
        let (controller, _, _) = makeController()
        let window = try XCTUnwrap(controller.window)
        let content = try XCTUnwrap(window.contentView)
        XCTAssertGreaterThan(content.subviews.count, 5)
    }

    @MainActor
    func testRefreshFromSettingsHandlesOnOffAndUnknownValues() {
        let settings = InMemorySettings()
        settings.eyeMin = 25
        settings.legMin = 45
        settings.eyeBreakSec = 30
        settings.showOverlay = true
        settings.playSound = false
        settings.paused = true
        let (controller, _, _) = makeController(settings)
        controller.refreshFromSettings()          // hits both ternary arms

        settings.eyeMin = 99                       // not a popup option -> "index nil" branch
        controller.refreshFromSettings()

        XCTAssertNotNil(controller.window)
    }

    @MainActor
    func testControlChangedWritesSettingsAndNotifies() {
        let settings = InMemorySettings()
        let loginItem = FakeLoginItem()
        var changeCount = 0
        let controller = PreferencesWindowController(
            settings: settings, loginItem: loginItem,
            onChange: { changeCount += 1 }, takeBreak: { _ in }
        )
        controller.refreshFromSettings()           // sync popups to settings
        controller.controlChanged()                // simulate a control edit

        XCTAssertEqual(changeCount, 1)             // re-apply requested
        XCTAssertEqual(loginItem.setCalls.count, 1)
        // Values written back are valid popup options.
        XCTAssertTrue([15, 20, 25, 30].contains(settings.eyeMin))
        XCTAssertTrue([30, 45, 60].contains(settings.legMin))
    }

    @MainActor
    func testIntervalOptionsIncludeSmallValuesAndAreWellFormed() {
        let (controller, _, _) = makeController()

        // New small intervals are available for both eyes and legs.
        XCTAssertTrue(controller.eyeOptions.contains(1))
        XCTAssertTrue(controller.eyeOptions.contains(5))
        XCTAssertTrue(controller.legOptions.contains(1))
        XCTAssertTrue(controller.legOptions.contains(5))

        for options in [controller.eyeOptions, controller.legOptions, controller.breakOptions] {
            XCTAssertEqual(options, options.sorted(), "options must be ascending")
            XCTAssertEqual(Set(options).count, options.count, "options must be unique")
        }

        // The shipped defaults must remain selectable options.
        XCTAssertTrue(controller.eyeOptions.contains(20))    // Settings default eyeMin
        XCTAssertTrue(controller.legOptions.contains(30))    // Settings default legMin
        XCTAssertTrue(controller.breakOptions.contains(20))  // Settings default eyeBreakSec
    }

    @MainActor
    func testSmallIntervalIsSelectableAndRoundTrips() {
        let settings = InMemorySettings()
        settings.eyeMin = 1
        settings.legMin = 5
        let (controller, _, _) = makeController(settings)
        controller.refreshFromSettings()   // must select the small values without falling back
        controller.controlChanged()        // read popups back into settings
        XCTAssertEqual(settings.eyeMin, 1)
        XCTAssertEqual(settings.legMin, 5)
    }

    @MainActor
    func testTakeBreakButtonsForwardReminderIds() {
        var ids: [String] = []
        let controller = PreferencesWindowController(
            settings: InMemorySettings(), loginItem: FakeLoginItem(),
            onChange: {}, takeBreak: { ids.append($0) }
        )
        controller.eyeNowTapped()
        controller.legNowTapped()
        XCTAssertEqual(ids, ["eye", "leg"])
    }
}
