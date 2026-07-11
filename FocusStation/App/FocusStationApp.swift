import SwiftData
import SwiftUI

@main
struct FocusStationApp: App {
    private let container: ModelContainer
    @State private var timerManager: any TimerManagerProtocol
    @State private var tickGenerator: TickGenerator
    @State private var menuBarController: MenuBarController?

    init() {
        guard let container = ModelContainer.appContainer else {
            fatalError("Failed to create ModelContainer")
        }
        self.container = container

        let manager = TimerManager(modelContext: container.mainContext)
        let tickGen = TickGenerator()
        self._timerManager = State(initialValue: manager)
        self._tickGenerator = State(initialValue: tickGen)

        let controller = MenuBarController(
            timerManager: manager,
            tickGenerator: tickGen
        )
        self._menuBarController = State(initialValue: controller)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(false)) {
            EmptyView()
        } label: {
            EmptyView()
        }
    }
}
