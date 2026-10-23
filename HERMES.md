# Switchboard

## What this is
A native macOS menu-bar app in the style of One Switch: one click toggles system switches
(Dark Mode, Keep Awake, Night Shift, Mute, Hide Desktop Icons, Auto-hide Dock, Hidden Files,
AirPods/headphones) and runs one-shot actions (Screen Saver, Sleep Display, Lock Screen,
Eject Disks, Empty Trash). For Melvern's own Mac; not distributed.

## Stack
- Swift 6 / SwiftPM, AppKit status item + SwiftUI popover. No dependencies.
- `SwitchKit` library holds every switch behind a `CommandRunner` protocol, so the logic is unit-tested with a fake.
- Private frameworks (CoreBrightness for Night Shift, login.framework for Lock) are dlopen'd at runtime, so a missing symbol hides the row instead of crashing.
- Ad-hoc codesigned .app via `scripts/build-app.sh`, with no Xcode project.
- **Rejected:** an Xcode project (noisy pbxproj, and SwiftPM builds fine), and Electron (100 MB for a menu).

## Commands
```bash
swift test                          # 22 unit tests (SwitchKit)
swift build                         # debug build
.build/debug/Switchboard --probe    # print every switch + live state, no UI
.build/debug/Switchboard --set <id> on|off   # e.g. --set nightShift on
.build/debug/Switchboard --run <id>          # e.g. --run ejectDisks
scripts/build-app.sh [--install]    # build/Switchboard.app; --install copies to /Applications and launches
swift scripts/make-icon.swift .     # regenerate Resources/AppIcon.icns
```
Switch ids: darkMode keepAwake nightShift mute hideDesktop hideDock hiddenFiles screenSaver
sleepDisplay lockScreen ejectDisks emptyTrash bt:<mac-address>

## Milestones — status and which model to use
Product scope, non-goals, and open questions live in `docs/prd.md`.

| # | Scope | Status | Model / effort |
|---|---|---|---|
| M1 | Menu-bar popover with 13 switches, settings (reorder/hide, launch at login), CLI | done | opus / high |
| M2 | Global hotkeys per switch + Shortcuts.app actions (App Intents) | next | opus / high |
| M3 | More switches: Do Not Disturb/Focus, True Tone, Low Power Mode, Wi-Fi/Bluetooth power, Clean Keyboard | todo | opus / high |
| M4 | Signed + notarized build (needs a paid Apple developer account) | blocked on account | opus / medium |

Default: strongest model + high effort.

**State the model and effort at the start of every milestone, before working.**

## Conventions
- Ask before adding a dependency.
- Every switch command comes from a fixed string in code, never assembled from external data.
- Toggle reads/writes block (`defaults`, `osascript`), so call them off the main thread (`BoardModel.work`).
- Never commit secrets.

## Gotchas
- `internal` is a keyword, so don't use it as a parameter name.
- Dark Mode, Dock and Empty Trash need Automation permission (System Events / Finder). A denial is mapped to a readable error (-1743).
- The NSHostingController needs `sizingOptions = .preferredContentSize`, or the popover opens at its old height and its top gets clipped off-screen.

## House rules
- Run `swift test` before and after a change, and report the real numbers.
- A diff that contradicts a sentence in a doc means that doc sentence is part of the diff.

## Keep Awake (One Switch style)
- Subtitle under the title while on: "Indefinitely" or a live "1h 29m left" (TimelineView, 1s tick).
- The timer menu checkmarks the chosen mode; the plain toggle turns on with the last chosen mode (`keepAwakeMode` in defaults, 0 = indefinitely).
- To check the UI, use `--snapshot`, not menu-bar clicking: the menu bar auto-hides behind fullscreen apps and blind clicks land in other apps. ImageRenderer draws AppKit controls (Toggle/Menu) as yellow placeholders. That's expected.

## Menu-bar icon
Custom template glyph in `Sources/Switchboard/StatusIcon.swift`: a solid rounded tile with a vertical switch slot, knob up. Melvern approved it. Don't swap it for an SF Symbol: `switch.2` looks like Control Center, and he rejected `switch.programmable`.
