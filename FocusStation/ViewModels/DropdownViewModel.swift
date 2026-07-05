import Foundation
import Observation

@Observable
final class DropdownViewModel {
    var tasks: [Task] = []
    var taskToEdit: Task?

    var isEmpty: Bool { tasks.isEmpty }

    var sortedTasks: [Task] {
        tasks.sorted { lhs, rhs in
            if lhs.displayState != rhs.displayState {
                return displayStateOrder(lhs.displayState) < displayStateOrder(rhs.displayState)
            }
            return lhs.displayOrder < rhs.displayOrder
        }
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
        let order = -(Int(Date.now.timeIntervalSince1970))
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

    func moveTaskUp(_ task: Task) {
        swapAdjacent(task, offset: -1)
    }

    func moveTaskDown(_ task: Task) {
        swapAdjacent(task, offset: 1)
    }

    func moveTask(_ task: Task, to index: Int) {
        timerManager.move(task: task, to: index)
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

    private func swapAdjacent(_ task: Task, offset: Int) {
        let sorted = sortedTasks
        guard let idx = sorted.firstIndex(where: { $0.id == task.id }) else { return }
        let targetIdx = idx + offset
        guard targetIdx >= 0, targetIdx < sorted.count else { return }
        timerManager.swapTasks(task, with: sorted[targetIdx])
        refreshTasks()
    }

    private func displayStateOrder(_ state: Task.DisplayState) -> Int {
        switch state {
        case .running:   return 0
        case .paused:    return 1
        case .idle:      return 2
        case .completed: return 3
        }
    }
}
