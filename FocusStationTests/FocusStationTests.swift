import Foundation
import SwiftData
import SwiftUI
import XCTest
import AppKit
@testable import FocusStation

/// Verifies timestamp-based elapsed-time and local calendar-day behavior.
final class TaskModelTests: XCTestCase {
    func testCurrentElapsedUsesTimestampDifference() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let task = Task(
            name: "Running",
            accumulatedElapsed: 30,
            isRunning: true,
            startedAt: startedAt
        )

        XCTAssertEqual(
            task.currentElapsed(at: Date(timeIntervalSince1970: 1_045)),
            75,
            accuracy: 0.001
        )
    }

    func testCurrentElapsedClampsFutureClockChanges() {
        let task = Task(
            name: "Future clock",
            accumulatedElapsed: 30,
            isRunning: true,
            startedAt: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(
            task.currentElapsed(at: Date(timeIntervalSince1970: 1_000)),
            30,
            accuracy: 0.001
        )
    }

    func testEarlierDayUsesCalendarBoundariesAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(identifier: "America/Los_Angeles") else {
            throw XCTSkip("Time zone unavailable")
        }
        calendar.timeZone = timeZone

        let creation = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 7,
            hour: 23,
            minute: 59
        )))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 8,
            hour: 0,
            minute: 1
        )))
        let task = Task(name: "DST", createdAt: creation)

        XCTAssertTrue(task.wasCreatedBeforeToday(on: nextDay, calendar: calendar))
    }

    func testCreationTodayAndFutureDatesAreNotCarriedTasks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 19_800) ?? .current
        let today = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 19,
            hour: 12
        )))
        let sameDay = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 19,
            hour: 1
        )))
        let future = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 20,
            hour: 1
        )))

        XCTAssertFalse(Task(name: "Today", createdAt: sameDay).wasCreatedBeforeToday(
            on: today,
            calendar: calendar
        ))
        XCTAssertFalse(Task(name: "Future", createdAt: future).wasCreatedBeforeToday(
            on: today,
            calendar: calendar
        ))
    }
}

/// Verifies normalized editor input and single-session state ownership.
final class DropdownViewModelTests: XCTestCase {
    func testTargetTimeNormalizesMinutesAndZero() {
        XCTAssertNil(TaskEditorState(hours: 0, minutes: 0).targetTime)
        XCTAssertEqual(
            TaskEditorState(hours: 1, minutes: 90).targetTime,
            7_140
        )
        XCTAssertNil(TaskEditorState(hours: -1, minutes: -1).targetTime)
    }

    func testCreateUsesNextStableOrderAndClosesEditor() {
        let existing = Task(name: "Existing", displayOrder: 4)
        let manager = TimerManagerSpy(tasks: [existing])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.beginCreating()
        viewModel.editor?.name = "  New task  "

        XCTAssertTrue(viewModel.saveEditor())
        XCTAssertNil(viewModel.editor)
        XCTAssertEqual(manager.tasks.last?.name, "New task")
        XCTAssertEqual(manager.tasks.last?.displayOrder, 5)
    }

    func testEditUsesOneAtomicUpdateAndClosesEditor() {
        let task = Task(name: "Before", displayOrder: 0, targetTime: 600)
        let manager = TimerManagerSpy(tasks: [task])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.beginEditing(task)
        viewModel.editor?.name = "After"
        viewModel.editor?.hours = 1
        viewModel.editor?.minutes = 15

        XCTAssertTrue(viewModel.saveEditor())
        XCTAssertEqual(manager.updateCallCount, 1)
        XCTAssertEqual(task.name, "After")
        XCTAssertEqual(task.targetTime, 4_500)
        XCTAssertNil(viewModel.editor)
    }

    func testSecondEditorCannotReplaceUnsavedEditor() {
        let first = Task(name: "First")
        let second = Task(name: "Second")
        let manager = TimerManagerSpy(tasks: [first, second])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.beginEditing(first)
        let originalEditorID = viewModel.editor?.id
        viewModel.beginEditing(second)

        XCTAssertEqual(viewModel.editor?.id, originalEditorID)
        XCTAssertTrue(viewModel.isEditing(first))
        XCTAssertFalse(viewModel.isEditing(second))
    }

    func testMissingEditedTaskCancelsSafely() {
        let task = Task(name: "Removed")
        let manager = TimerManagerSpy(tasks: [task])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.beginEditing(task)
        viewModel.editor?.name = "Changed"
        manager.tasks = []
        viewModel.refreshTasks()

        XCTAssertFalse(viewModel.saveEditor())
        XCTAssertNil(viewModel.editor)
    }

    func testStaleFieldCommitCannotRestoreSavedCreateEditor() throws {
        let manager = TimerManagerSpy(tasks: [])
        let viewModel = DropdownViewModel(timerManager: manager)
        viewModel.beginCreating()

        var fieldSnapshot = try XCTUnwrap(viewModel.editor)
        fieldSnapshot.name = "Created once"
        viewModel.updateEditor(fieldSnapshot)

        XCTAssertTrue(viewModel.saveEditor())
        viewModel.updateEditor(fieldSnapshot)

        XCTAssertNil(viewModel.editor)
        XCTAssertEqual(manager.tasks.map(\.name), ["Created once"])
    }

    func testStaleFieldCommitCannotRestoreSavedEditEditor() throws {
        let task = Task(name: "Before")
        let manager = TimerManagerSpy(tasks: [task])
        let viewModel = DropdownViewModel(timerManager: manager)
        viewModel.beginEditing(task)

        var fieldSnapshot = try XCTUnwrap(viewModel.editor)
        fieldSnapshot.name = "After"
        viewModel.updateEditor(fieldSnapshot)

        XCTAssertTrue(viewModel.saveEditor())
        viewModel.updateEditor(fieldSnapshot)

        XCTAssertNil(viewModel.editor)
        XCTAssertEqual(task.name, "After")
        XCTAssertEqual(manager.updateCallCount, 1)
    }

    func testReorderMovesAcrossAdjacentRowsInBothDirections() {
        let first = Task(name: "First", displayOrder: 0)
        let second = Task(name: "Second", displayOrder: 1)
        let third = Task(name: "Third", displayOrder: 2)
        let manager = TimerManagerSpy(tasks: [first, second, third])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.moveTask(first.id, toward: second.id)
        XCTAssertEqual(viewModel.sortedTasks.map(\.name), ["Second", "First", "Third"])

        viewModel.moveTask(third.id, toward: first.id)
        XCTAssertEqual(viewModel.sortedTasks.map(\.name), ["Second", "Third", "First"])
    }

    func testActiveAndCompletedTasksRemainOrderedWithinTheirGroups() {
        let activeLater = Task(name: "Active later", displayOrder: 3)
        let completedFirst = Task(
            name: "Completed first",
            isCompleted: true,
            displayOrder: 0
        )
        let activeFirst = Task(name: "Active first", displayOrder: 1)
        let completedLater = Task(
            name: "Completed later",
            isCompleted: true,
            displayOrder: 2
        )
        let manager = TimerManagerSpy(tasks: [
            activeLater,
            completedFirst,
            activeFirst,
            completedLater
        ])
        let viewModel = DropdownViewModel(timerManager: manager)

        XCTAssertEqual(viewModel.activeTasks.map(\.name), ["Active first", "Active later"])
        XCTAssertEqual(
            viewModel.completedTasks.map(\.name),
            ["Completed first", "Completed later"]
        )
    }

    func testReorderWorksAcrossCompletionStates() {
        let active = Task(name: "Active", displayOrder: 0)
        let completed = Task(name: "Completed", isCompleted: true, displayOrder: 1)
        let manager = TimerManagerSpy(tasks: [active, completed])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.moveTask(active.id, toward: completed.id)

        XCTAssertEqual(viewModel.sortedTasks.map(\.name), ["Completed", "Active"])
    }

    func testSelectedDayFiltersTasksWithoutChangingTheirPersistedOrder() {
        let today = LocalDay.today
        let tomorrow = today.addingDays(1)
        let todayLater = Task(
            name: "Today later",
            displayOrder: 3,
            scheduledDayKey: today.key
        )
        let tomorrowTask = Task(
            name: "Tomorrow",
            displayOrder: 0,
            scheduledDayKey: tomorrow.key
        )
        let todayFirst = Task(
            name: "Today first",
            displayOrder: 1,
            scheduledDayKey: today.key
        )
        let viewModel = DropdownViewModel(
            timerManager: TimerManagerSpy(tasks: [todayLater, tomorrowTask, todayFirst])
        )

        XCTAssertEqual(viewModel.sortedTasks.map(\.name), ["Today first", "Today later"])
        viewModel.showNextDay()
        XCTAssertEqual(viewModel.sortedTasks.map(\.name), ["Tomorrow"])
    }

    func testFutureTaskCanBeEditedButCannotRunOrComplete() {
        let tomorrow = LocalDay.today.addingDays(1)
        let task = Task(name: "Plan", scheduledDayKey: tomorrow.key)
        let manager = TimerManagerSpy(tasks: [task])
        let viewModel = DropdownViewModel(timerManager: manager, selectedDay: tomorrow)

        XCTAssertTrue(viewModel.canBeginEditing)
        viewModel.startTask(task)
        viewModel.completeTask(task)

        XCTAssertFalse(task.isRunning)
        XCTAssertFalse(task.isCompleted)
    }

    func testPastTaskIsReadOnly() {
        let yesterday = LocalDay.today.addingDays(-1)
        let task = Task(name: "Past", scheduledDayKey: yesterday.key)
        let manager = TimerManagerSpy(tasks: [task])
        let viewModel = DropdownViewModel(timerManager: manager, selectedDay: yesterday)

        viewModel.beginEditing(task)
        viewModel.deleteTask(task)

        XCTAssertNil(viewModel.editor)
        XCTAssertEqual(manager.tasks.map(\.name), ["Past"])
    }

    func testCarryUsesRemainingTargetAndPreservesLineage() throws {
        let today = LocalDay.today
        let task = Task(
            name: "Carry me",
            accumulatedElapsed: 900,
            targetTime: 3_600,
            scheduledDayKey: today.key
        )
        let manager = TimerManagerSpy(tasks: [task])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.carryTask(task)

        let copy = try XCTUnwrap(manager.tasks.last)
        XCTAssertEqual(copy.scheduledDayKey, today.addingDays(1).key)
        XCTAssertEqual(copy.targetTime, 2_700)
        XCTAssertEqual(copy.accumulatedElapsed, 0)
        XCTAssertEqual(copy.effectiveLineageID, task.id)
        XCTAssertEqual(viewModel.selectedDay, today.addingDays(1))
    }

    func testRepeatUsesFullTargetAndDuplicateCopyIsPrevented() throws {
        let task = Task(
            name: "Repeat me",
            accumulatedElapsed: 900,
            targetTime: 3_600,
            scheduledDayKey: LocalDay.today.key
        )
        let manager = TimerManagerSpy(tasks: [task])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.repeatTask(task)
        let copy = try XCTUnwrap(manager.tasks.last)
        XCTAssertEqual(copy.targetTime, 3_600)

        viewModel.showPreviousDay()
        viewModel.repeatTask(task)
        XCTAssertEqual(manager.tasks.count, 2)
    }

    func testFutureDayCapacitySubtractsOtherPlannedWorkButNotEditedTask() {
        let tomorrow = LocalDay.today.addingDays(1)
        let first = Task(
            name: "First",
            targetTime: 3_600,
            scheduledDayKey: tomorrow.key
        )
        let second = Task(
            name: "Second",
            targetTime: 7_200,
            scheduledDayKey: tomorrow.key
        )
        let viewModel = DropdownViewModel(
            timerManager: TimerManagerSpy(tasks: [first, second]),
            selectedDay: tomorrow
        )

        let fullDay = tomorrow.availableDuration()
        XCTAssertEqual(viewModel.maximumTargetTime, fullDay - 10_800, accuracy: 0.001)

        viewModel.beginEditing(first)
        XCTAssertEqual(viewModel.maximumTargetTime, fullDay - 7_200, accuracy: 0.001)
    }
}

/// Verifies local-day duration rules and history serialization.
final class DailyWorkspaceTests: XCTestCase {
    func testLocalDayRejectsNormalizedInvalidDates() {
        XCTAssertNil(LocalDay(key: "2026-02-31"))
        XCTAssertNil(LocalDay(key: "2026-13-01"))
    }

    func testFullDayDurationRespectsDaylightSavingBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 1,
            hour: 12
        )))

        XCTAssertEqual(
            LocalDay(key: "2026-03-08")?.availableDuration(at: reference, calendar: calendar),
            23 * 3_600
        )
        XCTAssertEqual(
            LocalDay(key: "2026-11-01")?.availableDuration(at: reference, calendar: calendar),
            25 * 3_600
        )
    }

    func testCSVExportEscapesNamesAndSortsByDayThenOrder() throws {
        let later = Task(
            name: "Review, \"ship\"",
            accumulatedElapsed: 90,
            displayOrder: 1,
            targetTime: 60,
            scheduledDayKey: "2026-07-20"
        )
        let earlier = Task(
            name: "Plan",
            accumulatedElapsed: 30,
            isCompleted: true,
            displayOrder: 0,
            scheduledDayKey: "2026-07-19"
        )

        let document = try XCTUnwrap(HistoryCSVExporter.makeDocument(
            tasks: [later, earlier],
            scope: .allHistory
        ))

        XCTAssertEqual(
            document.suggestedFilename,
            "FocusStation-History-2026-07-19-to-2026-07-20.csv"
        )
        let rows = document.contents.components(separatedBy: "\r\n")
        XCTAssertTrue(rows[1].hasPrefix("2026-07-19,Plan,Completed"))
        XCTAssertTrue(rows[2].contains("\"Review, \"\"ship\"\"\""))
        XCTAssertTrue(rows[2].hasSuffix(",30"))
    }

    func testFormatterKeepsExactLongDayDuration() {
        XCTAssertEqual(TimeFormatter.format(24 * 3_600), "24h")
        XCTAssertEqual(TimeFormatter.format(25 * 3_600), "25h")
    }
}

/// Verifies the persisted timer engine closes stale work exactly at local midnight.
@MainActor
final class TimerManagerDayBoundaryTests: XCTestCase {
    func testRunningTaskIsCappedAtScheduledDayMidnight() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Task.self,
            Day.self,
            ArchivedTask.self,
            configurations: configuration
        )
        let manager = TimerManager(modelContext: container.mainContext)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let yesterday = LocalDay.today.addingDays(-1, calendar: calendar)
        let start = yesterday.nextStartDate(calendar: calendar).addingTimeInterval(-900)
        let task = Task(
            name: "Late task",
            isRunning: true,
            startedAt: start,
            scheduledDayKey: yesterday.key
        )
        container.mainContext.insert(task)
        try container.mainContext.save()
        manager.refreshTasks()

        manager.reconcileDayBoundary(at: yesterday.nextStartDate(calendar: calendar).addingTimeInterval(600))

        XCTAssertFalse(task.isRunning)
        XCTAssertNil(task.startedAt)
        XCTAssertEqual(task.accumulatedElapsed, 900, accuracy: 0.001)
    }
}

/// Verifies deterministic content-driven popover sizing without view measurement.
final class PopoverLayoutTests: XCTestCase {
    func testEmptyAndSingleTaskLayoutsUseCompactMinimumHeight() {
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: 0,
                completedCount: 0,
                isCreating: false,
                isEditing: false
            ),
            190
        )
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: 1,
                completedCount: 0,
                isCreating: false,
                isEditing: false
            ),
            PopoverLayout.minimumHeight
        )
    }

    func testFiveTasksFitWithoutReachingMaximumHeight() {
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: 5,
                completedCount: 0,
                isCreating: false,
                isEditing: false
            ),
            410
        )
    }

    func testLargeTaskListClampsToMaximumHeight() {
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: 20,
                completedCount: 0,
                isCreating: false,
                isEditing: false
            ),
            PopoverLayout.maximumHeight
        )
    }

    func testCompletedTasksRemainInlineAtNormalRowHeight() {
        let collapsedHeight = PopoverLayout.preferredHeight(
            activeCount: 0,
            completedCount: 3,
            isCreating: false,
            isEditing: false
        )
        let expandedHeight = PopoverLayout.preferredHeight(
            activeCount: 0,
            completedCount: 3,
            isCreating: false,
            isEditing: false
        )

        XCTAssertEqual(collapsedHeight, 282)
        XCTAssertEqual(expandedHeight, 282)
    }

    func testEditorHeightIsIncludedWithoutExceedingMaximum() {
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: 5,
                completedCount: 0,
                isCreating: false,
                isEditing: true
            ),
            422
        )
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: 20,
                completedCount: 0,
                isCreating: true,
                isEditing: false
            ),
            PopoverLayout.maximumHeight
        )
    }
}

/// Verifies menu-bar task priority and elapsed/target content.
final class StatusBarContentTests: XCTestCase {
    func testRunningTaskTakesPriorityOverEarlierPausedTask() {
        let paused = Task(name: "Paused", accumulatedElapsed: 60)
        let running = Task(
            name: "Running",
            accumulatedElapsed: 120,
            isRunning: true,
            startedAt: .now
        )

        XCTAssertEqual(
            StatusBarContent.displayedTask(in: [paused, running])?.id,
            running.id
        )
    }

    func testPausedTaskIsShownWhenNothingIsRunning() {
        let idle = Task(name: "Idle")
        let paused = Task(name: "Paused", accumulatedElapsed: 60)

        XCTAssertEqual(
            StatusBarContent.displayedTask(in: [idle, paused])?.id,
            paused.id
        )
    }

    func testTimeTextIncludesOptionalTarget() {
        let targeted = Task(
            name: "Targeted",
            accumulatedElapsed: 300,
            targetTime: 1_800
        )
        let untargeted = Task(name: "Untargeted", accumulatedElapsed: 300)

        XCTAssertEqual(StatusBarContent.timeText(for: targeted), "5m / 30m")
        XCTAssertEqual(StatusBarContent.timeText(for: untargeted), "5m")
    }

    func testElapsedToneReflectsRunningPausedAndOverdueStates() {
        let running = Task(name: "Running", isRunning: true, startedAt: .now)
        let paused = Task(name: "Paused", accumulatedElapsed: 60)
        let overdue = Task(
            name: "Overdue",
            accumulatedElapsed: 601,
            targetTime: 600
        )
        let pausedOverdue = Task(
            name: "Paused overdue",
            accumulatedElapsed: 601,
            targetTime: 600
        )

        XCTAssertEqual(StatusBarContent.elapsedTone(for: running), .withinLimit)
        XCTAssertEqual(StatusBarContent.elapsedTone(for: paused), .paused)
        XCTAssertEqual(StatusBarContent.elapsedTone(for: overdue), .overdue)
        XCTAssertEqual(
            StatusBarContent.elapsedTone(for: pausedOverdue),
            .overdue
        )
    }
}

/// Deterministic hostile records reused across the adversarial test campaign.
private enum AdversarialSeedData {
    static let extremeNames = [
        "",
        "   \n\t  ",
        String(repeating: "🧠", count: 2_000),
        "Review, \"ship\"\nthen deploy",
        "=HYPERLINK(\"https://example.invalid\")",
        "+1+1",
        "-2+3",
        "@SUM(A1:A2)",
        "مرحبا بالعالم",
        "e\u{301} versus é"
    ]

    static func denseTasks(count: Int, day: LocalDay) -> [Task] {
        (0..<count).map { index in
            Task(
                name: "Seed \(index) · \(extremeNames[index % extremeNames.count])",
                accumulatedElapsed: TimeInterval(index * 7),
                isCompleted: index.isMultiple(of: 3),
                displayOrder: count - index,
                targetTime: index.isMultiple(of: 2) ? TimeInterval((index + 1) * 60) : nil,
                scheduledDayKey: day.key,
                lineageID: index.isMultiple(of: 5) ? UUID() : nil
            )
        }
    }
}

/// Attacks model and formatter inputs that normal UI controls should never produce.
final class AdversarialValueTests: XCTestCase {
    func testElapsedSanitizesNegativeNaNAndInfinity() {
        XCTAssertEqual(Task(name: "Negative", accumulatedElapsed: -100).currentElapsed(), 0)
        XCTAssertEqual(Task(name: "NaN", accumulatedElapsed: .nan).currentElapsed(), 0)
        XCTAssertEqual(Task(name: "Infinite", accumulatedElapsed: .infinity).currentElapsed(), 0)
    }

    func testFormatterSurvivesAllNonFiniteAndHugeValues() {
        XCTAssertEqual(TimeFormatter.format(-.infinity), "0m")
        XCTAssertEqual(TimeFormatter.format(.nan), "0m")
        XCTAssertEqual(TimeFormatter.format(.infinity), "0m")
        XCTAssertEqual(TimeFormatter.format(.greatestFiniteMagnitude), "999h+")
    }

    func testEditorIntMaxCannotOverflow() {
        let target = TaskEditorState(hours: .max, minutes: .max).targetTime
        XCTAssertEqual(target, .greatestFiniteMagnitude)
    }

    func testCompletedStateWinsOverImpossibleRunningFlags() {
        let task = Task(name: "Corrupt", isRunning: true, isCompleted: true, startedAt: .now)
        XCTAssertEqual(task.displayState, .completed)
    }

    func testLegacyNilDayOnlyAppearsOnToday() {
        let task = Task(name: "Legacy")
        XCTAssertTrue(task.isScheduled(on: .today))
        XCTAssertFalse(task.isScheduled(on: LocalDay.today.addingDays(1)))
    }
}

/// Fuzzes local-calendar arithmetic through leap years, month edges, and time zones.
final class AdversarialCalendarTests: XCTestCase {
    func testLeapDayValidationAndYearTransitions() throws {
        XCTAssertNotNil(LocalDay(key: "2028-02-29"))
        XCTAssertNil(LocalDay(key: "2027-02-29"))
        XCTAssertEqual(try XCTUnwrap(LocalDay(key: "2026-12-31")).addingDays(1).key, "2027-01-01")
        XCTAssertEqual(try XCTUnwrap(LocalDay(key: "2028-03-01")).addingDays(-1).key, "2028-02-29")
    }

    func testFourThousandAdjacentDaysRoundTripWithoutDrift() throws {
        let origin = try XCTUnwrap(LocalDay(key: "2020-01-01"))
        for offset in -2_000...2_000 {
            XCTAssertEqual(origin.addingDays(offset).addingDays(-offset), origin)
        }
    }

    func testHalfHourTimezoneStillUsesCalendarMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let day = try XCTUnwrap(LocalDay(key: "2026-07-20"))
        XCTAssertEqual(day.availableDuration(at: day.addingDays(-1).representativeDate(calendar: calendar), calendar: calendar), 86_400)
        XCTAssertEqual(calendar.component(.hour, from: day.startDate(calendar: calendar)), 0)
    }
}

/// Hammers editor sessions, copying, ordering, and capacity accounting.
final class AdversarialDropdownTests: XCTestCase {
    func testWhitespaceOnlyNameNeverCreatesTask() {
        let manager = TimerManagerSpy(tasks: [])
        let viewModel = DropdownViewModel(timerManager: manager)
        viewModel.beginCreating()
        viewModel.editor?.name = " \n\t "

        XCTAssertFalse(viewModel.saveEditor())
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertNotNil(viewModel.editor)
    }

    func testOneHundredSaveAttemptsCreateExactlyOnce() {
        let manager = TimerManagerSpy(tasks: [])
        let viewModel = DropdownViewModel(timerManager: manager)
        viewModel.beginCreating()
        viewModel.editor?.name = "Only once"

        for _ in 0..<100 {
            _ = viewModel.saveEditor()
        }

        XCTAssertEqual(manager.tasks.map(\.name), ["Only once"])
        XCTAssertNil(viewModel.editor)
    }

    func testNavigationIsFrozenDuringEditingDespiteRapidClicks() {
        let viewModel = DropdownViewModel(timerManager: TimerManagerSpy(tasks: []))
        let originalDay = viewModel.selectedDay
        viewModel.beginCreating()

        for _ in 0..<100 {
            viewModel.showPreviousDay()
            viewModel.showNextDay()
            viewModel.showToday()
        }

        XCTAssertEqual(viewModel.selectedDay, originalDay)
    }

    func testDestinationWithNoCapacityRejectsCopyWithoutNavigating() {
        let today = LocalDay.today
        let tomorrow = today.addingDays(1)
        let source = Task(name: "Source", targetTime: 60, scheduledDayKey: today.key)
        let full = Task(
            name: "Already full",
            targetTime: tomorrow.availableDuration(),
            scheduledDayKey: tomorrow.key
        )
        let manager = TimerManagerSpy(tasks: [source, full])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.carryTask(source)

        XCTAssertEqual(manager.tasks.count, 2)
        XCTAssertEqual(viewModel.selectedDay, today)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testOversizedBatchCarryIsAtomic() {
        let today = LocalDay.today
        let tomorrow = today.addingDays(1)
        let halfDay = tomorrow.availableDuration() / 2
        let tasks = [
            Task(name: "One", targetTime: halfDay + 60, scheduledDayKey: today.key),
            Task(name: "Two", targetTime: halfDay + 60, scheduledDayKey: today.key)
        ]
        let manager = TimerManagerSpy(tasks: tasks)
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.carryUnfinishedTasks()

        XCTAssertEqual(manager.tasks.count, 2)
        XCTAssertEqual(viewModel.selectedDay, today)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testRepeatedBatchCarryDoesNotDuplicateLineages() {
        let today = LocalDay.today
        let source = Task(name: "One", targetTime: 60, scheduledDayKey: today.key)
        let manager = TimerManagerSpy(tasks: [source])
        let viewModel = DropdownViewModel(timerManager: manager)

        viewModel.carryUnfinishedTasks()
        viewModel.showPreviousDay()
        viewModel.carryUnfinishedTasks()

        XCTAssertEqual(manager.tasks.count, 2)
    }

    func testDenseReorderingPreservesEveryTaskExactlyOnce() {
        let day = LocalDay.today
        let tasks = AdversarialSeedData.denseTasks(count: 100, day: day)
        let manager = TimerManagerSpy(tasks: tasks)
        let viewModel = DropdownViewModel(timerManager: manager)
        let originalIDs = Set(tasks.map(\.id))
        var state: UInt64 = 0xC0FFEE

        for _ in 0..<1_000 {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let source = Int(state % 100)
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let destination = Int(state % 100)
            let snapshot = viewModel.sortedTasks
            viewModel.moveTask(snapshot[source].id, toward: snapshot[destination].id)
        }

        XCTAssertEqual(Set(viewModel.sortedTasks.map(\.id)), originalIDs)
        XCTAssertEqual(viewModel.sortedTasks.count, 100)
    }

    func testCompletedTasksDoNotConsumeFutureCapacity() {
        let tomorrow = LocalDay.today.addingDays(1)
        let completed = Task(
            name: "Done",
            isCompleted: true,
            targetTime: tomorrow.availableDuration(),
            scheduledDayKey: tomorrow.key
        )
        let viewModel = DropdownViewModel(
            timerManager: TimerManagerSpy(tasks: [completed]),
            selectedDay: tomorrow
        )

        XCTAssertEqual(viewModel.maximumTargetTime, tomorrow.availableDuration(), accuracy: 0.001)
    }

    func testSingleTaskSummaryUsesCorrectGrammar() {
        let task = Task(name: "One", scheduledDayKey: LocalDay.today.key)
        let viewModel = DropdownViewModel(timerManager: TimerManagerSpy(tasks: [task]))
        XCTAssertTrue(viewModel.daySummary.hasPrefix("1 task ·"))
    }
}

/// Validates persistence invariants against a real in-memory SwiftData container.
@MainActor
final class AdversarialTimerManagerTests: XCTestCase {
    func testInvalidDayAndNonFiniteTargetsAreSanitized() throws {
        let (container, manager) = try makeManager()
        _ = container
        let task = manager.createTask(
            name: "Corrupt input",
            iconName: IconProvider.defaultIcon,
            targetTime: .nan,
            displayOrder: nil,
            scheduledDayKey: "2026-02-31",
            lineageID: nil
        )

        XCTAssertEqual(task.scheduledDayKey, LocalDay.today.key)
        XCTAssertNil(task.targetTime)
    }

    func testStartingSecondTaskPausesFirst() throws {
        let (container, manager) = try makeManager()
        _ = container
        let first = manager.createTask(
            name: "First",
            iconName: IconProvider.defaultIcon,
            targetTime: nil,
            displayOrder: 0,
            scheduledDayKey: LocalDay.today.key,
            lineageID: nil
        )
        let second = manager.createTask(
            name: "Second",
            iconName: IconProvider.defaultIcon,
            targetTime: nil,
            displayOrder: 1,
            scheduledDayKey: LocalDay.today.key,
            lineageID: nil
        )

        manager.start(task: first)
        manager.start(task: second)

        XCTAssertFalse(first.isRunning)
        XCTAssertNil(first.startedAt)
        XCTAssertTrue(second.isRunning)
        XCTAssertNotNil(second.startedAt)
    }

    func testLegacyRunningTaskMigratesToStartDayAndStopsAtMidnight() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Task.self,
            Day.self,
            ArchivedTask.self,
            configurations: configuration
        )
        let today = LocalDay.today
        let startedAt = today.startDate().addingTimeInterval(-600)
        let task = Task(
            name: "Legacy runner",
            accumulatedElapsed: 30,
            isRunning: true,
            startedAt: startedAt
        )
        container.mainContext.insert(task)
        try container.mainContext.save()

        _ = TimerManager(modelContext: container.mainContext)

        XCTAssertEqual(task.scheduledDayKey, today.addingDays(-1).key)
        XCTAssertFalse(task.isRunning)
        XCTAssertEqual(task.accumulatedElapsed, 630, accuracy: 0.001)
    }

    func testFutureCorruptRunningTaskStopsWithoutAddingElapsed() throws {
        let (container, manager) = try makeManager()
        _ = container
        let task = manager.createTask(
            name: "Future runner",
            iconName: IconProvider.defaultIcon,
            targetTime: nil,
            displayOrder: nil,
            scheduledDayKey: LocalDay.today.addingDays(1).key,
            lineageID: nil
        )
        task.accumulatedElapsed = 42
        task.isRunning = true
        task.startedAt = .now

        manager.reconcileDayBoundary(at: .now)

        XCTAssertFalse(task.isRunning)
        XCTAssertNil(task.startedAt)
        XCTAssertEqual(task.accumulatedElapsed, 42, accuracy: 0.001)
    }

    func testPauseAllIsIdempotentUnderRepeatedCalls() throws {
        let (container, manager) = try makeManager()
        _ = container
        let task = manager.createTask(
            name: "Runner",
            iconName: IconProvider.defaultIcon,
            targetTime: nil,
            displayOrder: nil,
            scheduledDayKey: LocalDay.today.key,
            lineageID: nil
        )
        manager.start(task: task)
        manager.pauseAllRunningTasks()
        let elapsed = task.accumulatedElapsed

        for _ in 0..<100 {
            manager.pauseAllRunningTasks()
        }

        XCTAssertEqual(task.accumulatedElapsed, elapsed, accuracy: 0.001)
        XCTAssertFalse(task.isRunning)
    }

    func testMacSleepNotificationDoesNotPauseRunningTask() throws {
        let (container, manager) = try makeManager()
        _ = container
        let task = manager.createTask(
            name: "Sleep-proof runner",
            iconName: IconProvider.defaultIcon,
            targetTime: nil,
            displayOrder: nil,
            scheduledDayKey: LocalDay.today.key,
            lineageID: nil
        )
        let startedAt = Date().addingTimeInterval(-300)
        task.accumulatedElapsed = 60
        task.isRunning = true
        task.startedAt = startedAt
        try manager.modelContext.save()

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        XCTAssertTrue(task.isRunning)
        XCTAssertEqual(task.startedAt, startedAt)
        XCTAssertGreaterThanOrEqual(task.currentElapsed(), 360)
    }

    func testClearAllDataRemovesTasksAndArchivedDays() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Task.self,
            Day.self,
            ArchivedTask.self,
            configurations: configuration
        )
        let manager = TimerManager(modelContext: container.mainContext)
        _ = manager.createTask(
            name: "Task",
            iconName: IconProvider.defaultIcon,
            targetTime: nil,
            displayOrder: nil,
            scheduledDayKey: LocalDay.today.key,
            lineageID: nil
        )
        container.mainContext.insert(Day(date: .now, archivedTasks: []))
        try container.mainContext.save()

        manager.clearAllData()

        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Day>()).isEmpty)
    }

    private func makeManager() throws -> (ModelContainer, TimerManager) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Task.self,
            Day.self,
            ArchivedTask.self,
            configurations: configuration
        )
        return (container, TimerManager(modelContext: container.mainContext))
    }
}

/// Treats CSV as untrusted spreadsheet input and stresses large exports.
final class AdversarialCSVTests: XCTestCase {
    func testFormulaLikeNamesAreNeutralized() throws {
        for name in ["=1+1", "+1+1", "-2+3", "@SUM(A1:A2)", "  =4+4"] {
            let task = Task(name: name, scheduledDayKey: LocalDay.today.key)
            let document = try XCTUnwrap(HistoryCSVExporter.makeDocument(
                tasks: [task],
                scope: .allHistory
            ))
            XCTAssertTrue(document.contents.contains("'\(name)"))
            XCTAssertFalse(document.contents.contains(",\(name),"))
        }
    }

    func testSelectedDayExportCannotLeakOtherDays() throws {
        let today = LocalDay.today
        let secret = Task(name: "Other day", scheduledDayKey: today.addingDays(-1).key)
        let visible = Task(name: "Selected", scheduledDayKey: today.key)
        let document = try XCTUnwrap(HistoryCSVExporter.makeDocument(
            tasks: [secret, visible],
            scope: .selectedDay(today)
        ))

        XCTAssertTrue(document.contents.contains("Selected"))
        XCTAssertFalse(document.contents.contains("Other day"))
    }

    func testEmptyScopesProduceNoDocument() {
        XCTAssertNil(HistoryCSVExporter.makeDocument(tasks: [], scope: .allHistory))
        XCTAssertNil(HistoryCSVExporter.makeDocument(
            tasks: [Task(name: "Legacy")],
            scope: .allHistory
        ))
    }

    func testFiveHundredHostileRowsExportDeterministically() throws {
        let day = LocalDay.today
        let tasks = AdversarialSeedData.denseTasks(count: 500, day: day)
        let first = try XCTUnwrap(HistoryCSVExporter.makeDocument(tasks: tasks, scope: .allHistory))
        let second = try XCTUnwrap(HistoryCSVExporter.makeDocument(tasks: tasks.reversed(), scope: .allHistory))

        XCTAssertEqual(first.contents, second.contents)
        XCTAssertEqual(first.contents.components(separatedBy: "\r\n").count, 502)
    }
}

/// Pushes geometry calculations with invalid and extreme list counts.
final class AdversarialLayoutTests: XCTestCase {
    func testNegativeCountsCannotShrinkBelowMinimum() {
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: -1_000,
                completedCount: -1_000,
                isCreating: false,
                isEditing: false
            ),
            190
        )
    }

    func testTenThousandRowsClampAtMaximum() {
        XCTAssertEqual(
            PopoverLayout.preferredHeight(
                activeCount: 5_000,
                completedCount: 5_000,
                isCreating: true,
                isEditing: false
            ),
            PopoverLayout.maximumHeight
        )
    }
}

/// Repeatedly lays out the real SwiftUI dropdown under dense and rapidly changing state.
@MainActor
final class AdversarialViewRenderingTests: XCTestCase {
    func testDenseDropdownRendersAcrossEverySupportedHeight() {
        let tasks = AdversarialSeedData.denseTasks(count: 40, day: .today)
        let viewModel = DropdownViewModel(timerManager: TimerManagerSpy(tasks: tasks))
        let host = NSHostingView(
            rootView: DropdownView(viewModel: viewModel, tickGenerator: TickGenerator())
        )

        for height in stride(from: 188, through: 480, by: 4) {
            host.frame = NSRect(x: 0, y: 0, width: 340, height: height)
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.frame.width, 340)
        }
    }

    func testTwoHundredEditorAndDateTransitionsKeepStableWidth() {
        let tasks = AdversarialSeedData.denseTasks(count: 25, day: .today)
        let viewModel = DropdownViewModel(timerManager: TimerManagerSpy(tasks: tasks))
        let host = NSHostingView(
            rootView: DropdownView(viewModel: viewModel, tickGenerator: TickGenerator())
        )
        host.frame = NSRect(x: 0, y: 0, width: 340, height: 480)

        for iteration in 0..<200 {
            if iteration.isMultiple(of: 2) {
                viewModel.beginCreating()
            } else {
                viewModel.cancelEditor()
                viewModel.showNextDay()
                viewModel.showPreviousDay()
            }
            host.layoutSubtreeIfNeeded()
        }

        XCTAssertEqual(host.frame.width, 340)
        XCTAssertEqual(viewModel.selectedDay, .today)
    }
}

/// In-memory protocol spy for deterministic view-model tests.
private final class TimerManagerSpy: TimerManagerProtocol {
    var tasks: [Task]
    var errorMessage: String?
    private(set) var updateCallCount = 0

    init(tasks: [Task]) {
        self.tasks = tasks
    }

    func start(task: Task) {
        task.isRunning = true
    }

    func pause(task: Task) {
        task.isRunning = false
    }

    func resume(task: Task) {
        task.isRunning = true
    }

    func createTask(
        name: String,
        iconName: String,
        targetTime: TimeInterval?,
        displayOrder: Int?,
        scheduledDayKey: String,
        lineageID: UUID?
    ) -> Task {
        let task = Task(
            name: name,
            iconName: iconName,
            displayOrder: displayOrder ?? 0,
            targetTime: targetTime,
            scheduledDayKey: scheduledDayKey,
            lineageID: lineageID
        )
        tasks.append(task)
        return task
    }

    func delete(task: Task) {
        tasks.removeAll { $0.id == task.id }
    }

    func complete(task: Task) {
        task.isCompleted = true
        task.isRunning = false
    }

    func uncomplete(task: Task) {
        task.isCompleted = false
    }

    func update(task: Task, name: String, targetTime: TimeInterval?) {
        updateCallCount += 1
        task.name = name
        task.targetTime = targetTime
    }

    func reorderTasks(_ tasks: [Task]) {
        for (index, task) in tasks.enumerated() {
            task.displayOrder = index
        }
        self.tasks = tasks
    }

    func reconcileDayBoundary(at date: Date) {}

    func clearAllData() {
        tasks = []
    }

    func clearError() {
        errorMessage = nil
    }
}
