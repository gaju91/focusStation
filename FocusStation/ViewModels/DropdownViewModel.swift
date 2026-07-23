import Foundation
import Observation

/// Transient input state for one create or edit operation.
struct TaskEditorState: Identifiable {
    /// The persistence operation performed when the editor is saved.
    enum Mode: Equatable {
        case create
        case edit(taskID: UUID)
    }

    let id: UUID
    let mode: Mode
    var name: String
    var hours: Int
    var minutes: Int

    init(
        id: UUID = UUID(),
        mode: Mode = .create,
        name: String = "",
        hours: Int = 0,
        minutes: Int = 0
    ) {
        self.id = id
        self.mode = mode
        self.name = name
        self.hours = hours
        self.minutes = minutes
    }

    /// A normalized optional target duration derived from the editor fields.
    var targetTime: TimeInterval? {
        let safeHours = max(0, hours)
        let safeMinutes = min(max(0, minutes), 59)
        guard safeHours > 0 || safeMinutes > 0 else { return nil }
        let (hourSeconds, hourOverflow) = safeHours.multipliedReportingOverflow(by: 3600)
        let minuteSeconds = safeMinutes * 60
        let (totalSeconds, totalOverflow) = hourSeconds.addingReportingOverflow(minuteSeconds)
        guard !hourOverflow, !totalOverflow else { return .greatestFiniteMagnitude }
        return TimeInterval(totalSeconds)
    }
}

/// Owns one selected daily workspace and delegates persisted mutations.
@Observable
final class DropdownViewModel {
    private(set) var tasks: [Task] = []
    private(set) var errorMessage: String?
    private(set) var revision = 0
    var selectedDay: LocalDay
    var editor: TaskEditorState?

    private let timerManager: any TimerManagerProtocol
    private var observedToday: LocalDay

    init(
        timerManager: any TimerManagerProtocol,
        selectedDay: LocalDay = .today
    ) {
        self.timerManager = timerManager
        self.selectedDay = selectedDay
        self.observedToday = .today
        refreshTasks()
    }

    var isEmpty: Bool { sortedTasks.isEmpty }

    var sortedTasks: [Task] {
        tasks
            .filter { $0.isScheduled(on: selectedDay, today: observedToday) }
            .sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.displayOrder < rhs.displayOrder
            }
    }

    var activeTasks: [Task] {
        sortedTasks.filter { !$0.isCompleted }
    }

    var completedTasks: [Task] {
        sortedTasks.filter(\.isCompleted)
    }

    var isCreating: Bool {
        editor?.mode == .create
    }

    var isToday: Bool {
        selectedDay == observedToday
    }

    var isPastDay: Bool {
        selectedDay < observedToday
    }

    var isFutureDay: Bool {
        selectedDay > observedToday
    }

    var canBeginEditing: Bool {
        editor == nil && !isPastDay
    }

    var canNavigateDays: Bool {
        editor == nil
    }

    var canRunSelectedDay: Bool {
        isToday && editor == nil
    }

    var canCompleteSelectedDay: Bool {
        isToday && editor == nil
    }

    var dateTitle: String {
        let dateText = shortDateText(for: selectedDay)
        if isToday {
            return "Today · \(dateText)"
        }
        if selectedDay == observedToday.addingDays(-1) {
            return "Yesterday · \(dateText)"
        }
        let date = selectedDay.representativeDate()
        let selectedYear = Calendar.current.component(.year, from: date)
        let currentYear = Calendar.current.component(.year, from: .now)
        if selectedYear == currentYear {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        return date.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated).year()
        )
    }

    var daySummary: String {
        let taskCount = sortedTasks.count
        let completedCount = completedTasks.count
        let total = sortedTasks.reduce(0) { result, task in
            result + task.currentElapsed()
        }
        guard taskCount > 0 else {
            return isFutureDay ? "Plan this day" : "No tasks"
        }
        let taskLabel = taskCount == 1 ? "task" : "tasks"
        return "\(taskCount) \(taskLabel) · \(completedCount) done · \(TimeFormatter.format(total))"
    }

    var maximumTargetTime: TimeInterval {
        let editedTaskID: UUID?
        switch editor?.mode {
        case .edit(let taskID):
            editedTaskID = taskID
        case .create, nil:
            editedTaskID = nil
        }
        return availableTargetCapacity(on: selectedDay, excluding: editedTaskID)
    }

    var targetLimitMessage: String? {
        guard
            let target = editor?.targetTime,
            target > maximumTargetTime
        else { return nil }
        return "Maximum available is \(TimeFormatter.format(maximumTargetTime))"
    }

    var hasHistoryToExport: Bool {
        tasks.contains { $0.scheduledDayKey != nil }
    }

    var hasSelectedDayToExport: Bool {
        !sortedTasks.isEmpty
    }

    var carryDestination: LocalDay {
        let adjacent = selectedDay.addingDays(1)
        return adjacent < observedToday ? observedToday : adjacent
    }

    var carryDestinationText: String {
        carryDestination == observedToday
            ? "Today"
            : shortDateText(for: carryDestination)
    }

    func refreshTasks() {
        timerManager.reconcileDayBoundary(at: .now)
        let currentToday = LocalDay.today
        if selectedDay == observedToday {
            selectedDay = currentToday
        }
        if currentToday != observedToday, editor != nil {
            editor = nil
        }
        observedToday = currentToday
        tasks = timerManager.tasks
        errorMessage = timerManager.errorMessage
        revision &+= 1
    }

    func dismissError() {
        timerManager.clearError()
        errorMessage = nil
    }

    func showPreviousDay() {
        guard canNavigateDays else { return }
        selectedDay = selectedDay.addingDays(-1)
        revision &+= 1
    }

    func showNextDay() {
        guard canNavigateDays else { return }
        selectedDay = selectedDay.addingDays(1)
        revision &+= 1
    }

    func showToday() {
        guard canNavigateDays else { return }
        selectedDay = observedToday
        revision &+= 1
    }

    // MARK: Editor

    func beginCreating() {
        guard canBeginEditing else { return }
        editor = TaskEditorState()
    }

    func beginEditing(_ task: Task) {
        guard canBeginEditing else { return }
        let targetSeconds = max(0, Int(task.targetTime ?? 0))
        editor = TaskEditorState(
            mode: .edit(taskID: task.id),
            name: task.name,
            hours: targetSeconds / 3600,
            minutes: (targetSeconds % 3600) / 60
        )
    }

    func isEditing(_ task: Task) -> Bool {
        editor?.mode == .edit(taskID: task.id)
    }

    /// Accepts field changes only while their editor session is still active.
    func updateEditor(_ updatedEditor: TaskEditorState) {
        guard editor?.id == updatedEditor.id else { return }
        editor = updatedEditor
    }

    @discardableResult
    func saveEditor() -> Bool {
        guard let editor, targetLimitMessage == nil else { return false }
        let name = editor.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }

        switch editor.mode {
        case .create:
            let nextOrder = (sortedTasks.map(\.displayOrder).max() ?? -1) + 1
            _ = timerManager.createTask(
                name: name,
                iconName: IconProvider.defaultIcon,
                targetTime: editor.targetTime,
                displayOrder: nextOrder,
                scheduledDayKey: selectedDay.key,
                lineageID: nil
            )
        case .edit(let taskID):
            guard let task = tasks.first(where: { $0.id == taskID }) else {
                self.editor = nil
                refreshTasks()
                return false
            }
            timerManager.update(
                task: task,
                name: name,
                targetTime: editor.targetTime
            )
        }

        self.editor = nil
        refreshTasks()
        return true
    }

    func cancelEditor() {
        editor = nil
    }

    // MARK: Timer Actions

    func startTask(_ task: Task) {
        guard canRunSelectedDay else { return }
        timerManager.start(task: task)
        refreshTasks()
    }

    func pauseTask(_ task: Task) {
        guard canRunSelectedDay, task.isRunning else { return }
        timerManager.pause(task: task)
        refreshTasks()
    }

    func resumeTask(_ task: Task) {
        guard canRunSelectedDay, !task.isRunning, !task.isCompleted else { return }
        timerManager.resume(task: task)
        refreshTasks()
    }

    // MARK: CRUD and Copy

    func deleteTask(_ task: Task) {
        guard !isPastDay else { return }
        if isEditing(task) {
            editor = nil
        }
        timerManager.delete(task: task)
        refreshTasks()
    }

    func completeTask(_ task: Task) {
        guard canCompleteSelectedDay else { return }
        timerManager.complete(task: task)
        refreshTasks()
    }

    func uncompleteTask(_ task: Task) {
        guard canCompleteSelectedDay else { return }
        timerManager.uncomplete(task: task)
        refreshTasks()
    }

    func carryTask(_ task: Task) {
        let destination = carryDestination
        guard copyTask(task, to: destination, usesRemainingTarget: true) else { return }
        selectedDay = destination
        refreshTasks()
    }

    func repeatTask(_ task: Task) {
        let destination = carryDestination
        guard copyTask(task, to: destination, usesRemainingTarget: false) else { return }
        selectedDay = destination
        refreshTasks()
    }

    func carryUnfinishedTasks() {
        let destination = carryDestination
        let tasksToCopy = activeTasks.filter { task in
            !timerManager.tasks.contains { candidate in
                candidate.scheduledDayKey == destination.key
                    && candidate.effectiveLineageID == task.effectiveLineageID
            }
        }
        let proposedTargets = tasksToCopy.compactMap { remainingTarget(for: $0) }
        guard proposedTargets.reduce(0, +) <= availableTargetCapacity(on: destination) else {
            errorMessage = "These tasks need more focus time than \(carryDestinationText) has available."
            return
        }
        for task in tasksToCopy {
            _ = copyTask(task, to: destination, usesRemainingTarget: true)
        }
        selectedDay = destination
        refreshTasks()
    }

    func exportDocument(scope: HistoryExportScope) -> HistoryCSVDocument? {
        HistoryCSVExporter.makeDocument(tasks: tasks, scope: scope)
    }

    func reportExportFailure() {
        errorMessage = "FocusStation couldn’t save the CSV export."
    }

    func moveTask(_ sourceID: UUID, toward destinationID: UUID) {
        guard canBeginEditing, sourceID != destinationID else { return }
        var ordered = sortedTasks
        guard
            let sourceIndex = ordered.firstIndex(where: { $0.id == sourceID }),
            let destinationIndex = ordered.firstIndex(where: { $0.id == destinationID })
        else { return }

        let task = ordered.remove(at: sourceIndex)
        let insertionIndex = min(destinationIndex, ordered.count)
        ordered.insert(task, at: insertionIndex)
        timerManager.reorderTasks(ordered)
        refreshTasks()
    }

    private func copyTask(
        _ task: Task,
        to destination: LocalDay? = nil,
        usesRemainingTarget: Bool
    ) -> Bool {
        let destination = destination ?? carryDestination
        let lineageID = task.effectiveLineageID
        let alreadyCopied = timerManager.tasks.contains { candidate in
            candidate.scheduledDayKey == destination.key
                && candidate.effectiveLineageID == lineageID
        }
        guard !alreadyCopied else { return true }

        let proposedTarget: TimeInterval?
        if usesRemainingTarget, task.targetTime != nil {
            proposedTarget = remainingTarget(for: task)
        } else {
            proposedTarget = task.targetTime
        }
        let destinationLimit = availableTargetCapacity(on: destination)
        if let proposedTarget, proposedTarget > destinationLimit {
            errorMessage = "This task needs \(TimeFormatter.format(proposedTarget)), but \(carryDestinationText) only has \(TimeFormatter.format(destinationLimit)) available."
            return false
        }
        let destinationTasks = timerManager.tasks.filter {
            $0.scheduledDayKey == destination.key
        }
        let nextOrder = (destinationTasks.map(\.displayOrder).max() ?? -1) + 1
        _ = timerManager.createTask(
            name: task.name,
            iconName: task.iconName,
            targetTime: proposedTarget,
            displayOrder: nextOrder,
            scheduledDayKey: destination.key,
            lineageID: lineageID
        )
        return true
    }

    private func shortDateText(for day: LocalDay) -> String {
        day.representativeDate().formatted(.dateTime.day().month(.abbreviated))
    }

    private func remainingTarget(for task: Task) -> TimeInterval? {
        guard let target = task.targetTime else { return nil }
        let remaining = max(0, target - task.currentElapsed())
        return remaining > 0 ? remaining : nil
    }

    private func availableTargetCapacity(
        on day: LocalDay,
        excluding taskID: UUID? = nil
    ) -> TimeInterval {
        let plannedDuration = timerManager.tasks.reduce(0) { result, task in
            guard
                task.id != taskID,
                task.scheduledDayKey == day.key,
                !task.isCompleted,
                let target = task.targetTime,
                target > 0
            else { return result }

            let remaining = day == observedToday
                ? max(0, target - task.currentElapsed())
                : target
            return result + remaining
        }
        return max(0, day.availableDuration() - plannedDuration)
    }
}
