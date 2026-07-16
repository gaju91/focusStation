import Foundation
import Observation

@Observable
final class DropdownViewModel {
    var tasks: [Task] = []

    var isEmpty: Bool { tasks.isEmpty }

    var sortedTasks: [Task] {
        tasks.sorted { $0.displayOrder < $1.displayOrder }
    }

    private let timerManager: any TimerManagerProtocol
    private var syncTimer: Timer?

    init(timerManager: any TimerManagerProtocol) {
        self.timerManager = timerManager
        refreshTasks()
        startSyncTimer()
    }

    deinit {
        syncTimer?.invalidate()
    }

    func refreshTasks() {
        tasks = timerManager.tasks
    }

    private func startSyncTimer() {
        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(syncTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    @objc private func syncTick() {
        refreshTasks()
    }

    // MARK: Timer Actions

    func startTask(_ task: Task) {
        timerManager.start(task: task)
        refreshTasks()
    }

    func pauseTask(_ task: Task) {
        guard task.isRunning else { return }
        timerManager.pause(task: task)
        refreshTasks()
    }

    func resumeTask(_ task: Task) {
        guard !task.isRunning else { return }
        timerManager.resume(task: task)
        refreshTasks()
    }

    // MARK: CRUD

    func createTask(name: String, iconName: String, targetTime: TimeInterval?) {
        let order = Int(Date.now.timeIntervalSince1970)
        _ = timerManager.createTask(name: name, iconName: iconName, targetTime: targetTime, displayOrder: order)
        refreshTasks()
    }

    func deleteTask(_ task: Task) {
        timerManager.delete(task: task)
        refreshTasks()
    }

    func completeTask(_ task: Task) {
        timerManager.complete(task: task)
        refreshTasks()
    }

    func uncompleteTask(_ task: Task) {
        timerManager.uncomplete(task: task)
        refreshTasks()
    }

    func reorderTasks(from source: IndexSet, to destination: Int) {
        var sorted = sortedTasks
        sorted.move(fromOffsets: source, toOffset: destination)
        timerManager.reorderTasks(sorted)
        refreshTasks()
    }

    func reorderTask(from sourceIndex: Int, to destinationIndex: Int) {
        var sorted = sortedTasks
        let task = sorted.remove(at: sourceIndex)
        sorted.insert(task, at: destinationIndex)
        timerManager.reorderTasks(sorted)
        refreshTasks()
    }

    func updateTaskName(_ task: Task, to newName: String) {
        timerManager.updateName(of: task, to: newName)
        refreshTasks()
    }

    func updateTaskIcon(_ task: Task, to iconName: String) {
        timerManager.updateIcon(of: task, to: iconName)
        refreshTasks()
    }

    func updateTaskTarget(_ task: Task, to targetTime: TimeInterval?) {
        timerManager.updateTargetTime(of: task, to: targetTime)
        refreshTasks()
    }

    // MARK: Private

    func suspendSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    func resumeSync() {
        guard syncTimer == nil else { return }
        startSyncTimer()
    }
}
