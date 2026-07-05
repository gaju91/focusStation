import SwiftData

extension ModelContainer {
    /// Shared ModelContainer for the entire app.
    /// Uses on-disk store at the default SwiftData location.
    /// Schemas: Task, Day (which includes ArchivedTask via relationship).
    static let appContainer: ModelContainer? = {
        let schema = Schema([
            Task.self,
            Day.self,
            ArchivedTask.self
        ])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        return try? ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }()
}
