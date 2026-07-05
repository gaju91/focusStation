import Foundation
import Observation
import SwiftData

@Observable
final class TimerManager: TimerManagerProtocol {
    var tasks: [Task] = []

    let modelContext: ModelContext
    private var displayTimer: Timer?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        observeSleepWake()
        refreshTasks()
    }

    deinit {
        displayTimer?.invalidate()
    }

    func startDisplayTimer() {
        guard displayTimer == nil else { return }
        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
        displayTimer?.fire()
    }

    func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    /// Display timer heartbeat. No work needed — @Observable
    /// accesses are driven externally via TickGenerator + TimelineView.
    @objc private func timerDidFire() {}

    // MARK: Timer Actions

    func start(task: Task) {
        guard !task.isRunning else { return }
        pauseOtherRunningTasks(except: task)
        task.isRunning = true
        task.startedAt = .now
        try? modelContext.save()
        refreshTasks()
    }

    func pause(task: Task) {
        guard task.isRunning else { return }
        task.accumulatedElapsed = task.currentElapsed()
        task.isRunning = false
        task.startedAt = nil
        try? modelContext.save()
        refreshTasks()
    }

    func resume(task: Task) {
        guard !task.isRunning else { return }
        pauseOtherRunningTasks(except: task)
        task.isRunning = true
        task.startedAt = .now
        try? modelContext.save()
        refreshTasks()
    }

    private func pauseOtherRunningTasks(except target: Task) {
        for t in tasks where t.isRunning && t.id != target.id {
            t.accumulatedElapsed = t.currentElapsed()
            t.isRunning = false
            t.startedAt = nil
        }
    }

    // MARK: Task CRUD

    func createTask(name: String, iconName: String, targetTime: TimeInterval?, displayOrder: Int?) -> Task {
        let order = displayOrder ?? -(Int(Date.now.timeIntervalSince1970))
        let task = Task(name: name, iconName: iconName, displayOrder: order, targetTime: targetTime)
        modelContext.insert(task)
        try? modelContext.save()
        refreshTasks()
        return task
    }

    func delete(task: Task) {
        if task.isRunning {
            pause(task: task)
        }
        modelContext.delete(task)
        try? modelContext.save()
        refreshTasks()
    }

    func complete(task: Task) {
        if task.isRunning {
            pause(task: task)
        }
        task.isCompleted = true
        try? modelContext.save()
        refreshTasks()
    }

    func uncomplete(task: Task) {
        task.isCompleted = false
        try? modelContext.save()
        refreshTasks()
    }

    func updateName(of task: Task, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        task.name = trimmed
        try? modelContext.save()
        refreshTasks()
    }

    func updateIcon(of task: Task, to iconName: String) {
        task.iconName = iconName
        try? modelContext.save()
        refreshTasks()
    }

    func updateTargetTime(of task: Task, to targetTime: TimeInterval?) {
        task.targetTime = targetTime
        try? modelContext.save()
        refreshTasks()
    }

    func move(task: Task, to index: Int) {
        guard !task.isCompleted else { return }
        var mutableTasks = tasks.filter { !$0.isCompleted }
        mutableTasks.removeAll(where: { $0.id == task.id })
        let clamped = max(0, min(index, mutableTasks.count))
        mutableTasks.insert(task, at: clamped)
        for (i, t) in mutableTasks.enumerated() {
            t.displayOrder = i
        }
        try? modelContext.save()
        refreshTasks()
    }

    func swapTasks(_ a: Task, with b: Task) {
        let tmp = a.displayOrder
        a.displayOrder = b.displayOrder
        b.displayOrder = tmp
        try? modelContext.save()
        refreshTasks()
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
        try? modelContext.save()
        refreshTasks()
    }

    func refreshTasks() {
        startDisplayTimer()
        let descriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\.displayOrder)])
        if let results = try? modelContext.fetch(descriptor) {
            tasks = results
        }
    }
}
