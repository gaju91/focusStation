import SwiftUI

/// Wrapper view to avoid AnyView in NSHostingView.
/// AnyView breaks intrinsicContentSize calculation.
struct MenuBarContainerView: View {
    let timerManager: any TimerManagerProtocol
    let tick: Int

    var body: some View {
        StatusBarLabelView(timerManager: timerManager)
            .id(tick)
    }
}
