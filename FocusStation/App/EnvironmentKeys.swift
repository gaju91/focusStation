import SwiftUI
import SwiftData

extension EnvironmentValues {
    @Entry var timerManager: any TimerManagerProtocol = NoOpTimerManager()
}

private final class NoOpTimerManager: TimerManagerProtocol {
    var tasks: [Task] { [] }
    func start(task: Task) {}
    func pause(task: Task) {}
    func resume(task: Task) {}
    func createTask(name: String, iconName: String, targetTime: TimeInterval?, displayOrder: Int?) -> Task {
        Task(name: name)
    }
    func delete(task: Task) {}
    func complete(task: Task) {}
    func uncomplete(task: Task) {}
    func updateName(of task: Task, to newName: String) {}
    func updateIcon(of task: Task, to iconName: String) {}
    func updateTargetTime(of task: Task, to targetTime: TimeInterval?) {}
    func move(task: Task, to index: Int) {}
    func swapTasks(_ a: Task, with b: Task) {}
    func clearAllData() {}
}
