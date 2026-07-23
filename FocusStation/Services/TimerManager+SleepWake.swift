import AppKit

extension TimerManager {
    /// Start observing sleep/wake notifications.
    /// Called once from TimerManager.init.
    func observeSleepWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
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

    @objc private func handleSleep() {
        pauseAllRunningTasks()
    }

    @objc private func handleWake() {
        refreshTasks()
        reconcileDayBoundary(at: .now)
    }
}
