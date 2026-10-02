//
//  RealTimerScheduler.swift
//
//  Production adapter for `RepeatingTimerScheduling`, backed by `Timer`.
//

import Foundation

final class RealTimerScheduler: RepeatingTimerScheduling {
    func scheduleRepeating(every interval: TimeInterval, _ block: @escaping () -> Void) -> Cancellable {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in block() }
        return TimerCancellable(timer)
    }
}

private final class TimerCancellable: Cancellable {
    private let timer: Timer
    init(_ timer: Timer) { self.timer = timer }
    func cancel() { timer.invalidate() }
    deinit { timer.invalidate() }
}
