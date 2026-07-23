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
    var scheduledDayKey: String?
    var lineageID: UUID?

    init(
        name: String,
        iconName: String = IconProvider.defaultIcon,
        accumulatedElapsed: TimeInterval = 0,
        isRunning: Bool = false,
        isCompleted: Bool = false,
        displayOrder: Int = 0,
        startedAt: Date? = nil,
        targetTime: TimeInterval? = nil,
        createdAt: Date = .now,
        scheduledDayKey: String? = nil,
        lineageID: UUID? = nil
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
        self.scheduledDayKey = scheduledDayKey
        self.lineageID = lineageID
    }

    /// Live elapsed time — accumulated + current session if running.
    func currentElapsed(at date: Date = .now) -> TimeInterval {
        let safeAccumulated = accumulatedElapsed.isFinite
            ? max(0, accumulatedElapsed)
            : 0
        guard isRunning, let startedAt else {
            return safeAccumulated
        }
        let sessionElapsed = date.timeIntervalSince(startedAt)
        guard sessionElapsed.isFinite else { return safeAccumulated }
        return safeAccumulated + max(0, sessionElapsed)
    }

    /// Whether the task was created before the current local calendar day.
    func wasCreatedBeforeToday(
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.startOfDay(for: createdAt) < calendar.startOfDay(for: date)
    }

    /// Whether this task belongs to a daily workspace, with legacy tasks treated as Today.
    func isScheduled(
        on day: LocalDay,
        today: LocalDay = .today
    ) -> Bool {
        (scheduledDayKey ?? today.key) == day.key
    }

    /// Stable identifier shared by copies of the same work across daily workspaces.
    var effectiveLineageID: UUID {
        lineageID ?? id
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
