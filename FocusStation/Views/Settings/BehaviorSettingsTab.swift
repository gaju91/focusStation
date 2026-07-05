import SwiftUI

/// Behavior: single-timer enforcement is mandatory.
struct BehaviorSettingsTab: View {
    var body: some View {
        Form {
            Section {
                Text("Only one task can run at a time.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Timer Mode")
            } footer: {
                Text("Starting or resuming a task pauses any other running task.")
            }
        }
        .formStyle(.grouped)
    }
}
