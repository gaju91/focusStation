import Foundation

/// API for all timer state mutation and task persistence.
/// ViewModels depend on this protocol, never on the concrete TimerManager.
protocol TimerManagerProtocol: AnyObject {
    var tasks: [Task] { get }

    func start(task: Task)
    func pause(task: Task)
    func resume(task: Task)
    func createTask(name: String, iconName: String, targetTime: TimeInterval?, displayOrder: Int?) -> Task
    func delete(task: Task)
    func complete(task: Task)
    func uncomplete(task: Task)
    func updateName(of task: Task, to newName: String)
    func updateIcon(of task: Task, to iconName: String)
    func updateTargetTime(of task: Task, to targetTime: TimeInterval?)
    func move(task: Task, to index: Int)
    func swapTasks(_ a: Task, with b: Task)
    func clearAllData()
}
