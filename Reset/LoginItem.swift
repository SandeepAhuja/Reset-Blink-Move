//
//  LoginItem.swift
//
//  Production adapter for `LoginItemManaging`, backed by SMAppService.
//

import Foundation
import ServiceManagement

final class LoginItem: LoginItemManaging {

    var isEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    func set(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                } else {
                    if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                }
            } catch {
                NSLog("Launch at login change failed: \(error)")
            }
        }
    }
}
