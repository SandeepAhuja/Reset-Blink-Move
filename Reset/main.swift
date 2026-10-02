//
//  main.swift
//
//  Entry point only. This is the one file allowed to contain top-level
//  executable code, so it is kept deliberately tiny — all application logic
//  lives in its own file/type:
//
//    • Settings.swift                    – persisted preferences
//    • ReminderEngine.swift              – pure, unit-tested logic
//    • AppDelegate.swift                 – menu bar, notifications, scheduling
//    • PreferencesWindowController.swift – preferences UI
//    • LaunchAtLogin.swift               – login-item wrapper
//

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
