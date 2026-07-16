import AppKit
import SwiftUI

/// Shared inline task form — used by both pending creation and edit mode.
struct TaskFormView: View {
    @Binding var name: String
    @Binding var hours: Int
    @Binding var minutes: Int
    let onSave: () -> Void
    let onCancel: () -> Void
    let saveHelp: String
    let cancelHelp: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                TextField("Task name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit { onSave() }
                Button { onSave() } label: {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help(saveHelp)
                Button { onCancel() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(cancelHelp)
            }
            HStack(spacing: 4) {
                TextField("0", value: $hours, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 50)
                Text("h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0", value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 50)
                Text("m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Pending task row shown inline in the task list before creation.
struct PendingTaskRowView: View {
    @Binding var row: PendingTask
    let onSave: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TaskFormView(
                name: $row.name,
                hours: $row.hours,
                minutes: $row.minutes,
                onSave: onSave,
                onCancel: onDiscard,
                saveHelp: "Save task",
                cancelHelp: "Discard"
            )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }
}

@MainActor
private final class TickDriver: NSObject {
    var onFire: (() -> Void)?
    private var timer: Timer?

    func start() {
        stop()
        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(fire),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func fire() {
        onFire?()
    }
}

/// Pending task before creation — holds inline input state.
struct PendingTask: Identifiable {
    let id = UUID()
    var name = ""
    var hours = 0
    var minutes = 0
}

struct DropdownView: View {
    @Environment(\.timerManager) private var timerManager: any TimerManagerProtocol

    @State private var viewModel: DropdownViewModel?
    @State private var pendingRows: [PendingTask] = []
    @State private var displayTick = 0
    @State private var tickDriver = TickDriver()

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if (viewModel?.isEmpty ?? true) && pendingRows.isEmpty {
                EmptyStateView()
                    .frame(maxHeight: 300)
            } else {
                taskListView
            }

            footerView
        }
        .frame(minWidth: 230, maxWidth: 400)
        .onAppear {
            if viewModel == nil {
                viewModel = DropdownViewModel(timerManager: timerManager)
            }
            tickDriver.onFire = { displayTick &+= 1 }
            tickDriver.start()
        }
        .onDisappear {
            tickDriver.stop()
        }
    }

    // MARK: Header

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("FocusStation")
                    .font(.headline)
                Spacer()
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "xmark.circle").font(.system(size: 12))
                }
                .buttonStyle(.plain).help("Quit")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
        }
    }

    // MARK: Task List

    private var taskListView: some View {
        List {
            if let tasks = viewModel?.sortedTasks {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        tick: displayTick,
                        onStart: { viewModel?.startTask($0) },
                        onPause: { viewModel?.pauseTask($0) },
                        onResume: { viewModel?.resumeTask($0) },
                        onComplete: { viewModel?.completeTask($0) },
                        onUncomplete: { viewModel?.uncompleteTask($0) },
                        onRename: { task, newName in
                            viewModel?.updateTaskName(task, to: newName)
                        },
                        onUpdateTarget: { task, target in
                            viewModel?.updateTaskTarget(task, to: target)
                        },
                        onEditBegin: { viewModel?.suspendSync() },
                        onEditEnd: { viewModel?.resumeSync() },
                        onDelete: { viewModel?.deleteTask($0) }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .onMove { indices, destination in
                    viewModel?.reorderTasks(from: indices, to: destination)
                }
            }

            if !pendingRows.isEmpty, viewModel?.isEmpty == false {
                Divider()
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            ForEach($pendingRows) { $row in
                PendingTaskRowView(
                    row: $row,
                    onSave: { createTask(from: row.id) },
                    onDiscard: { pendingRows.removeAll { $0.id == row.id } }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
        .listStyle(.plain)
    }

    // MARK: Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                pendingRows.append(PendingTask())
            } label: {
                Label("Add Task", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(.vertical, 6)
        }
    }

    // MARK: Helpers

    private func createTask(from id: UUID) {
        guard let index = pendingRows.firstIndex(where: { $0.id == id }) else { return }
        let row = pendingRows[index]
        let trimmed = row.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let target: TimeInterval? = (row.hours > 0 || row.minutes > 0)
            ? TimeInterval(row.hours * 3600 + row.minutes * 60)
            : nil
        viewModel?.createTask(name: trimmed, iconName: IconProvider.defaultIcon, targetTime: target)
        pendingRows.remove(at: index)
    }
}
