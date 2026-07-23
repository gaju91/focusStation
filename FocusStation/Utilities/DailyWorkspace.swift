import Foundation

/// Stable Gregorian local-calendar date used to assign tasks without time-zone drift.
struct LocalDay: Hashable, Comparable, Identifiable {
    let key: String

    var id: String { key }

    static var today: LocalDay {
        LocalDay(date: .now)
    }

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = calendar.timeZone
        let components = localCalendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1
        let month = components.month ?? 1
        let day = components.day ?? 1
        self.key = String(format: "%04d-%02d-%02d", year, month, day)
    }

    init?(key: String) {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2]),
            (1...12).contains(month),
            (1...31).contains(day)
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: 12
        )
        guard
            let date = calendar.date(from: components),
            calendar.component(.year, from: date) == year,
            calendar.component(.month, from: date) == month,
            calendar.component(.day, from: date) == day
        else { return nil }
        self.key = key
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        lhs.key < rhs.key
    }

    /// Noon on this local day, used for locale-aware display formatting.
    func representativeDate(calendar: Calendar = .autoupdatingCurrent) -> Date {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else { return .now }

        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = calendar.timeZone
        return localCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: 12
        )) ?? .now
    }

    /// Start of this day in the supplied local time zone.
    func startDate(calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.startOfDay(for: representativeDate(calendar: calendar))
    }

    /// Start of the following local calendar day, respecting daylight-saving changes.
    func nextStartDate(calendar: Calendar = .autoupdatingCurrent) -> Date {
        let start = startDate(calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start
    }

    /// Adjacent local day reached through calendar arithmetic rather than fixed seconds.
    func addingDays(
        _ value: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> LocalDay {
        let date = calendar.date(
            byAdding: .day,
            value: value,
            to: representativeDate(calendar: calendar)
        ) ?? representativeDate(calendar: calendar)
        return LocalDay(date: date, calendar: calendar)
    }

    /// Maximum focus allocation available on this day; Today begins at the current instant.
    func availableDuration(
        at date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TimeInterval {
        let today = LocalDay(date: date, calendar: calendar)
        let start = self == today ? max(date, startDate(calendar: calendar)) : startDate(calendar: calendar)
        return max(0, nextStartDate(calendar: calendar).timeIntervalSince(start))
    }
}

/// Scope selected from the compact task-history export menu.
enum HistoryExportScope {
    case selectedDay(LocalDay)
    case allHistory
}

/// CSV payload and native save-panel filename.
struct HistoryCSVDocument {
    let contents: String
    let suggestedFilename: String
}

/// Builds deterministic, spreadsheet-friendly task history without external dependencies.
enum HistoryCSVExporter {
    static func makeDocument(
        tasks: [Task],
        scope: HistoryExportScope,
        now: Date = .now
    ) -> HistoryCSVDocument? {
        let selectedTasks: [Task]
        switch scope {
        case .selectedDay(let day):
            selectedTasks = tasks.filter { $0.scheduledDayKey == day.key }
        case .allHistory:
            selectedTasks = tasks.filter { $0.scheduledDayKey != nil }
        }
        guard !selectedTasks.isEmpty else { return nil }

        let sortedTasks = selectedTasks.sorted { lhs, rhs in
            let lhsDay = lhs.scheduledDayKey ?? ""
            let rhsDay = rhs.scheduledDayKey ?? ""
            if lhsDay == rhsDay {
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.displayOrder < rhs.displayOrder
            }
            return lhsDay < rhsDay
        }

        var rows = [
            "Date,Task,Status,Tracked Seconds,Tracked Time,Target Seconds,Target Time,Overtime Seconds"
        ]
        for task in sortedTasks {
            let elapsed = max(0, task.currentElapsed(at: now))
            let target = task.targetTime.flatMap { $0 > 0 ? $0 : nil }
            let overtime = target.map { max(0, elapsed - $0) } ?? 0
            let fields = [
                task.scheduledDayKey ?? "",
                spreadsheetSafeText(task.name),
                task.isCompleted ? "Completed" : "Incomplete",
                String(Int(elapsed.rounded())),
                TimeFormatter.format(elapsed),
                target.map { String(Int($0.rounded())) } ?? "",
                target.map(TimeFormatter.format) ?? "",
                String(Int(overtime.rounded()))
            ]
            rows.append(fields.map(csvField).joined(separator: ","))
        }

        let filename: String
        switch scope {
        case .selectedDay(let day):
            filename = "FocusStation-\(day.key).csv"
        case .allHistory:
            let firstDay = sortedTasks.first?.scheduledDayKey ?? "History"
            let lastDay = sortedTasks.last?.scheduledDayKey ?? firstDay
            filename = "FocusStation-History-\(firstDay)-to-\(lastDay).csv"
        }
        return HistoryCSVDocument(
            contents: rows.joined(separator: "\r\n") + "\r\n",
            suggestedFilename: filename
        )
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func spreadsheetSafeText(_ value: String) -> String {
        let firstContent = value.first { !$0.isWhitespace }
        guard
            let firstContent,
            "=+-@".contains(firstContent)
        else { return value }
        return "'\(value)"
    }
}
