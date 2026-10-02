//
//  UserNotificationPresenter.swift
//
//  Production adapter for `NotificationPresenting`, backed by
//  UNUserNotificationCenter. Also acts as the center's delegate so foreground
//  presentation honors the "play sound" setting. Guards against a missing bundle
//  identifier (e.g. under a bare test runner) by disabling delivery.
//

import Foundation
import UserNotifications

final class UserNotificationPresenter: NSObject, NotificationPresenting, UNUserNotificationCenterDelegate {

    private let settings: SettingsProviding
    private let center: UNUserNotificationCenter?

    init(settings: SettingsProviding) {
        self.settings = settings
        self.center = (Bundle.main.bundleIdentifier != nil) ? .current() : nil
        super.init()
        center?.delegate = self
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func present(_ content: NotificationContent) {
        guard let center else { return }
        let payload = UNMutableNotificationContent()
        payload.title = content.title
        payload.body = content.body
        payload.sound = settings.playSound ? .default : nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: payload, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(presentationOptions())
    }

    /// Foreground presentation options, honoring the sound setting.
    /// Extracted so the decision is unit-testable without a `UNNotification`.
    func presentationOptions() -> UNNotificationPresentationOptions {
        settings.playSound ? [.banner, .sound] : [.banner]
    }
}
