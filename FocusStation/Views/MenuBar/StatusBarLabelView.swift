import SwiftUI

/// Status bar item label: single active task.
/// Running: `🧠 Research 1h23m / 3h00m`
/// Paused:  `🧠 Research 45m`
/// Idle:    `🧠`
struct StatusBarLabelView: View {
    let timerManager: any TimerManagerProtocol
    let tick: Int

    var body: some View {
        let _ = tick
        let tasks = timerManager.tasks
        if let task = tasks.first(where: { $0.displayState == .running }) {
            runningRow(for: task)
        } else if let task = tasks.first(where: { $0.displayState == .paused }) {
            pausedRow(for: task)
        } else {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
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
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(task.name)
            if elapsed > 0 {
                Text(TimeFormatter.format(elapsed))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(elapsedColor(for: task))
                    .fixedSize()
                if hasTarget {
                    Text("/")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                        .fixedSize()
                    Text(TimeFormatter.format(task.targetTime ?? 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func pausedRow(for task: Task) -> some View {
        HStack(spacing: 4) {
            taskIcon(task)
            Text(task.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(task.name)
            if task.accumulatedElapsed > 0 {
                Text(TimeFormatter.format(task.accumulatedElapsed))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(elapsedColor(for: task))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 6)
    }

    private func taskIcon(_ task: Task) -> some View {
        Image(systemName: task.iconName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private func elapsedColor(for task: Task) -> Color {
        switch task.elapsedTone() {
        case .withinLimit:
            return .green
        case .paused:
            return .orange
        case .overdue:
            return .red
        }
    }
}
