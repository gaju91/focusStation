import AppKit
import Observation
import SwiftUI

/// Shared geometry for the compact popover and its content-driven height.
enum PopoverLayout {
    static let width: CGFloat = 340
    static let minimumHeight: CGFloat = 188
    static let maximumHeight: CGFloat = 480
    static let headerHeight: CGFloat = 44
    static let footerHeight: CGFloat = 44
    static let taskRowHeight: CGFloat = 64
    static let editorRowHeight: CGFloat = 76
    static let emptyStateHeight: CGFloat = 100
    static let compactEmptyStateHeight: CGFloat = 64

    /// Returns a deterministic popover height without measuring a view during layout.
    static func preferredHeight(
        activeCount: Int,
        completedCount: Int,
        isCreating: Bool,
        isEditing: Bool
    ) -> CGFloat {
        let safeActiveCount = max(0, activeCount)
        let safeCompletedCount = max(0, completedCount)
        var contentHeight: CGFloat = 0

        let safeTaskCount = safeActiveCount + safeCompletedCount
        if safeTaskCount == 0, !isCreating {
            contentHeight += emptyStateHeight
        } else {
            contentHeight += CGFloat(safeTaskCount) * taskRowHeight
        }

        if isCreating {
            contentHeight += editorRowHeight
        } else if isEditing {
            contentHeight += editorRowHeight - taskRowHeight
        }

        let desiredHeight = headerHeight + footerHeight + 2 + contentHeight
        return min(max(desiredHeight, minimumHeight), maximumHeight)
    }
}

private enum StatusBarLayout {
    static let horizontalPadding: CGFloat = 8
    static let contentChromeWidth: CGFloat = 38
    static let minimumWidth: CGFloat = 24
    static let maximumWidth: CGFloat = 260

    static var maximumTextWidth: CGFloat {
        maximumWidth - contentChromeWidth - horizontalPadding
    }
}

/// Produces stable menu-bar content while keeping the timer suffix visible.
enum StatusBarContent {
    static func displayedTask(in tasks: [Task]) -> Task? {
        tasks.first(where: { $0.displayState == .running })
            ?? tasks.first(where: { $0.displayState == .paused })
    }

    static func elapsedText(for task: Task) -> String {
        TimeFormatter.format(task.currentElapsed())
    }

    static func timeText(for task: Task) -> String {
        var text = elapsedText(for: task)
        if let target = task.targetTime, target > 0 {
            text += " / \(TimeFormatter.format(target))"
        }
        return text
    }

    static func elapsedTone(for task: Task) -> Task.ElapsedTone {
        task.elapsedTone()
    }
}

/// Owns the native status item, popover, shared dropdown state, and live updates.
@MainActor
final class MenuBarController {
    private let timerManager: any TimerManagerProtocol
    private let tickGenerator: TickGenerator
    private let dropdownViewModel: DropdownViewModel
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var isStatusUpdateScheduled = false
    private var isPopoverAnchorUpdateScheduled = false
    private var isPopoverResizeScheduled = false
    private var shouldAnimateScheduledResize = false
    private var observedDay = LocalDay.today

    init(
        timerManager: any TimerManagerProtocol,
        tickGenerator: TickGenerator
    ) {
        self.timerManager = timerManager
        self.tickGenerator = tickGenerator
        self.dropdownViewModel = DropdownViewModel(timerManager: timerManager)
        setupStatusBar()
        observeTick()
        observeTasks()
        observeDropdownLayout()
    }

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(
            withLength: StatusBarLayout.minimumWidth
        )
        item.isVisible = true
        self.statusItem = item

        guard let button = item.button else { return }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.cell?.lineBreakMode = .byTruncatingTail
        button.cell?.usesSingleLineMode = true
        button.imageScaling = .scaleProportionallyDown

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: DropdownView(
                viewModel: dropdownViewModel,
                tickGenerator: tickGenerator
            )
        )
        popover.contentSize = desiredPopoverSize
        self.popover = popover
        updateLabel()
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            dropdownViewModel.refreshTasks()
            applyPopoverSize(animated: false)
            NSApp.activate(ignoringOtherApps: true)
            popover.show(
                relativeTo: popoverAnchorRect(for: button),
                of: button,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func observeTasks() {
        withObservationTracking {
            for task in timerManager.tasks {
                _ = task.name
                _ = task.iconName
                _ = task.isRunning
                _ = task.isCompleted
                _ = task.accumulatedElapsed
                _ = task.targetTime
                _ = task.displayOrder
                _ = task.scheduledDayKey
                _ = task.lineageID
            }
        } onChange: { [weak self] in
            Swift.Task { @MainActor [weak self] in
                self?.dropdownViewModel.refreshTasks()
                self?.updateLabel()
                self?.resizeVisiblePopover()
                self?.observeTasks()
            }
        }
    }

    private func observeDropdownLayout() {
        withObservationTracking {
            _ = dropdownViewModel.revision
            _ = dropdownViewModel.activeTasks.count
            _ = dropdownViewModel.completedTasks.count
            _ = dropdownViewModel.editor?.id
        } onChange: { [weak self] in
            Swift.Task { @MainActor [weak self] in
                self?.updateLabel()
                self?.resizeVisiblePopover()
                self?.observeDropdownLayout()
            }
        }
    }

    private func observeTick() {
        withObservationTracking {
            _ = tickGenerator.value
        } onChange: { [weak self] in
            Swift.Task { @MainActor [weak self] in
                guard let self else { return }
                let currentDay = LocalDay.today
                self.timerManager.reconcileDayBoundary(at: .now)
                if currentDay != self.observedDay {
                    self.observedDay = currentDay
                    self.dropdownViewModel.refreshTasks()
                    self.resizeVisiblePopover()
                }
                self.updateLabel()
                self.observeTick()
            }
        }
    }

    private func updateLabel() {
        guard !isStatusUpdateScheduled else { return }
        isStatusUpdateScheduled = true

        Swift.Task { @MainActor [weak self] in
            await Swift.Task.yield()
            guard let self else { return }
            self.isStatusUpdateScheduled = false
            self.applyStatusUpdate()
        }
    }

    private func applyStatusUpdate() {
        guard let button = statusItem?.button else { return }
        updateStatusButton(button)
        if resizeStatusItem() {
            updateVisiblePopoverAnchor()
        }
    }

    private func resizeStatusItem() -> Bool {
        guard let item = statusItem else { return false }
        let width = desiredStatusItemWidth()
        guard abs(item.length - width) > 0.5 else { return false }
        item.length = width
        return true
    }

    private func updateVisiblePopoverAnchor() {
        guard let popover, popover.isShown else { return }
        guard !isPopoverAnchorUpdateScheduled else { return }
        isPopoverAnchorUpdateScheduled = true

        Swift.Task { @MainActor [weak self] in
            await Swift.Task.yield()
            guard let self else { return }
            self.isPopoverAnchorUpdateScheduled = false
            guard
                let popover = self.popover,
                popover.isShown,
                let button = self.statusItem?.button
            else { return }
            popover.positioningRect = self.popoverAnchorRect(for: button)
        }
    }

    private func popoverAnchorRect(for button: NSStatusBarButton) -> NSRect {
        NSRect(
            x: button.bounds.midX - 0.5,
            y: button.bounds.minY,
            width: 1,
            height: button.bounds.height
        )
    }

    private func updateStatusButton(_ button: NSStatusBarButton) {
        guard let task = displayedTask else {
            let image = NSImage(
                systemSymbolName: "brain.head.profile",
                accessibilityDescription: "FocusStation"
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.toolTip = "FocusStation"
            return
        }

        let image = NSImage(
            systemSymbolName: task.iconName,
            accessibilityDescription: task.name
        )
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.title = ""
        button.attributedTitle = attributedStatusTitle(for: task)
        button.toolTip = statusTooltip(for: task)
    }

    private func desiredStatusItemWidth() -> CGFloat {
        guard let task = displayedTask else {
            return StatusBarLayout.minimumWidth
        }

        let label = statusText(for: task)
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let textWidth = (label as NSString).size(withAttributes: [.font: font]).width
        let desiredWidth = textWidth
            + StatusBarLayout.contentChromeWidth
            + StatusBarLayout.horizontalPadding
        return min(
            max(desiredWidth, StatusBarLayout.minimumWidth),
            StatusBarLayout.maximumWidth
        )
    }

    private var displayedTask: Task? {
        let today = LocalDay.today
        let todayTasks = timerManager.tasks.filter { $0.isScheduled(on: today) }
        return StatusBarContent.displayedTask(in: todayTasks)
    }

    private func statusText(for task: Task) -> String {
        let timeText = StatusBarContent.timeText(for: task)
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let spacing = "  "
        let reservedWidth = textWidth(timeText + spacing, font: font)
        let nameWidth = max(0, StatusBarLayout.maximumTextWidth - reservedWidth)
        let name = truncated(task.name, toWidth: nameWidth, font: font)
        return "\(name)\(spacing)\(timeText)"
    }

    private func statusTooltip(for task: Task) -> String {
        let state = task.displayState == .running ? "Running" : "Paused"
        return "\(task.name)\n\(state) · \(StatusBarContent.timeText(for: task))"
    }

    private func attributedStatusTitle(for task: Task) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let semiboldFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let timeText = StatusBarContent.timeText(for: task)
        let spacing = "  "
        let reservedWidth = textWidth(timeText + spacing, font: font)
        let nameWidth = max(0, StatusBarLayout.maximumTextWidth - reservedWidth)
        let name = truncated(task.name, toWidth: nameWidth, font: font)
        let prefix = " \(name)\(spacing)"
        let attributedTitle = NSMutableAttributedString(
            string: prefix + timeText,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.controlTextColor
            ]
        )

        let elapsedText = StatusBarContent.elapsedText(for: task)
        let elapsedRange = NSRange(
            location: (prefix as NSString).length,
            length: (elapsedText as NSString).length
        )
        attributedTitle.addAttributes(
            [
                .font: semiboldFont,
                .foregroundColor: elapsedColor(for: task)
            ],
            range: elapsedRange
        )

        if timeText.count > elapsedText.count {
            let targetRange = NSRange(
                location: elapsedRange.location + elapsedRange.length,
                length: (timeText as NSString).length - elapsedRange.length
            )
            attributedTitle.addAttribute(
                .foregroundColor,
                value: NSColor.controlTextColor,
                range: targetRange
            )
        }
        return attributedTitle
    }

    private func elapsedColor(for task: Task) -> NSColor {
        switch StatusBarContent.elapsedTone(for: task) {
        case .overdue:
            return .systemRed
        case .paused:
            return .systemOrange
        case .withinLimit:
            return .systemGreen
        }
    }

    private func truncated(
        _ text: String,
        toWidth maximumWidth: CGFloat,
        font: NSFont
    ) -> String {
        guard textWidth(text, font: font) > maximumWidth else { return text }
        let ellipsis = "…"
        guard textWidth(ellipsis, font: font) <= maximumWidth else { return "" }

        var lowerBound = 0
        var upperBound = text.count
        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound + 1) / 2
            let endIndex = text.index(text.startIndex, offsetBy: midpoint)
            let candidate = String(text[..<endIndex]) + ellipsis
            if textWidth(candidate, font: font) <= maximumWidth {
                lowerBound = midpoint
            } else {
                upperBound = midpoint - 1
            }
        }

        let endIndex = text.index(text.startIndex, offsetBy: lowerBound)
        return String(text[..<endIndex]) + ellipsis
    }

    private func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private var desiredPopoverSize: NSSize {
        let isCreating = dropdownViewModel.isCreating
        let isEditing = dropdownViewModel.editor != nil && !isCreating
        let height = PopoverLayout.preferredHeight(
            activeCount: dropdownViewModel.activeTasks.count,
            completedCount: dropdownViewModel.completedTasks.count,
            isCreating: isCreating,
            isEditing: isEditing
        )
        return NSSize(width: PopoverLayout.width, height: height)
    }

    private func resizeVisiblePopover() {
        guard let popover, popover.isShown else { return }
        shouldAnimateScheduledResize = true
        guard !isPopoverResizeScheduled else { return }
        isPopoverResizeScheduled = true

        Swift.Task { @MainActor [weak self] in
            await Swift.Task.yield()
            guard let self else { return }
            let shouldAnimate = self.shouldAnimateScheduledResize
            self.isPopoverResizeScheduled = false
            self.shouldAnimateScheduledResize = false
            self.applyPopoverSize(animated: shouldAnimate)
        }
    }

    private func applyPopoverSize(animated: Bool) {
        guard let popover else { return }
        let size = desiredPopoverSize
        guard popover.contentSize != size else { return }

        if animated, popover.isShown {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.allowsImplicitAnimation = true
                popover.contentSize = size
            }
        } else {
            popover.contentSize = size
        }
    }
}
