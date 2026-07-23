import SwiftUI

/// Compact icon-button styling with a stable hit region and visible press state.
private struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.10 : 0))
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

/// Live elapsed and target metadata for a task within the selected daily workspace.
private struct TaskElapsedMetadataView: View {
    let task: Task
    let tickGenerator: TickGenerator

    var body: some View {
        let _ = tickGenerator.value
        HStack(spacing: 4) {
            Text(TimeFormatter.format(task.currentElapsed()))
                .fontDesign(.monospaced)
                .foregroundStyle(isOvertime ? .red : .secondary)

            if let target = task.targetTime, target > 0 {
                Text("/")
                Text(TimeFormatter.format(target))
                    .fontDesign(.monospaced)
            }

        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var isOvertime: Bool {
        guard let target = task.targetTime, target > 0 else { return false }
        return task.currentElapsed() > target
    }

}

/// Stable two-line task row with primary timer and secondary management actions.
struct TaskRowView: View {
    let task: Task
    let tickGenerator: TickGenerator
    let canEdit: Bool
    let canRun: Bool
    let canComplete: Bool
    let canCopy: Bool
    let copyDestinationText: String
    let onStart: (Task) -> Void
    let onPause: (Task) -> Void
    let onResume: (Task) -> Void
    let onComplete: (Task) -> Void
    let onUncomplete: (Task) -> Void
    let onEdit: (Task) -> Void
    let onDelete: (Task) -> Void
    let onCarry: (Task) -> Void
    let onRepeat: (Task) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            completionButton

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .help(task.name)

                TaskElapsedMetadataView(
                    task: task,
                    tickGenerator: tickGenerator
                )
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                HStack(spacing: 4) {
                    editButton
                    deleteButton
                }
                .opacity(showsManagementActions ? 1 : 0)
                .allowsHitTesting(showsManagementActions)
                .accessibilityHidden(!showsManagementActions)
                .animation(.easeOut(duration: 0.10), value: showsManagementActions)

                actionButton
            }
            .frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: PopoverLayout.taskRowHeight)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            if canEdit {
                Button {
                    onEdit(task)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete(task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if canCopy {
                if canEdit {
                    Divider()
                }

                if !task.isCompleted {
                    Button {
                        onCarry(task)
                    } label: {
                        Label(
                            "Carry to \(copyDestinationText)",
                            systemImage: "arrow.right"
                        )
                    }
                }

                Button {
                    onRepeat(task)
                } label: {
                    Label(
                        "Repeat on \(copyDestinationText)",
                        systemImage: "doc.on.doc"
                    )
                }
            }
        }
    }

    private var rowBackground: Color {
        if task.displayState == .running {
            return Color.accentColor.opacity(0.10)
        }
        if isHovered {
            return Color.primary.opacity(0.05)
        }
        return .clear
    }

    private var showsManagementActions: Bool {
        isHovered && canEdit
    }

    private var completionButton: some View {
        Button {
            if task.isCompleted {
                onUncomplete(task)
            } else {
                onComplete(task)
            }
        } label: {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundStyle(task.isCompleted ? .green : .secondary)
        }
        .buttonStyle(CompactIconButtonStyle())
        .disabled(!canComplete)
        .help(task.isCompleted ? "Mark as incomplete" : "Mark as completed")
        .accessibilityLabel(task.isCompleted ? "Mark as incomplete" : "Mark as completed")
    }

    private var editButton: some View {
        Button {
            onEdit(task)
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(CompactIconButtonStyle())
        .disabled(!canEdit)
        .help("Edit \"\(task.name)\"")
        .accessibilityLabel("Edit \(task.name)")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete(task)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(CompactIconButtonStyle())
        .disabled(!canEdit)
        .help("Delete \"\(task.name)\"")
        .accessibilityLabel("Delete \(task.name)")
    }

    @ViewBuilder
    private var actionButton: some View {
        if !canRun {
            Spacer()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        } else {
            switch task.displayState {
            case .completed:
                Spacer()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            case .running:
                Button { onPause(task) } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("Pause timer")
                .accessibilityLabel("Pause timer for \(task.name)")
            case .paused:
                Button { onResume(task) } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("Resume timer")
                .accessibilityLabel("Resume timer for \(task.name)")
            case .idle:
                Button { onStart(task) } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(CompactIconButtonStyle())
                .help("Start tracking")
                .accessibilityLabel("Start tracking \(task.name)")
            }
        }
    }
}
