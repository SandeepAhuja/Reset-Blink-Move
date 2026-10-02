//
//  UserNotificationPresenterTests.swift
//
//  Unit tests for the UNUserNotificationCenter-backed adapter. The foreground
//  presentation decision is tested directly; delivery is exercised as a
//  no-crash smoke test (posting to the center has no return value to assert).
//

import XCTest
import UserNotifications
@testable import Reset

final class UserNotificationPresenterTests: XCTestCase {

    func testPresentationOptionsWithSound() {
        let settings = InMemorySettings()
        settings.playSound = true
        let presenter = UserNotificationPresenter(settings: settings)
        XCTAssertEqual(presenter.presentationOptions(), [.banner, .sound])
    }

    func testPresentationOptionsWithoutSound() {
        let settings = InMemorySettings()
        settings.playSound = false
        let presenter = UserNotificationPresenter(settings: settings)
        let options = presenter.presentationOptions()
        XCTAssertEqual(options, [.banner])
        XCTAssertFalse(options.contains(.sound))
    }

    func testPresentDoesNotCrash() {
        let presenter = UserNotificationPresenter(settings: InMemorySettings())
        presenter.present(NotificationContent(title: "Title", body: "Body"))
        // Under the host app the request is enqueued; the point is that the
        // adapter path runs without throwing.
    }
}
