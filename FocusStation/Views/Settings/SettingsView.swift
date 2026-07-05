import SwiftUI

/// Tabbed settings container.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }

            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }

            BehaviorSettingsTab()
                .tabItem { Label("Behavior", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 600, height: 460)
    }
}
