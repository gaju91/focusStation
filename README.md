<p align="center">
  <img src="docs/focusStation_Desktop_View.png" alt="FocusStation Desktop View" width="800">
</p>

# FocusStation

**A native macOS menu bar task timer. Track your time, stay focused — zero friction.**

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/Persistence-SwiftData-green)](https://developer.apple.com/xcode/swiftdata/)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-silver)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-purple)](LICENSE)

FocusStation lives in your Mac's menu bar. Add tasks, start a timer, and your progress is always one glance away. No accounts, no cloud, no complexity — just you and your work.

---

## Install

1. Download `FocusStation-v0.1.0.zip` from [Releases](https://github.com/gaju91/focusStation/releases)
2. Unzip and drag `FocusStation.app` to `/Applications`
3. **First launch:** right-click → **Open** (ad-hoc signed — Gatekeeper requires this once)

---

## Screenshots

<p align="center">
  <img src="docs/focusStation_Focus_View.png" alt="Focus View" width="400">
</p>

---

## Usage

- **Add a task:** click "Add Task", type a name, set optional target hours/minutes, hit Save
- **Start tracking:** click ▶ on any task — only one timer runs at a time
- **Menu bar glance:** active task name + elapsed / target visible without opening the popover
- **Edit inline:** hover a row → pencil icon → edit name or target
- **Reorder:** drag rows via the handle

---

## Development

### Requirements
- macOS 14 (Sonoma) or later
- Xcode 16 or later

### Build
```bash
git clone https://github.com/gaju91/focusStation.git
cd focusStation
xcodebuild -project FocusStation.xcodeproj -scheme FocusStation -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/FocusStation-*/Build/Products/Debug/FocusStation.app
```

**That's it.** Zero dependencies. Zero package managers. Zero third-party code.

### Release

Follow these steps to create a distributable ZIP. Each step builds on the previous one.

**1. Build the Release version of the app**

This compiles the app with optimizations (no debug symbols).

```bash
xcodebuild -project FocusStation.xcodeproj -scheme FocusStation -configuration Release build
```

The compiled `.app` bundle lands at `build/Release/FocusStation.app`.

**2. Package as a ZIP**

This creates a single compressed file you can share. `ditto` preserves macOS metadata (permissions, code signature) which plain `zip` would strip.

```bash
ditto -c -k --keepParent build/Release/FocusStation.app FocusStation-v0.1.0.zip
```

Replace `v0.1.0` with the current version number.

**3. Tag the release**

This marks a point in Git history. Use [semantic versioning](https://semver.org): `MAJOR.MINOR.PATCH`. For example, `v0.1.0` for the first release, `v0.1.1` for a bug fix, `v0.2.0` for new features.

```bash
git tag v0.1.0
git push origin v0.1.0
```

**4. Upload to GitHub**

Go to [GitHub Releases](https://github.com/gaju91/focusStation/releases) → "Draft a new release":
- **Tag:** select the tag you just pushed (e.g., `v0.1.0`)
- **Title:** `FocusStation v0.1.0`
- **Description:** a brief list of changes since the last release
- **Attach:** drag the `.zip` file you created in step 2
- Click **Publish release**

The ZIP is now publicly downloadable from the Releases page — anyone can install from `## Install` above.

---

## Project Structure (19 files)

```
FocusStation/
├── App/
│   ├── FocusStationApp.swift         # @main — DI, dummy MenuBarExtra
│   ├── ModelContainer+App.swift      # SwiftData schema + on-disk store
│   └── EnvironmentKeys.swift         # @Entry for TimerManagerProtocol
├── Models/
│   ├── Task.swift                    # @Model: name, icon, timestamps, isRunning, displayState
│   └── Day.swift                     # Archived day schema (forward compatibility)
├── Services/
│   ├── TimerManagerProtocol.swift    # 15-member contract for timer CRUD
│   ├── TimerManager.swift            # @Observable timer engine + single-timer enforcement + CRUD
│   ├── TimerManager+SleepWake.swift  # NSWorkspace sleep → pause all, wake → restart display
│   ├── TickGenerator.swift           # @MainActor @Observable 1s tick source
│   └── MenuBarController.swift       # NSStatusBar + NSPopover lifecycle + tick observation
├── ViewModels/
│   └── DropdownViewModel.swift       # @Observable — syncs tasks, exposes sortedTasks, CRUD passthrough
├── Views/
│   ├── MenuBar/
│   │   ├── StatusBarLabelView.swift   # Running/Paused/Idle label with time and target
│   │   ├── MenuBarLabelView.swift     # Bridges TickGenerator + timerManager
│   │   └── MenuBarContainerView.swift # Typed NSHostingView wrapper (avoids AnyView)
│   └── Dropdown/
│       ├── DropdownView.swift         # Task list, inline task creation, inline editing
│       ├── TaskRowView.swift          # Single row: checkbox, name, elapsed, action buttons, inline edit
│       └── EmptyStateView.swift       # "No tasks yet" placeholder
├── Utilities/
│   ├── TimeFormatter.swift            # TimeInterval → "1h23m" / "45m" (omits zero components)
│   └── IconProvider.swift             # 32 SF Symbol registry + default icon
└── Resources/
    └── Info.plist                     # LSUIElement = true (hide from Dock)
```

---

## Architecture

### Pattern: MVVM + @Observable

```
┌──────────┐     reads      ┌──────────────┐     calls     ┌─────────────┐
│   View   │ ←───────────── │  ViewModel   │ ────────────→ │   Service   │
│ (SwiftUI)│                │ (@Observable)│               │(TimerManager)│
└──────────┘                └──────────────┘               └──────┬──────┘
                                                                  │
                                                            reads/writes
                                                                  │
                                                            ┌─────▼──────┐
                                                            │ SwiftData  │
                                                            │ (on disk)  │
                                                            └────────────┘
```

- **Views** render pixels. No business logic, no SwiftData access.
- **ViewModels** (`@Observable` classes, import `Observation`) prepare data.
- **Services** own state. `TimerManager` is the sole mutation point for tasks.
- **Protocol DI** — ViewModels depend on `any TimerManagerProtocol`, never the concrete class. `NoOpTimerManager` serves as the `@Entry` default.

### Timer Engine — Timestamp-Based, Zero Drift

```swift
func currentElapsed() -> TimeInterval {
    guard isRunning, let startedAt else { return accumulatedElapsed }
    return accumulatedElapsed + Date.now.timeIntervalSince(startedAt)
}
```

- **No counters.** `elapsed += 1` never appears — that drifts and breaks on sleep.
- **Started timestamp** recorded on start/resume. Paused captures elapsed into `accumulatedElapsed`.
- **Live display** computed on every render: `accumulated + (now - startedAt)`.
- **Sleep-safe** — on wake, the math accounts for elapsed wall-clock time automatically.
- **Single-timer enforcement** — `TimerManager.start()` and `resume()` both call `pauseOtherRunningTasks(except:)`. Starting or resuming a task automatically pauses any currently running task. This is mandatory, not a toggle-able setting.

### Menu Bar — NSStatusBar + NSPopover

The initial `MenuBarExtra` approach was abandoned because SwiftUI clips label content. The current implementation uses:

- `NSStatusBar.system.statusItem(withLength: .variableLength)` — shrinks to icon-only when idle, expands for active timers. No wasted space.
- `NSHostingView<MenuBarContainerView>` — embedded SwiftUI inside the status button.
- `NSPopover` with `.transient` behavior + `NSHostingController` — dropdown panel.
- `TickGenerator` (`@Observable`, 1s selector-based timer on `RunLoop.main.common`) — drives `withObservationTracking` in `MenuBarController` to re-render the label each second without `@Sendable` closures.
- **No explicit appearance override** — the `NSHostingView` inherits appearance from the status bar button, which automatically tracks light/dark theme.

### Menu Bar Label States

| State | Display |
|---|---|
| Running | `icon  Task Name  1h23m / 3h00m` (green elapsed, gray target) |
| Paused | `icon  Task Name  45m` (orange elapsed) |
| Idle | `icon` only |

Running and paused rows share the same `.frame(minWidth: 140)` to prevent the status bar from resizing on pause/resume — only the color changes (green ↔ orange). The idle state uses `variableLength` so the status item shrinks to just the icon.

---

## File Responsibility Guide

### `App/`

| File | Responsibility |
|---|---|
| `FocusStationApp.swift` | `@main` entry point. Creates `ModelContainer`, `TimerManager`, `TickGenerator`, `MenuBarController`. Renders a dummy `MenuBarExtra` (hidden) to satisfy the `App` protocol. |
| `ModelContainer+App.swift` | Static `ModelContainer.appContainer` factory. Schema: `Task`, `Day`, `ArchivedTask`. On-disk store. |
| `EnvironmentKeys.swift` | `@Entry var timerManager`. Defaults to `NoOpTimerManager`. Overridden via `.environment(\.timerManager, ...)`. |

### `Models/`

| File | Responsibility |
|---|---|
| `Task.swift` | `@Model` class. Properties: `name`, `iconName`, `isRunning`, `isCompleted`, `accumulatedElapsed`, `startedAt`, `targetTime`, `displayOrder`. `currentElapsed()` computed from timestamps. `displayState` derives `.running` / `.paused` / `.idle` / `.completed`. |
| `Day.swift` | `@Model` for archived daily snapshots + `ArchivedTask` frozen task state. Schema present for forward compatibility. |

### `Services/`

| File | Responsibility |
|---|---|
| `TimerManagerProtocol.swift` | 15-member `AnyObject` protocol. Contract for all timer mutations + task CRUD + reordering. |
| `TimerManager.swift` | `@Observable` implementation. Owns `tasks: [Task]`, `modelContext`, display timer, `refreshTasks()`. `start`/`pause`/`resume` enforce single-timer via `pauseOtherRunningTasks(except:)`. `reorderTasks(_:)` for batch drag-and-drop reordering. `deinit` invalidates display timer. |
| `TimerManager+SleepWake.swift` | `NSWorkspace` notification observers. On sleep: pause all running timers + invalidate display timer. On wake: restart display timer only (no auto-resume). |
| `TickGenerator.swift` | `@MainActor @Observable`. Runs a 1s selector-based `Timer` on `RunLoop.main.common`. `value` incremented each tick — observed by `MenuBarController` to trigger label re-renders. Selector-based to avoid `@Sendable` warnings in Swift 6. |
| `MenuBarController.swift` | `@MainActor` class. Creates `NSStatusItem` (variableLength), `NSHostingView` for label, `NSPopover` for dropdown. Click toggle, `withObservationTracking` tick loop. Popover width computed from `fittingSize`. No explicit appearance override. |

### `ViewModels/`

| File | Responsibility |
|---|---|
| `DropdownViewModel.swift` | `@Observable`. Syncs `tasks` from `timerManager` every 1s via selector-based sync timer. Exposes `sortedTasks` (running → paused → idle → completed by displayOrder). Handles all timer actions + CRUD passthrough + `reorderTasks(from:to:)`. `deinit` invalidates sync timer. |

### `Views/MenuBar/`

| File | Responsibility |
|---|---|
| `StatusBarLabelView.swift` | Renders menu bar label. Idle: brain icon only. Running: icon + name + elapsed / target. Paused: icon + name + elapsed. Uses `.foregroundStyle(.primary)` on icons and text for theme-agnostic rendering. Running/paused rows use `.frame(minWidth: 140)` to prevent resize on state change. |
| `MenuBarLabelView.swift` | Bridges `TickGenerator` + `timerManager` to `StatusBarLabelView` with `.id(tickGenerator.value)` for re-rendering. |
| `MenuBarContainerView.swift` | Concrete typed wrapper around `StatusBarLabelView`. Exists solely to avoid `AnyView` in `NSHostingView` (breaks `intrinsicContentSize`). |

### `Views/Dropdown/`

| File | Responsibility |
|---|---|
| `DropdownView.swift` | `NSPopover` content. Header ("FocusStation" + Quit button), scrollable task list with drag-to-reorder, inline pending task rows for batch creation, "Add Task" footer button. Contains `PendingTask` struct (name + hours + minutes) and `PendingTaskRowView` (inline form matching the edit-mode layout). Accent-colored separator between existing tasks and pending rows. |
| `TaskRowView.swift` | Single task row. Normal mode: completion checkbox, task name + elapsed/target time, action button (Start/Pause/Resume/Complete), hover-revealed pencil edit button, trash delete button. Edit mode: inline form identical to `PendingTaskRowView` — rounded-border name field + target h/m fields + checkmark save / x cancel buttons. Context menu for alternate actions. Double-clicking the name does nothing — use the pencil button or context menu "Rename". |
| `EmptyStateView.swift` | Static placeholder shown when no tasks and no pending rows exist. |

### `Utilities/`

| File | Responsibility |
|---|---|
| `TimeFormatter.swift` | `static func format(TimeInterval) -> String`. Returns `"1h30m"`, `"45m"`, `"30s"`, `"0m"`. Omits zero components — never shows `"1h0m"`. |
| `IconProvider.swift` | 32 SF Symbol names. `defaultIcon = "brain.head.profile"`. `label(for:)` for human-readable display. |

---

## Guardrails

These checks are enforced and must pass. Run locally before committing:

```bash
# Build must succeed
xcodebuild -project FocusStation.xcodeproj -scheme FocusStation -configuration Debug build

# No force unwraps (use guard let / if let)
grep -rn '!' FocusStation/ --include='*.swift' | grep -v '!=' | grep -v 'fatalError' || echo "PASS"

# No debug prints
grep -rn 'print(' FocusStation/ --include='*.swift' || echo "PASS"

# No counter-based timers (use timestamps)
grep -rn 'elapsed += 1' FocusStation/ --include='*.swift' || echo "PASS"

# No legacy property wrappers (use @Observable)
grep -rn '@Published\|ObservableObject\|@StateObject' FocusStation/ --include='*.swift' || echo "PASS"

# No hardcoded colors (use semantic: .primary, .secondary, .green, .orange, .accentColor)
grep -rn 'Color\.black\|Color\.white\|Color(red:\|Color(hex:' FocusStation/ --include='*.swift' || echo "PASS"

# No Combine (use @Observable + withObservationTracking)
grep -rn 'import Combine\|Combine\.' FocusStation/ --include='*.swift' || echo "PASS"

# No raw UserDefaults writes (use @AppStorage when needed)
grep -rn 'UserDefaults.standard.set\|UserDefaults.standard.removeObject' FocusStation/ --include='*.swift' || echo "PASS"
```

### Must Always

- `guard let` / `if let` — never force-unwrap
- `@Observable` only — never `@Published` / `ObservableObject` / `@StateObject`
- `currentElapsed()` = timestamp diff — never `elapsed += 1`
- Semantic colors only — `.primary`, `.secondary`, `.green`, `.orange`, `.accentColor`
- Imports sorted alphabetically: Foundation → SwiftData → SwiftUI → AppKit → Observation
- `///` doc comments on every public type, method, and property
- ViewModels import `Observation` (not `SwiftUI`)
- Views import `SwiftUI` (and `AppKit` only when needed)

---

## Troubleshooting

| Issue | Fix |
|---|---|
| **"Cannot be opened because the developer cannot be verified"** | Right-click the app → Open, or run `xattr -cr /Applications/FocusStation.app` in Terminal |
| **App doesn't appear in menu bar** | Ensure the app is in `/Applications`. If your menu bar is crowded, the icon may be hidden — try closing other menu bar items or use [Bartender](https://www.macbartender.com) |
| **Timers not counting** | Click ▶ on a task to start the timer. Only one timer runs at a time — starting another pauses the current one |
| **Tasks disappeared after restart** | Tasks persist via SwiftData — ensure the app quits normally (not force-quit) |

---

## Contributing

1. Fork the repo
2. Create a branch: `feature/your-feature` or `fix/your-bug`
3. Write code following the conventions above
4. Run all guardrail checks — they must pass
5. Submit a PR with a clear description

### Commit Style
```
area: short description in present tense

- Bullet points for what changed
- Reference issues if applicable
```

### Project Values
- **Zero dependencies.** Everything uses Apple frameworks only.
- **Local-only.** No networking. No analytics. No accounts.
- **Timestamp-based timer.** Never increment a counter.
- **Small surface area.** One responsibility per file. Clear ownership.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI (no AppKit views except NSStatusBar/NSPopover) |
| Persistence | SwiftData (on-disk, local only) |
| Concurrency | `@MainActor` + `@Observable` + `withObservationTracking` |
| Menu Bar | `NSStatusBar` + `NSHostingView` (not MenuBarExtra) |
| Build | Xcode 16, zero package dependencies |

---

## License

MIT — see [LICENSE](LICENSE) for details.
