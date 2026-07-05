import SwiftUI

/// Shown when the task list is empty.
/// Provides a direct path to creating the first task.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            Text("No tasks yet.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add your first task")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }
}
