//
//  Settings.swift
//
//  `SettingsProviding` is the abstraction the app depends on (Dependency
//  Inversion); `UserDefaultsSettings` is the production implementation backed by
//  UserDefaults. Tests supply their own conforming type (an in-memory fake or a
//  UserDefaults suite), so nothing ever touches the user's real preferences.
//

import Foundation

protocol SettingsProviding: AnyObject {
    var eyeMin: Int { get set }
    var legMin: Int { get set }
    var eyeBreakSec: Int { get set }
    var showOverlay: Bool { get set }
    var playSound: Bool { get set }
    var paused: Bool { get set }
    func registerDefaults()
}

final class UserDefaultsSettings: SettingsProviding {

    enum Keys {
        static let eyeMin      = "eyeIntervalMin"
        static let legMin      = "legIntervalMin"
        static let eyeBreakSec = "eyeBreakSec"
        static let showOverlay = "showOverlay"
        static let playSound   = "playSound"
        static let paused      = "paused"
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    func registerDefaults() {
        store.register(defaults: [
            Keys.eyeMin: 20,
            Keys.legMin: 30,
            Keys.eyeBreakSec: 20,
            Keys.showOverlay: true,
            Keys.playSound: true,
            Keys.paused: false
        ])
    }

    var eyeMin: Int  { get { store.integer(forKey: Keys.eyeMin) }  set { store.set(newValue, forKey: Keys.eyeMin) } }
    var legMin: Int  { get { store.integer(forKey: Keys.legMin) }  set { store.set(newValue, forKey: Keys.legMin) } }
    var eyeBreakSec: Int { get { store.integer(forKey: Keys.eyeBreakSec) } set { store.set(newValue, forKey: Keys.eyeBreakSec) } }
    var showOverlay: Bool { get { store.bool(forKey: Keys.showOverlay) } set { store.set(newValue, forKey: Keys.showOverlay) } }
    var playSound: Bool   { get { store.bool(forKey: Keys.playSound) }   set { store.set(newValue, forKey: Keys.playSound) } }
    var paused: Bool      { get { store.bool(forKey: Keys.paused) }      set { store.set(newValue, forKey: Keys.paused) } }
}
