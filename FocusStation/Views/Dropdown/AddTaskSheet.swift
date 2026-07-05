import SwiftUI

struct AddTaskSheet: View {
    let viewModel: DropdownViewModel
    var existingTask: Task?
    var onDismiss: () -> Void

    @State private var taskName: String = ""
    @State private var targetHours: Int = 0
    @State private var targetMinutes: Int = 0
    @State private var showNameError: Bool = false

    private var isEditing: Bool { existingTask != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing ? "Edit Task" : "New Task")
                .font(.headline)

            TextField("Task name", text: $taskName)
                .textFieldStyle(.roundedBorder)
                .onChange(of: taskName) { _, _ in
                    if !taskName.trimmingCharacters(in: .whitespaces).isEmpty {
                        showNameError = false
                    }
                }
            if showNameError {
                Text("A name is required")
                    .font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 4) {
                Text("Target:")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("0", value: $targetHours, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 40)
                Text("h")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("0", value: $targetMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 40)
                Text("m")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)

                if !isEditing {
                    Button("Save & Add Another") {
                        save(keepOpen: true)
                    }
                }

                Spacer()

                Button("Save") {
                    save(keepOpen: false)
                }
                .keyboardShortcut(.return)
                .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .onAppear {
            if let task = existingTask {
                taskName = task.name
                if let target = task.targetTime {
                    targetHours = Int(target) / 3600
                    targetMinutes = (Int(target) % 3600) / 60
                } else {
                    targetHours = 0
                    targetMinutes = 0
                }
            }
        }
    }

    private func save(keepOpen: Bool) {
        let trimmed = taskName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showNameError = true
            return
        }
        let target: TimeInterval? = (targetHours > 0 || targetMinutes > 0)
            ? TimeInterval(targetHours * 3600 + targetMinutes * 60)
            : nil

        if let task = existingTask {
            viewModel.updateTaskName(task, to: trimmed)
            viewModel.updateTaskTarget(task, to: target)
        } else {
            viewModel.createTask(name: trimmed, iconName: IconProvider.defaultIcon, targetTime: target)
        }

        if keepOpen {
            taskName = ""
            targetHours = 0
            targetMinutes = 0
        } else {
            viewModel.taskToEdit = nil
            onDismiss()
        }
    }
}
