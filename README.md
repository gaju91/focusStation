# FocusStation

**A native, day-specific macOS menu bar task timer for planning realistic work and staying focused.**

FocusStation lives entirely in the Mac menu bar. Plan tasks on a calendar day, give them optional time budgets, work on one task at a time, review previous days, deliberately carry unfinished work forward, and export the history as CSV.

No account. No cloud. No analytics. No networking. No third-party dependencies.

<!--
Upload docs/focusStation_Walkthrough.mp4 through GitHub's Markdown editor,
then paste the generated playable video attachment directly below this comment.
-->

_Complete walkthrough: create, edit, time, complete, delete, review, export, carry, plan ahead, and reorder tasks._



https://github.com/user-attachments/assets/b700279c-8f47-4ae6-a9ca-c301f86500f2



[![Project status](https://img.shields.io/badge/status-complete-2ea44f)](#project-status)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/Persistence-SwiftData-green)](https://developer.apple.com/xcode/swiftdata/)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-silver)](https://developer.apple.com/macos/)
[![Tests](https://img.shields.io/badge/tests-65%20passing-2ea44f)](#test-and-verify)
[![License](https://img.shields.io/badge/license-MIT-purple)](LICENSE)

## Project status

**FocusStation is feature-complete for its intended scope.**

The product is not trying to become a project manager, calendar, team tracker, billing system, or Pomodoro suite. Its finished job is narrower: help one person plan a realistic day, see the current focus in the menu bar, preserve an accurate history, and make unfinished work an explicit decision.

Maintenance, compatibility fixes, security fixes, and small usability improvements may continue. New feature work should protect the one-second, menu-bar-first workflow.

## Install

The downloadable v1.0.0 build supports Apple Silicon Macs running macOS 14 Sonoma or later.

1. Download the latest ZIP from [GitHub Releases](https://github.com/gaju91/focusStation/releases/latest).
2. Unzip it and move `FocusStation.app` to `/Applications`.
3. On first launch, right-click the app and choose **Open**. If Gatekeeper still blocks it, run:

```bash
xattr -cr /Applications/FocusStation.app
```

4. Open FocusStation and look for the brain icon in the menu bar.

## What the completed app does

### Daily workspaces

- The header is a compact date carousel.
- **Today** supports the complete workflow: create, edit, reorder, time, complete, delete, carry, and repeat.
- **Future dates** support planning and reordering, but timers and completion remain disabled until that date arrives.
- **Past dates** are read-only history.
- Targets are limited by the actual remaining capacity of the selected local calendar day.
- Calendar arithmetic respects time zones, leap days, and 23/24/25-hour daylight-saving days.

### Focus timer

- Only one task can run at a time; starting or resuming another task automatically pauses the current one.
- Elapsed time is derived from timestamps, never from an incrementing counter.
- A running task is capped at the end of its scheduled local day.
- FocusStation pauses running work before the Mac sleeps and when the app quits, preventing accidental sleep time from being recorded.
- Completion preserves elapsed time and keeps the task in its current list position with a green check and strikethrough.

### Menu bar

- Idle state is the brain icon only.
- Running or paused state shows the task icon, a tail-truncated name, elapsed time, and an optional target.
- Elapsed time is orange while within the target and red when overdue.
- The full task, state, and time remain available through the native tooltip.
- The status item is capped at 260 pt and the popover anchor follows the center of its current width.

### Compact popover

- Stable width: 340 pt.
- Content-driven height: 188–480 pt.
- Rows keep fixed control columns, so hover actions never shift the task text.
- Long names use up to two lines before tail truncation and expose the full name as help text.
- Edit and delete controls appear on hover and are also available through the context menu.
- All primary controls have 28×28 pt hit regions, accessibility labels, and native help text.
- Large lists scroll without a permanently visible scrollbar.

### Inline create and edit

- New and existing tasks use the same 76 pt inline editor.
- The name field receives focus immediately and shows a visible focus ring.
- Optional hour/minute controls set the target.
- `Return` saves, `Escape` cancels, and `⌘N` creates a new task.
- A save is atomic and closes the editor on the first interaction; stale field callbacks cannot restore or duplicate it.

### Carry, repeat, and history

- Unfinished work never resets or silently moves at midnight.
- **Carry** creates a task on the next applicable day with zero elapsed time and only the remaining target estimate.
- **Repeat** creates fresh work with the original full target.
- Lineage tracking prevents duplicate copies from repeated carry/repeat actions.
- Batch carry preflights destination capacity and is atomic: either every eligible task is copied or none are.
- The export menu writes either the selected day or all history through the native macOS save panel.
- CSV output is deterministic, RFC-style escaped, and neutralizes spreadsheet-formula prefixes.

## Keyboard and pointer reference

| Action | Control |
|---|---|
| Open FocusStation | Click the menu-bar item |
| New task | `⌘N` or **New Task** |
| Save editor | `Return` or **Save** |
| Cancel editor | `Escape` or **Cancel** |
| Edit or delete | Hover the task row |
| Carry or repeat one task | Right-click the task row |
| Reorder | Drag the row |
| Change date | Header arrows or horizontal swipe |
| Return to Today | Click an off-date title |
| Export history | Header export icon |
| Quit | Header `×` button |

## Architecture

```text
SwiftUI views
    ↓
DropdownViewModel (@Observable)
    ↓ protocol dependency
TimerManager
    ↓
SwiftData (local on-disk store)

TickGenerator ──→ MenuBarController ──→ NSStatusItem + NSPopover
```

- **Views** render state and forward user intent. They do not access SwiftData.
- **DropdownViewModel** owns the selected day, inline editor state, grouping, capacity validation, carry/repeat orchestration, and export preparation.
- **TimerManager** is the mutation boundary for timers, CRUD, ordering, sleep handling, legacy migration, and day-boundary reconciliation.
- **MenuBarController** owns one native status item, one native popover, one shared dropdown view model, label updates, popover anchoring, and coalesced content-size changes.
- **Task** stores durable timer and daily-workspace state. `currentElapsed(at:)` derives live elapsed time from timestamps.
- **LocalDay** provides stable local-calendar keys and DST-safe day arithmetic.

The app uses Swift 6, SwiftUI, SwiftData, Observation, and the small amount of AppKit required for `NSStatusItem`, `NSPopover`, sleep/wake notifications, and the native save panel.

## Project structure

```text
FocusStation/
├── App/
│   ├── FocusStationApp.swift
│   └── ModelContainer+App.swift
├── Models/
│   ├── Task.swift
│   └── Day.swift
├── Services/
│   ├── MenuBarController.swift
│   ├── TickGenerator.swift
│   ├── TimerManager.swift
│   ├── TimerManager+SleepWake.swift
│   └── TimerManagerProtocol.swift
├── Utilities/
│   ├── DailyWorkspace.swift
│   ├── IconProvider.swift
│   └── TimeFormatter.swift
├── ViewModels/
│   └── DropdownViewModel.swift
├── Views/
│   ├── Dropdown/
│   │   ├── DropdownView.swift
│   │   ├── EmptyStateView.swift
│   │   └── TaskRowView.swift
│   └── MenuBar/
│       ├── MenuBarContainerView.swift
│       └── StatusBarLabelView.swift
└── Resources/
    ├── Assets.xcassets/
    └── Info.plist

FocusStationTests/
└── FocusStationTests.swift
```

The production target contains 18 Swift files, `Info.plist`, and the complete macOS app-icon asset catalog. The test target contains 65 tests covering the model, timer service, view model, layout calculations, status-bar content, CSV export, day boundaries, and adversarial rendering/state scenarios.

## Development

### Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later
- No package manager or third-party dependency installation

### Build

```bash
xcodebuild \
  -project FocusStation.xcodeproj \
  -scheme FocusStation \
  -configuration Debug \
  -derivedDataPath /tmp/FocusStationDerivedData \
  clean build
```

### Test and verify

```bash
xcodebuild test \
  -project FocusStation.xcodeproj \
  -scheme FocusStation \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/FocusStationTests

rg -n '@Published|ObservableObject|@StateObject' FocusStation -g '*.swift'
rg -n 'elapsed \+= 1' FocusStation -g '*.swift'
rg -n 'print\(' FocusStation -g '*.swift'
rg -n 'Color\.black|Color\.white|Color\(red:|Color\(hex:' FocusStation -g '*.swift'
rg -n 'import Combine|Combine\.' FocusStation -g '*.swift'
rg -n 'URLSession|https?://' FocusStation -g '*.swift'
rg -n '[A-Za-z0-9_\)\]]!(?![=])' FocusStation -g '*.swift' -P
```

Every search should return no matches. The final verified suite executes 65 tests with zero failures.

## Release packaging

```bash
xcodebuild \
  -project FocusStation.xcodeproj \
  -scheme FocusStation \
  -configuration Release \
  CONFIGURATION_BUILD_DIR=build/Release \
  build

ditto -c -k --keepParent \
  build/Release/FocusStation.app \
  build/Release/FocusStation-vX.Y.Z.zip
```

FocusStation is currently distributed with an ad-hoc signature and is not Apple-notarized. Preserve the Gatekeeper note in release instructions until Developer ID signing and notarization are configured.

## Product boundaries

FocusStation intentionally does not include:

- accounts or cloud sync;
- networking or analytics;
- collaboration or team reporting;
- project hierarchies, Kanban, or calendar integration;
- billing and timesheets;
- AI features;
- custom themes or third-party plugins.

These are product constraints, not missing checklist items.

## Documentation

- [Complete user guide](https://gajanand.info/tools/focusstation/guide)
- [Product page and download](https://gajanand.info/tools/focusstation)
- [Build-in-public series](https://gajanand.info/build)
- [Adversarial test report](docs/ADVERSARIAL_TEST_REPORT.md)

## License

MIT — see [LICENSE](LICENSE).
