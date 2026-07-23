import Foundation

/// Utility for formatting TimeInterval into human-readable elapsed time strings.
/// Omits zero components for compact display.
enum TimeFormatter {
    static func format(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval > 0 else { return "0m" }
        let maximumDisplaySeconds = TimeInterval(999 * 3600 + 3599)
        guard interval <= maximumDisplaySeconds else { return "999h+" }
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 && minutes > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        }

        if hours > 0 {
            return String(format: "%dh", hours)
        }

        if minutes > 0 {
            return String(format: "%dm", minutes)
        }

        if seconds > 0 {
            return String(format: "%ds", seconds)
        }

        return "0m"
    }
}
