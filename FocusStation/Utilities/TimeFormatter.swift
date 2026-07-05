import Foundation

/// Utility for formatting TimeInterval into human-readable elapsed time strings.
/// Omits zero components for compact display.
enum TimeFormatter {
    static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours >= 24 {
            return "24h+"
        }

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
