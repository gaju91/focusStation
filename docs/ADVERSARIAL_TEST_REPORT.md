# FocusStation Adversarial Test Report

Date: 23 July 2026
Result: PASS after fixes

## Scope

This campaign attacked the daily workspace, timer engine, SwiftData migration,
editor session ownership, task copying, ordering, CSV export, popover sizing,
and the real SwiftUI dropdown hierarchy. Seed records were isolated to the test
target and in-memory SwiftData containers; the user's persisted tasks were not
modified.

## Environment

- Apple silicon Mac, macOS 26.5.2
- Xcode SDK 26.5, Swift 6
- FocusStation deployment target macOS 14
- Debug configuration with fresh DerivedData directories

## Hostile Seed Matrix

- Empty and whitespace-only names
- 2,000-character emoji names, RTL text, and combining Unicode
- Commas, quotes, CR/LF, and spreadsheet-formula prefixes
- Negative, NaN, infinite, and extremely large durations
- Invalid dates, leap days, year boundaries, DST days, and half-hour time zones
- Legacy tasks without daily identity
- Impossible running/completed and future-running states
- Full-capacity days, oversized carry batches, and duplicate lineages
- Dense 40, 100, and 500-task datasets with mixed completion and target states

## Stress Evidence

- 66 distinct automated tests passed.
- The complete suite passed two consecutive clean-build iterations: 132/132 executions.
- 4,001 calendar offsets round-tripped per iteration without date drift.
- 1,000 deterministic randomized reorder operations per iteration preserved all
  100 task identities exactly once.
- 500 hostile CSV rows exported deterministically in forward and reversed input
  order.
- 100 repeated Save attempts produced exactly one task.
- 100 repeated navigation attempts could not escape an active editor session.
- The real DropdownView rendered at every 4-point height from 188 through 480.
- The real DropdownView survived 200 rapid create/cancel/date transitions while
  retaining its 340-point width.
- A production-shaped Xcode launch remained running with an empty debugger
  console after old output was cleared.

## Defects Found and Fixed

1. Extreme hour input could overflow integer multiplication and crash. Editor
   conversion now uses overflow-reporting arithmetic and becomes unsaveable.
2. NaN/infinite persisted elapsed values could poison timer display formatting.
   Model and formatter boundaries now sanitize non-finite values.
3. Invalid persisted day keys and non-finite targets were accepted by the timer
   service. Creation and updates now normalize them.
4. A legacy timer already spanning midnight could migrate to Today and continue
   illegally. Running legacy tasks now migrate to their start day and are capped
   at that day's local midnight.
5. CSV task names beginning with =, +, -, or @ could execute as spreadsheet
   formulas. User-controlled cells are now neutralized before CSV escaping.
6. Carry/repeat silently shortened a target when the destination lacked time,
   and a batch could be partially copied. Copies now reject insufficient
   capacity, batches preflight atomically, and duplicate lineages are ignored.
7. The one-task header said “1 tasks.” Singular/plural grammar is now correct.
8. A stale unused binding produced a compiler warning. It was removed.
9. macOS sleep paused active work despite timestamp-based elapsed tracking, and
   elapsed colors differed between surfaces. Sleep now preserves the running
   session, wake still enforces midnight, and one shared rule renders green
   within limit, orange when paused, and red when overdue.

## Guardrails and Limitations

The final guardrail scan, diff whitespace check, clean Debug build, and full test
suite pass. No temporary Dock-app, seed-data, popover-opening, or QA-window hooks
remain in production code.

The macOS automation bridge could list the debug process but could not attach to
the accessibility tree of the status-bar extra, even when the same view was
temporarily hosted in a normal QA window. Consequently, menu-bar click targeting
was not automatable in this environment. Its shared DropdownView was exercised
through NSHostingView layout stress, and the final Xcode runtime console was
clean; direct human pointer/VoiceOver validation remains the only uncovered
interaction layer.
