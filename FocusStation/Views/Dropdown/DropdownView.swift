import AppKit
import SwiftData
import SwiftUI

struct DropdownView: View {
    @Environment(\.timerManager) private var timerManager: any TimerManagerProtocol
    @Environment(\.modelContext) private var modelContext: ModelContext

    @AppStorage("hideCompleted") private var hideCompleted: Bool = false
    @State private var viewModel: DropdownViewModel?
    @State private var isShowingForm: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if isShowingForm, let vm = viewModel {
                AddTaskSheet(viewModel: vm, existingTask: vm.taskToEdit, onDismiss: { isShowingForm = false })
            } else if viewModel?.isEmpty ?? true {
                EmptyStateView()
                    .frame(maxHeight: 300)
            } else {
                taskListView
            }

            if !isShowingForm {
                footerView
            }
        }
        .frame(width: 260)
        .frame(minHeight: 340)
        .onAppear {
            if viewModel == nil {
                viewModel = DropdownViewModel(timerManager: timerManager)
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(isShowingForm
                     ? (viewModel?.taskToEdit != nil ? "Edit Task" : "New Task")
                     : "FocusStation")
                    .font(.headline)
                Spacer()
                if !isShowingForm {
                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } label: {
                        Image(systemName: "gearshape").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).help("Settings")
                    Button { NSApplication.shared.terminate(nil) } label: {
                        Image(systemName: "xmark.circle").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).help("Quit")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
        }
    }

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let tasks = viewModel?.sortedTasks {
                    let visible = hideCompleted
                        ? tasks.filter { $0.displayState != .completed }
                        : tasks
                    ForEach(visible) { task in
                        TaskRowView(
                            task: task,
                            onStart: { viewModel?.startTask($0) },
                            onPause: { viewModel?.pauseTask($0) },
                            onResume: { viewModel?.resumeTask($0) },
                            onComplete: { viewModel?.completeTask($0) },
                            onUncomplete: { viewModel?.uncompleteTask($0) },
                            onEdit: {
                                viewModel?.taskToEdit = $0
                                isShowingForm = true
                            },
                            onDelete: { viewModel?.deleteTask($0) },
                            onMoveUp: { viewModel?.moveTaskUp($0) },
                            onMoveDown: { viewModel?.moveTaskDown($0) }
                        )
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                viewModel?.taskToEdit = nil
                isShowingForm = true
            } label: {
                Label("Add Task", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(.vertical, 6)
        }
    }
}
