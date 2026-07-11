import SwiftUI

struct TaskRowView: View {
    let task: Task
    let onStart: (Task) -> Void
    let onPause: (Task) -> Void
    let onResume: (Task) -> Void
    let onComplete: (Task) -> Void
    let onUncomplete: (Task) -> Void
    let onRename: ((Task, String) -> Void)?
    let onUpdateTarget: ((Task, TimeInterval?) -> Void)?
    let onDelete: ((Task) -> Void)?

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editName: String = ""
    @State private var editHours: Int = 0
    @State private var editMinutes: Int = 0

    var body: some View {
        HStack(spacing: isEditing ? 0 : 8) {
            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("Task name", text: $editName)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .onSubmit { saveEdit() }
                        Button { saveEdit() } label: {
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help("Save changes")
                        Button { cancelEdit() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Cancel")
                    }
                    HStack(spacing: 4) {
                        TextField("0", value: $editHours, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .frame(width: 50)
                        Text("h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0", value: $editMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .frame(width: 50)
                        Text("m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
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
                        if let target = task.targetTime, target > 0 {
                            Text("/")
                            Text(TimeFormatter.format(target))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                actionButton

                if isHovered {
                    Button { enterEditMode() } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Edit \"\(task.name)\"")
                }

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
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .onHover { if !isEditing { isHovered = $0 } }
        .contextMenu {
            if !isEditing {
                if task.isCompleted {
                    Button("Uncomplete") { onUncomplete(task) }
                } else {
                    if task.isRunning {
                        Button("Pause") { onPause(task) }
                    } else {
                        Button("Start") { onStart(task) }
                    }
                    Divider()
                    Button("Rename") { enterEditMode() }
                }
                Divider()
                Button("Delete", role: .destructive) { onDelete?(task) }
            }
        }
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

    private func enterEditMode() {
        editName = task.name
        if let target = task.targetTime, target > 0 {
            editHours = Int(target) / 3600
            editMinutes = (Int(target) % 3600) / 60
        } else {
            editHours = 0
            editMinutes = 0
        }
        isEditing = true
    }

    private func saveEdit() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if trimmed != task.name {
            onRename?(task, trimmed)
        }
        let newTarget: TimeInterval? = (editHours > 0 || editMinutes > 0)
            ? TimeInterval(editHours * 3600 + editMinutes * 60)
            : nil
        onUpdateTarget?(task, newTarget)
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
    }
}
