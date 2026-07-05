import AppKit
import Observation
import SwiftData
import SwiftUI

private enum Layout {
    static let statusItemWidth: CGFloat = 180
    static let popoverWidth: CGFloat = 280
    static let popoverHeight: CGFloat = 400
}

/// Owns the NSStatusBar item, NSPopover, tick observation, and
/// appearance tracking. Created once at app init — lifetime matches app.
@MainActor
final class MenuBarController {
    private let timerManager: any TimerManagerProtocol
    private let tickGenerator: TickGenerator
    private let modelContext: ModelContext
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var hostingView: NSHostingView<MenuBarContainerView>?

    init(
        timerManager: any TimerManagerProtocol,
        tickGenerator: TickGenerator,
        modelContext: ModelContext
    ) {
        self.timerManager = timerManager
        self.tickGenerator = tickGenerator
        self.modelContext = modelContext
        setupStatusBar()
        observeTick()
    }

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: Layout.statusItemWidth)
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
        hosting.frame.size = NSSize(width: Layout.statusItemWidth, height: NSStatusBar.system.thickness)
        hosting.appearance = NSApp.effectiveAppearance
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
        popover.contentSize = NSSize(width: Layout.popoverWidth, height: Layout.popoverHeight)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: DropdownView()
                .environment(\.modelContext, modelContext)
                .environment(\.timerManager, timerManager)
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.contentSize = NSSize(width: Layout.popoverWidth, height: Layout.popoverHeight)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Re-assert after show(); NSHostingController may override contentSize.
            popover.contentSize = NSSize(width: Layout.popoverWidth, height: Layout.popoverHeight)
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
        hostingView?.appearance = NSApp.effectiveAppearance
        hostingView?.rootView = MenuBarContainerView(
            timerManager: timerManager,
            tick: tickGenerator.value
        )
    }
}
