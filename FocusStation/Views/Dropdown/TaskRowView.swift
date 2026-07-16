import SwiftUI

struct TaskRowView: View {
    let task: Task
    let tick: Int
    let onStart: (Task) -> Void
    let onPause: (Task) -> Void
    let onResume: (Task) -> Void
    let onComplete: (Task) -> Void
    let onUncomplete: (Task) -> Void
    let onRename: ((Task, String) -> Void)?
    let onUpdateTarget: ((Task, TimeInterval?) -> Void)?
    let onEditBegin: (() -> Void)?
    let onEditEnd: (() -> Void)?
    let onDelete: ((Task) -> Void)?

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editPending = PendingTask()

    var body: some View {
        HStack(spacing: isEditing ? 0 : 8) {
            if isEditing {
                HStack(spacing: 0) {
                    TaskFormView(
                        name: $editPending.name,
                        hours: $editPending.hours,
                        minutes: $editPending.minutes,
                        onSave: { saveEdit() },
                        onCancel: { cancelEdit() },
                        saveHelp: "Save changes",
                        cancelHelp: "Cancel"
                    )
                }
            } else {
                Group {
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

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name)
                            .font(.body)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)

                        HStack(spacing: 4) {
                            Text(TimeFormatter.format(task.currentElapsed()))
                                .foregroundStyle(isOvertime ? .red : .secondary)
                            if let target = task.targetTime, target > 0 {
                                Text("/")
                                Text(TimeFormatter.format(target))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    if isHovered {
                        Button { enterEditMode() } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Edit \"\(task.name)\"")

                        Button {
                            onDelete?(task)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Delete \"\(task.name)\"")
                    }

                    actionButton
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .onHover { if !isEditing { isHovered = $0 } }
    }

    // MARK: Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch task.displayState {
        case .completed:
            Button { onUncomplete(task) } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Mark as incomplete")
        case .running:
            Button { onPause(task) } label: {
                Image(systemName: "pause.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help("Pause timer")
        case .paused:
            Button { onResume(task) } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Resume timer")
        case .idle:
            Button { onStart(task) } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Start tracking")
        }
    }

    // MARK: Edit Helpers

    private var isOvertime: Bool {
        guard let target = task.targetTime, target > 0 else { return false }
        return task.currentElapsed() > target
    }

    private func enterEditMode() {
        onEditBegin?()
        editPending.name = task.name
        if let target = task.targetTime, target > 0 {
            editPending.hours = Int(target) / 3600
            editPending.minutes = (Int(target) % 3600) / 60
        } else {
            editPending.hours = 0
            editPending.minutes = 0
        }
        isEditing = true
    }

    private func saveEdit() {
        let trimmed = editPending.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if trimmed != task.name {
            onRename?(task, trimmed)
        }
        let newTarget: TimeInterval? = (editPending.hours > 0 || editPending.minutes > 0)
            ? TimeInterval(editPending.hours * 3600 + editPending.minutes * 60)
            : nil
        onUpdateTarget?(task, newTarget)
        onEditEnd?()
        isEditing = false
        editPending = PendingTask()
    }

    private func cancelEdit() {
        onEditEnd?()
        isEditing = false
        editPending = PendingTask()
    }
}
