import SwiftData
import SwiftUI
import AppKit

/// Owns the process-lifetime dependencies and installs the menu-bar item only
/// after AppKit has attached the application to a screen.
@MainActor
final class FocusStationCoordinator: NSObject {
    private let container: ModelContainer
    private let timerManager: TimerManager
    private let tickGenerator: TickGenerator
    private var menuBarController: MenuBarController?

    init(container: ModelContainer) {
        self.container = container
        self.timerManager = TimerManager(modelContext: container.mainContext)
        self.tickGenerator = TickGenerator()
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidFinishLaunching),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func applicationDidFinishLaunching(_: Notification) {
        scheduleMenuBarInstallation()
    }

    @objc private func applicationWillTerminate(_: Notification) {
        timerManager.pauseAllRunningTasks()
    }

    private func scheduleMenuBarInstallation() {
        guard menuBarController == nil else { return }
        perform(#selector(installMenuBar), with: nil, afterDelay: 0)
    }

    @objc private func installMenuBar() {
        guard menuBarController == nil else { return }
        menuBarController = MenuBarController(
            timerManager: timerManager,
            tickGenerator: tickGenerator
        )
    }
}

/// FocusStation menu-bar application entry point.
@main
struct FocusStationApp: App {
    private let coordinator: FocusStationCoordinator

    init() {
        guard let container = ModelContainer.appContainer else {
            fatalError("Failed to create ModelContainer")
        }
        coordinator = FocusStationCoordinator(container: container)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(false)) {
            EmptyView()
        } label: {
            EmptyView()
        }
    }
}
