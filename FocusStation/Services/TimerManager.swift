import Foundation
import Observation
import SwiftData

@Observable
final class TimerManager: TimerManagerProtocol {
    var tasks: [Task] = []
    private(set) var errorMessage: String?

    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        observeSleepWake()
        refreshTasks()
        migrateLegacyTasksIfNeeded()
        reconcileDayBoundary(at: .now)
    }

    deinit {
        stopObservingSleepWake()
    }

    // MARK: Timer Actions

    func start(task: Task) {
        guard
            !task.isRunning,
            !task.isCompleted,
            task.isScheduled(on: .today)
        else { return }
        pauseOtherRunningTasks(except: task)
        task.isRunning = true
        task.startedAt = .now
        saveChanges()
    }

    func pause(task: Task) {
        guard task.isRunning else { return }
        task.accumulatedElapsed = task.currentElapsed()
        task.isRunning = false
        task.startedAt = nil
        saveChanges()
    }

    func resume(task: Task) {
        guard
            !task.isRunning,
            !task.isCompleted,
            task.isScheduled(on: .today)
        else { return }
        pauseOtherRunningTasks(except: task)
        task.isRunning = true
        task.startedAt = .now
        saveChanges()
    }

    private func pauseOtherRunningTasks(except target: Task) {
        for t in tasks where t.isRunning && t.id != target.id {
            t.accumulatedElapsed = t.currentElapsed()
            t.isRunning = false
            t.startedAt = nil
        }
    }

    // MARK: Task CRUD

    func createTask(
        name: String,
        iconName: String,
        targetTime: TimeInterval?,
        displayOrder: Int?,
        scheduledDayKey: String,
        lineageID: UUID?
    ) -> Task {
        let order = displayOrder ?? ((tasks.map(\.displayOrder).max() ?? -1) + 1)
        let safeTarget = sanitizedTarget(targetTime)
        let safeDayKey = LocalDay(key: scheduledDayKey)?.key ?? LocalDay.today.key
        let task = Task(
            name: name,
            iconName: iconName,
            displayOrder: order,
            targetTime: safeTarget,
            scheduledDayKey: safeDayKey,
            lineageID: lineageID
        )
        modelContext.insert(task)
        saveChanges()
        return task
    }

    func delete(task: Task) {
        modelContext.delete(task)
        saveChanges()
    }

    func complete(task: Task) {
        if task.isRunning {
            task.accumulatedElapsed = task.currentElapsed()
            task.isRunning = false
            task.startedAt = nil
        }
        task.isCompleted = true
        saveChanges()
    }

    func uncomplete(task: Task) {
        task.isCompleted = false
        saveChanges()
    }

    func update(task: Task, name: String, targetTime: TimeInterval?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task.name = trimmed
        task.targetTime = sanitizedTarget(targetTime)
        saveChanges()
    }

    func reorderTasks(_ orderedTasks: [Task]) {
        for (index, task) in orderedTasks.enumerated() {
            task.displayOrder = index
        }
        saveChanges()
    }

    /// Stops stale running work at its local midnight and preserves exact elapsed time.
    func reconcileDayBoundary(at date: Date) {
        let today = LocalDay(date: date)
        var changed = false
        for task in tasks where task.isRunning {
            let scheduledDay = task.scheduledDayKey.flatMap(LocalDay.init(key:)) ?? today
            guard scheduledDay != today else { continue }

            if scheduledDay < today {
                let cutoff = min(date, scheduledDay.nextStartDate())
                task.accumulatedElapsed = task.currentElapsed(at: cutoff)
            }
            task.isRunning = false
            task.startedAt = nil
            changed = true
        }
        guard changed else { return }
        saveChanges()
    }

    func clearAllData() {
        let taskDescriptor = FetchDescriptor<Task>()
        if let allTasks = try? modelContext.fetch(taskDescriptor) {
            for task in allTasks {
                modelContext.delete(task)
            }
        }
        let dayDescriptor = FetchDescriptor<Day>()
        if let allDays = try? modelContext.fetch(dayDescriptor) {
            for day in allDays {
                modelContext.delete(day)
            }
        }
        saveChanges()
    }

    func refreshTasks() {
        let descriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\.displayOrder)])
        do {
            let results = try modelContext.fetch(descriptor)
            tasks = results
        } catch {
            errorMessage = "FocusStation couldn’t load your saved tasks."
        }
    }

    func clearError() {
        errorMessage = nil
    }

    /// Pauses every active task in one persistence transaction, used before sleep.
    func pauseAllRunningTasks() {
        var changed = false
        for task in tasks where task.isRunning {
            task.accumulatedElapsed = task.currentElapsed()
            task.isRunning = false
            task.startedAt = nil
            changed = true
        }
        guard changed else { return }
        saveChanges()
    }

    private func migrateLegacyTasksIfNeeded() {
        let today = LocalDay.today
        var changed = false
        for task in tasks where task.scheduledDayKey == nil {
            let destination: LocalDay
            if
                task.isRunning,
                let startedAt = task.startedAt,
                LocalDay(date: startedAt) < today
            {
                destination = LocalDay(date: startedAt)
            } else if task.isCompleted {
                destination = LocalDay(date: task.createdAt)
            } else {
                destination = today
            }
            task.scheduledDayKey = destination.key
            changed = true
        }
        guard changed else { return }
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            modelContext.rollback()
            errorMessage = "FocusStation couldn’t save that change. Your previously saved data is unchanged."
        }
        refreshTasks()
    }

    private func sanitizedTarget(_ targetTime: TimeInterval?) -> TimeInterval? {
        guard let targetTime, targetTime.isFinite, targetTime > 0 else { return nil }
        return targetTime
    }
}
