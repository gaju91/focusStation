import SwiftUI
import AppKit

/// The shared inline editor used for both task creation and editing.
struct TaskEditorRow: View {
    private enum FocusedField: Hashable {
        case name
        case hours
        case minutes
    }

    @Binding var editor: TaskEditorState
    let maximumTargetTime: TimeInterval
    let targetLimitMessage: String?
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: FocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Task name", text: $editor.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .focused($focusedField, equals: .name)
                .overlay(focusOutline(for: .name))
                .onSubmit(saveIfValid)
                .accessibilityLabel("Task name")

            HStack(spacing: 6) {
                Label("Target", systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .help("Maximum available: \(TimeFormatter.format(maximumTargetTime))")

                durationField(
                    value: nonnegativeBinding(\TaskEditorState.hours),
                    label: "h",
                    accessibilityLabel: "Target hours",
                    focusedField: .hours
                )
                durationField(
                    value: minuteBinding,
                    label: "m",
                    accessibilityLabel: "Target minutes",
                    focusedField: .minutes
                )

                if let targetLimitMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .help(targetLimitMessage)
                        .accessibilityLabel(targetLimitMessage)
                }

                Spacer(minLength: 4)

                Button("Cancel", action: onCancel)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
                    .help(cancelHelp)

                Button("Save", action: saveIfValid)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .help(saveHelp)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: PopoverLayout.editorRowHeight)
        .onAppear(perform: focusNameField)
        .onExitCommand(perform: onCancel)
    }

    private var canSave: Bool {
        !editor.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && targetLimitMessage == nil
    }

    private var saveHelp: String {
        switch editor.mode {
        case .create:
            return "Save task"
        case .edit:
            return "Save changes"
        }
    }

    private var cancelHelp: String {
        switch editor.mode {
        case .create:
            return "Discard task"
        case .edit:
            return "Cancel editing"
        }
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { editor.minutes },
            set: { editor.minutes = min(max(0, $0), 59) }
        )
    }

    private func nonnegativeBinding(
        _ keyPath: WritableKeyPath<TaskEditorState, Int>
    ) -> Binding<Int> {
        Binding(
            get: { editor[keyPath: keyPath] },
            set: { editor[keyPath: keyPath] = max(0, $0) }
        )
    }

    private func saveIfValid() {
        guard canSave else { return }
        onSave()
    }

    private func durationField(
        value: Binding<Int>,
        label: String,
        accessibilityLabel: String,
        focusedField field: FocusedField
    ) -> some View {
        HStack(spacing: 2) {
            TextField("0", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11).monospacedDigit())
                .frame(width: 38)
                .focused($focusedField, equals: field)
                .overlay(focusOutline(for: field))
                .accessibilityLabel(accessibilityLabel)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func focusOutline(for field: FocusedField) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .stroke(
                focusedField == field ? Color.accentColor : Color.clear,
                lineWidth: 2
            )
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.08), value: focusedField)
    }

    private func focusNameField() {
        Swift.Task { @MainActor in
            await Swift.Task.yield()
            focusedField = .name
        }
    }
}

/// Handles task reordering without relying on an NSTableView-backed List.
private struct TaskReorderDropDelegate: DropDelegate {
    let destinationTaskID: UUID
    @Binding var draggedTaskID: UUID?
    let onMove: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let sourceTaskID = draggedTaskID else { return }
        onMove(sourceTaskID, destinationTaskID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTaskID = nil
        return true
    }
}

/// Refined menu-bar popover with stable columns and content-driven sizing.
struct DropdownView: View {
    private let tickGenerator: TickGenerator

    @State private var viewModel: DropdownViewModel
    @State private var draggedTaskID: UUID?

    init(
        viewModel: DropdownViewModel,
        tickGenerator: TickGenerator
    ) {
        self.tickGenerator = tickGenerator
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            taskListView
            footerView
        }
        .frame(width: PopoverLayout.width)
        .background(.regularMaterial)
        .onAppear(perform: viewModel.refreshTasks)
        .alert(
            "Couldn’t Complete That Change",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel, action: viewModel.dismissError)
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected persistence error occurred.")
        }
    }

    private var headerView: some View {
        HStack(spacing: 0) {
            headerIconButton(
                systemName: "chevron.left",
                help: "Previous day",
                action: viewModel.showPreviousDay
            )
            .disabled(!viewModel.canNavigateDays)

            Button(action: viewModel.showToday) {
                VStack(spacing: 1) {
                    Text(viewModel.dateTitle)
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.daySummary)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 155)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isToday || !viewModel.canNavigateDays)
            .help(viewModel.isToday ? "Today" : "Return to Today")

            headerIconButton(
                systemName: "chevron.right",
                help: "Next day",
                action: viewModel.showNextDay
            )
            .disabled(!viewModel.canNavigateDays)

            Spacer(minLength: 4)

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 6)

            exportMenu

            headerIconButton(
                systemName: "xmark",
                help: "Quit FocusStation"
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: PopoverLayout.headerHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard viewModel.canNavigateDays else { return }
                    if value.translation.width > 40 {
                        viewModel.showPreviousDay()
                    } else if value.translation.width < -40 {
                        viewModel.showNextDay()
                    }
                }
        )
    }

    private var exportMenu: some View {
        Menu {
            Button("Export This Day…") {
                exportCSV(scope: .selectedDay(viewModel.selectedDay))
            }
            .disabled(!viewModel.hasSelectedDayToExport)

            Button("Export All History…") {
                exportCSV(scope: .allHistory)
            }
            .disabled(!viewModel.hasHistoryToExport)
        } label: {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help(viewModel.hasHistoryToExport ? "Export task history" : "No task history to export")
        .accessibilityLabel("Export task history")
    }

    private func headerIconButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .accessibilityLabel(help)
    }

    private var taskListView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    taskSection
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.editor?.id) { _, editorID in
                guard let editorID else { return }
                Swift.Task { @MainActor in
                    await Swift.Task.yield()
                    withAnimation(.easeOut(duration: 0.12)) {
                        scrollProxy.scrollTo(editorID, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var taskSection: some View {
        if viewModel.sortedTasks.isEmpty && !viewModel.isCreating {
            EmptyStateView(
                compact: false,
                title: emptyStateTitle
            )
        }

        ForEach(viewModel.sortedTasks) { task in
            taskEntry(task)
            if shouldShowDivider(after: task) {
                rowDivider
            }
        }

        if viewModel.isCreating, let editor = viewModel.editor {
            editorRow(editor)
        }
    }

    @ViewBuilder
    private func taskEntry(_ task: Task) -> some View {
        if viewModel.isEditing(task), let editor = viewModel.editor {
            editorRow(editor)
        } else {
            draggableTaskRow(task)
        }
    }

    @ViewBuilder
    private func draggableTaskRow(_ task: Task) -> some View {
        let row = taskRow(task)
        if viewModel.canBeginEditing {
            row
                .onDrag {
                    draggedTaskID = task.id
                    return NSItemProvider(object: task.id.uuidString as NSString)
                }
                .onDrop(
                    of: ["public.text"],
                    delegate: TaskReorderDropDelegate(
                        destinationTaskID: task.id,
                        draggedTaskID: $draggedTaskID,
                        onMove: viewModel.moveTask
                    )
                )
        } else {
            row
        }
    }

    private func taskRow(_ task: Task) -> some View {
        TaskRowView(
            task: task,
            tickGenerator: tickGenerator,
            canEdit: viewModel.canBeginEditing,
            canRun: viewModel.canRunSelectedDay,
            canComplete: viewModel.canCompleteSelectedDay,
            canCopy: viewModel.editor == nil,
            copyDestinationText: viewModel.carryDestinationText,
            onStart: viewModel.startTask,
            onPause: viewModel.pauseTask,
            onResume: viewModel.resumeTask,
            onComplete: viewModel.completeTask,
            onUncomplete: viewModel.uncompleteTask,
            onEdit: viewModel.beginEditing,
            onDelete: viewModel.deleteTask,
            onCarry: viewModel.carryTask,
            onRepeat: viewModel.repeatTask
        )
    }

    private func editorRow(_ editor: TaskEditorState) -> some View {
        TaskEditorRow(
            editor: Binding(
                get: { viewModel.editor ?? editor },
                set: { updatedEditor in
                    viewModel.updateEditor(updatedEditor)
                }
            ),
            maximumTargetTime: viewModel.maximumTargetTime,
            targetLimitMessage: viewModel.targetLimitMessage,
            onSave: { _ = viewModel.saveEditor() },
            onCancel: viewModel.cancelEditor
        )
        .id(editor.id)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 52)
    }

    private func shouldShowDivider(after task: Task) -> Bool {
        guard let lastTask = viewModel.sortedTasks.last else { return false }
        return task.id != lastTask.id || viewModel.isCreating
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            if viewModel.isPastDay {
                Button(action: viewModel.carryUnfinishedTasks) {
                    Label(
                        "Carry \(viewModel.activeTasks.count) to \(viewModel.carryDestinationText)",
                        systemImage: "arrow.right"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.activeTasks.isEmpty || !viewModel.canNavigateDays)
                .help("Carry unfinished tasks forward")
            } else {
                HStack(spacing: 0) {
                    Button(action: viewModel.beginCreating) {
                        Label("New Task", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.canBeginEditing ? .primary : .secondary)
                    .disabled(!viewModel.canBeginEditing)
                    .keyboardShortcut("n", modifiers: .command)
                    .help(viewModel.canBeginEditing ? "New task (⌘N)" : "Finish editing first")

                    if !viewModel.activeTasks.isEmpty {
                        Button(action: viewModel.carryUnfinishedTasks) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 36, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(!viewModel.canNavigateDays)
                        .help("Carry unfinished tasks to \(viewModel.carryDestinationText)")
                        .accessibilityLabel("Carry unfinished tasks to \(viewModel.carryDestinationText)")
                    }
                }
            }
        }
        .frame(height: PopoverLayout.footerHeight)
    }

    private var emptyStateTitle: String {
        if viewModel.isFutureDay {
            return "Nothing planned"
        }
        if viewModel.isPastDay {
            return "No tasks recorded"
        }
        return "No active tasks"
    }

    private func exportCSV(scope: HistoryExportScope) {
        guard let document = viewModel.exportDocument(scope: scope) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = document.suggestedFilename
        panel.canCreateDirectories = true
        panel.title = "Export FocusStation History"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try document.contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            viewModel.reportExportFailure()
        }
    }
}
