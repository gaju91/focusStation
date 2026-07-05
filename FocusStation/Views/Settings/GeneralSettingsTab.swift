import SwiftUI
import ServiceManagement

/// General settings: launch at login, sleep/wake, and data reset.
struct GeneralSettingsTab: View {
    @Environment(\.timerManager) private var timerManager: any TimerManagerProtocol
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("pauseOnSleep") private var pauseOnSleep: Bool = true
    @AppStorage("resumeOnWake") private var resumeOnWake: Bool = true
    @State private var showResetConfirmation: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            } header: {
                Text("General")
            }

            Section {
                Toggle("Pause on Sleep", isOn: $pauseOnSleep)
                Toggle("Resume on Wake", isOn: $resumeOnWake)
                    .disabled(!pauseOnSleep)
            } header: {
                Text("Sleep & Wake")
            } footer: {
                if !pauseOnSleep {
                    Text("Resume on Wake requires Pause on Sleep to be enabled.")
                }
            }

            Section {
                Button("Reset All Data", role: .destructive) {
                    showResetConfirmation = true
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Removes all tasks and history permanently.")
            }
        }
        .formStyle(.grouped)
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                timerManager.clearAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all tasks and history. This cannot be undone.")
        }
    }
}
