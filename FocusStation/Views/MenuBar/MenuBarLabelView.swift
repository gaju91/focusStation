import SwiftUI

/// The menu bar label. Receives the tick generator and timer manager
/// as direct parameters — not via @Environment — because
/// MenuBarExtra labels don't reliably inherit custom environment values.
struct MenuBarLabelView: View {
    let tickGenerator: TickGenerator
    let timerManager: any TimerManagerProtocol

    var body: some View {
        StatusBarLabelView(timerManager: timerManager, tick: tickGenerator.value)
            .id(tickGenerator.value)
    }
}
