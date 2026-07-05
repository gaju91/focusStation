import Foundation
import SwiftData

/// Historical record of a single task's tracking session within a Day.
@Model
final class Day: Identifiable {
    var id: UUID
    var date: Date

    @Relationship(deleteRule: .cascade)
    var archivedTasks: [ArchivedTask]

    var goalHours: Double?
    var totalElapsed: TimeInterval
    var completedAll: Bool
    var createdAt: Date

    init(
        date: Date,
        archivedTasks: [ArchivedTask] = [],
        goalHours: Double? = nil,
        totalElapsed: TimeInterval = 0,
        completedAll: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.date = date
        self.archivedTasks = archivedTasks
        self.goalHours = goalHours
        self.totalElapsed = totalElapsed
        self.completedAll = completedAll
        self.createdAt = createdAt
    }
}

/// Frozen snapshot of a task's state at archival time.
@Model
final class ArchivedTask: Identifiable {
    var id: UUID
    var name: String
    var iconName: String
    var elapsed: TimeInterval
    var isCompleted: Bool
    var createdAt: Date

    init(
        name: String,
        iconName: String,
        elapsed: TimeInterval,
        isCompleted: Bool,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.elapsed = elapsed
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
