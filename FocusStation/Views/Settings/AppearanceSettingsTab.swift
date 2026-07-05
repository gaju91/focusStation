import SwiftUI

/// Appearance settings: hide completed tasks.
struct AppearanceSettingsTab: View {
    @AppStorage("hideCompleted") private var hideCompleted: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Hide Completed Tasks", isOn: $hideCompleted)
            } header: {
                Text("Display")
            }
        }
        .formStyle(.grouped)
    }
}
