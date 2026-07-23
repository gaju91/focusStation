import AppKit

extension TimerManager {
    /// Observe wake notifications so a task that crossed midnight while the Mac
    /// slept is capped at its scheduled day boundary. Same-day sleep deliberately
    /// leaves the timestamp-based timer running.
    /// Called once from TimerManager.init.
    func observeSleepWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    /// Stop observing workspace notifications before the service is released.
    func stopObservingSleepWake() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleWake() {
        refreshTasks()
        reconcileDayBoundary(at: .now)
    }
}
