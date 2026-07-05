import SwiftUI

/// A single task row in the dropdown panel.
struct TaskRowView: View {
    let task: Task
    let onStart: (Task) -> Void
    let onPause: (Task) -> Void
    let onResume: (Task) -> Void
    let onComplete: (Task) -> Void
    let onUncomplete: (Task) -> Void
    let onEdit: ((Task) -> Void)?
    let onDelete: ((Task) -> Void)?
    let onMoveUp: ((Task) -> Void)?
    let onMoveDown: ((Task) -> Void)?
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if task.isCompleted {
                    onUncomplete(task)
                } else {
                    onComplete(task)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Mark as incomplete" : "Mark as completed")

            stateIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)

                HStack(spacing: 4) {
                    Text(TimeFormatter.format(task.currentElapsed()))
                    if let target = task.targetTime, target > 0 {
                        Text("/")
                        Text(TimeFormatter.format(target))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovered, !task.isCompleted {
                if let onMoveUp {
                    Button {
                        onMoveUp(task)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("Move up")
                }
                if let onMoveDown {
                    Button {
                        onMoveDown(task)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("Move down")
                }
            }

            actionButton

            Button {
                onDelete?(task)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete \"\(task.name)\"")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            isHovered ? Color.primary.opacity(0.05) : Color.clear
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 36)
        }
        .contextMenu {
            if task.isCompleted {
                Button("Uncomplete") { onUncomplete(task) }
            } else {
                if task.isRunning {
                    Button("Pause") { onPause(task) }
                } else {
                    Button("Start") { onStart(task) }
                }
                Divider()
                Button("Rename") { onEdit?(task) }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete?(task) }
        }
    }

    // MARK: State Indicator

    @ViewBuilder
    private var stateIndicator: some View {
        Group {
            switch task.displayState {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            case .running:
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            case .paused:
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            case .idle:
                Image(systemName: "circle")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 24)
    }

    // MARK: Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch task.displayState {
        case .completed:
            Text("Completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .running:
            Button("Pause") { onPause(task) }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Pause timer")
        case .paused:
            Button("Resume") { onResume(task) }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Resume timer")
        case .idle:
            Button("Start") { onStart(task) }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Start tracking")
        }
    }
}
