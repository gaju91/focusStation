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

    @objc private func handleSleep() {
        stopDisplayTimer()
    }

    @objc private func handleWake() {
        startDisplayTimer()
    }
}
