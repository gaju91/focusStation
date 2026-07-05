import Foundation

/// Produces a 1s tick for menu bar label updates.
/// Timer fires on the main RunLoop; @MainActor guarantees safe
/// mutation of the @Observable value property.
@MainActor
@Observable
final class TickGenerator {
    var value: Int = 0
    private var timer: Timer?

    init() {
        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(increment),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        timer.fire()
        self.timer = timer
    }

    @objc private func increment() {
        value &+= 1
    }

    deinit {
        MainActor.assumeIsolated {
            timer?.invalidate()
        }
    }
}
