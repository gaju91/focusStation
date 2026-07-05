import Foundation
import SwiftData

/// A single task tracked by FocusStation.
/// Accumulated elapsed time is computed from timestamps — never from a counter.
@Model
final class Task: Identifiable {
    var id: UUID
    var name: String
    var iconName: String
    var accumulatedElapsed: TimeInterval
    var isRunning: Bool
    var isCompleted: Bool
    var displayOrder: Int
    var startedAt: Date?
    var targetTime: TimeInterval?
    var createdAt: Date

    init(
        name: String,
        iconName: String = IconProvider.defaultIcon,
        accumulatedElapsed: TimeInterval = 0,
        isRunning: Bool = false,
        isCompleted: Bool = false,
        displayOrder: Int = 0,
        startedAt: Date? = nil,
        targetTime: TimeInterval? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.accumulatedElapsed = accumulatedElapsed
        self.isRunning = isRunning
        self.isCompleted = isCompleted
        self.displayOrder = displayOrder
        self.startedAt = startedAt
        self.targetTime = targetTime
        self.createdAt = createdAt
    }

    /// Live elapsed time — accumulated + current session if running.
    func currentElapsed() -> TimeInterval {
        guard isRunning, let startedAt else {
            return accumulatedElapsed
        }
        return accumulatedElapsed + Date.now.timeIntervalSince(startedAt)
    }

    /// Derived display state from running/completed/accumulated flags.
    var displayState: DisplayState {
        if isCompleted { return .completed }
        if isRunning { return .running }
        if accumulatedElapsed > 0 { return .paused }
        return .idle
    }

    enum DisplayState {
        case idle
        case running
        case paused
        case completed
    }
}
