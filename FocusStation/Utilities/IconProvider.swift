import Foundation

/// Registry of available SF Symbol names for task icons.
/// These are all valid Apple SF Symbols available on macOS 14+.
enum IconProvider {
    /// All selectable icons in the icon picker.
    /// Ordered by category for logical grouping.
    static let allIcons: [String] = [
        "brain.head.profile",
        "lightbulb",
        "target",
        "scope",

        "hammer",
        "wrench.and.screwdriver",
        "gearshape",
        "curlybraces",
        "text.alignleft",

        "phone",
        "envelope",
        "message",
        "bubble.left",

        "paintpalette",
        "pencil",
        "music.note",
        "film",

        "briefcase",
        "chart.bar",
        "doc.text",
        "calendar",

        "book",
        "graduationcap",
        "newspaper",
        "globe",

        "heart",
        "person",
        "house",
        "cart"
    ]

    /// The default icon assigned to new tasks.
    static let defaultIcon: String = "brain.head.profile"

    /// Returns a human-readable label for a given icon name.
    /// Falls back to the raw SF Symbol name with formatting applied.
    static func label(for iconName: String) -> String {
        iconName
            .split(separator: ".")
            .joined(separator: " ")
            .capitalized
    }
}
