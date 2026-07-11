import AppKit
import Observation
import SwiftUI

private enum Layout {
    static let popoverMinWidth: CGFloat = 230
    static let popoverMaxWidth: CGFloat = 400
    static let popoverHeight: CGFloat = 400
}

/// Owns the NSStatusBar item, NSPopover, tick observation, and
/// appearance tracking. Created once at app init — lifetime matches app.
@MainActor
final class MenuBarController {
    private let timerManager: any TimerManagerProtocol
    private let tickGenerator: TickGenerator
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var hostingView: NSHostingView<MenuBarContainerView>?

    init(
        timerManager: any TimerManagerProtocol,
        tickGenerator: TickGenerator
    ) {
        self.timerManager = timerManager
        self.tickGenerator = tickGenerator
        setupStatusBar()
        observeTick()
    }

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        guard let button = item.button else { return }

        button.title = ""
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])

        let rootView = MenuBarContainerView(
            timerManager: timerManager,
            tick: tickGenerator.value
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        self.hostingView = hosting

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: button.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: DropdownView()
                .environment(\.timerManager, timerManager)
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let fittingWidth = popover.contentViewController?.view.fittingSize.width ?? Layout.popoverMinWidth
            let width = min(max(fittingWidth, Layout.popoverMinWidth), Layout.popoverMaxWidth)
            popover.contentSize = NSSize(width: width, height: Layout.popoverHeight)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func observeTick() {
        withObservationTracking {
            _ = tickGenerator.value
        } onChange: { [weak self] in
            Swift.Task { @MainActor [weak self] in
                self?.updateLabel()
                self?.observeTick()
            }
        }
    }

    private func updateLabel() {
        hostingView?.rootView = MenuBarContainerView(
            timerManager: timerManager,
            tick: tickGenerator.value
        )
    }
}
