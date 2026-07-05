import SwiftUI

/// Status bar item label: single active task.
/// Running: `🧠 Research 1h23m / 3h00m`
/// Paused:  `🧠 Research 45m`
/// Idle:    `🧠`
struct StatusBarLabelView: View {
    let timerManager: any TimerManagerProtocol

    var body: some View {
        let tasks = timerManager.tasks
        if let task = tasks.first(where: { $0.displayState == .running }) {
            runningRow(for: task)
        } else if let task = tasks.first(where: { $0.displayState == .paused }) {
            pausedRow(for: task)
        } else {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12))
        }
    }

    @ViewBuilder
    private func runningRow(for task: Task) -> some View {
        let elapsed = task.currentElapsed()
        let hasTarget = (task.targetTime ?? 0) > 0

        HStack(spacing: 4) {
            taskIcon(task)
            Text(task.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            if elapsed > 0 {
                Text(TimeFormatter.format(elapsed))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                if hasTarget {
                    Text("/")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                    Text(TimeFormatter.format(task.targetTime ?? 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                }
            }
        }
    }

    @ViewBuilder
    private func pausedRow(for task: Task) -> some View {
        HStack(spacing: 4) {
            taskIcon(task)
            Text(task.name)
                .font(.system(size: 11))
                .lineLimit(1)
            if task.accumulatedElapsed > 0 {
                Text(TimeFormatter.format(task.accumulatedElapsed))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func taskIcon(_ task: Task) -> some View {
        Image(systemName: task.iconName)
            .font(.system(size: 11, weight: .semibold))
    }
}
