import Foundation

/// API for all timer state mutation and task persistence.
/// ViewModels depend on this protocol, never on the concrete TimerManager.
protocol TimerManagerProtocol: AnyObject {
    var tasks: [Task] { get }
    var errorMessage: String? { get }

    func start(task: Task)
    func pause(task: Task)
    func resume(task: Task)
    func createTask(
        name: String,
        iconName: String,
        targetTime: TimeInterval?,
        displayOrder: Int?,
        scheduledDayKey: String,
        lineageID: UUID?
    ) -> Task
    func delete(task: Task)
    func complete(task: Task)
    func uncomplete(task: Task)
    func update(task: Task, name: String, targetTime: TimeInterval?)
    func reorderTasks(_ tasks: [Task])
    func reconcileDayBoundary(at date: Date)
    func clearAllData()
    func clearError()
}
