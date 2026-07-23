import SwiftUI

/// Quiet placeholder shown when there are no active tasks.
struct EmptyStateView: View {
    let compact: Bool
    let title: String

    init(compact: Bool, title: String = "No active tasks") {
        self.compact = compact
        self.title = title
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: compact ? 16 : 20))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: compact
                ? PopoverLayout.compactEmptyStateHeight
                : PopoverLayout.emptyStateHeight
        )
    }
}
