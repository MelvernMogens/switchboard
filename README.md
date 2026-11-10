# Switchboard

**All your Mac's little switches in one menu-bar click — a self-built One Switch.**

Toggling Dark Mode, keeping the Mac awake, hiding desktop icons before a screen recording, or ejecting every disk before unplugging normally means a trip into System Settings or the terminal. Switchboard puts them all in one popover.

## Features

| Switches (toggle) | Actions (one-shot) | Devices |
|---|---|---|
| Dark Mode · Keep Awake · Night Shift · Mute · Hide Desktop Icons · Auto-hide Dock · Show Hidden Files | Start Screen Saver · Sleep Display · Lock Screen · **Eject Disks** · Empty Trash (asks first) | Every paired Bluetooth audio device (AirPods, headphones): connect / disconnect |

- **Keep Awake**: Indefinitely or 15m–5h. Shows the mode or a live countdown under the title; the plain toggle reuses your last pick.
- **Eject Disks**: skips any disk with an open file and tells you which one. Never touches the boot disk.
- **Settings**: drag to reorder, untick to hide, launch at login.
- **CLI**: every switch can be read or flipped from the terminal or Shortcuts (see below).

## Requirements

- macOS 13 or later
- Swift 5.9+ (Xcode or the Command Line Tools: `xcode-select --install`)

## Install

```bash
git clone https://github.com/MelvernMogens/switchboard.git && cd switchboard
swift test
scripts/build-app.sh --install
```

`scripts/build-app.sh` does a release build, wraps it in `build/Switchboard.app`, ad-hoc signs it, and with `--install` copies it to `/Applications` and launches it. Without `--install` it only builds `build/Switchboard.app`.

The first time you use Dark Mode, Auto-hide Dock or Empty Trash, macOS asks for Automation permission. Allow it once.

## Commands

| Command | What |
|---|---|
| `swift test` | Unit tests (SwitchKit) |
| `swift build` | Debug build |
| `.build/debug/Switchboard --probe` | List every switch + live state, no UI |
| `.build/debug/Switchboard --set nightShift on` | Flip a switch from the terminal / Shortcuts |
| `.build/debug/Switchboard --run ejectDisks` | Run an action |
| `.build/debug/Switchboard --snapshot out.png [secs]` | Render the panel to a PNG |
| `scripts/build-app.sh --install` | Build + install to /Applications |
| `swift scripts/make-icon.swift .` | Regenerate `Resources/AppIcon.icns` |

Switch ids: `darkMode` `keepAwake` `nightShift` `mute` `hideDesktop` `hideDock` `hiddenFiles` `screenSaver` `sleepDisplay` `lockScreen` `ejectDisks` `emptyTrash` `bt:<device-address>`

## How it works

```
menu-bar icon ─▶ SwiftUI popover ─▶ BoardModel (background queue)
                                        │
                                        ▼
                               SwitchKit.SwitchItem
          ┌──────────────┬──────────────┼──────────────┬──────────────┐
      defaults+killall  osascript    IOKit power   CoreBrightness   IOBluetooth /
      (Finder/Dock)     (System      assertion     (Night Shift,    NSWorkspace
                         Events)     (Keep Awake)   private)        (Eject)
```

- Swift / SwiftPM, AppKit status item + SwiftUI popover, no dependencies, no Xcode project.
- `SwitchKit` holds every switch behind a `CommandRunner` protocol, so the logic is unit-tested with a fake.
- Private frameworks are loaded at runtime; if a symbol is missing, that row hides itself instead of crashing.

## Project structure

```
Sources/SwitchKit/     switch definitions (native, shell, eject, registry)
Sources/Switchboard/   app: menu-bar icon, popover, settings, CLI entry
Tests/SwitchKitTests/  unit tests
scripts/               build-app.sh, make-icon.swift
docs/                  prd.md, security.md
```

## Limits

- Night Shift and Lock Screen use private macOS APIs. A future macOS can break them; the row then hides itself.
- Ad-hoc signed for personal use, not notarized.

## Roadmap

| | |
|---|---|
| M1 | Popover, 13 switches, settings, CLI ✅ |
| M2 | Global hotkeys + Shortcuts actions |
| M3 | Focus/DND, True Tone, Low Power, Wi-Fi/BT power, Clean Keyboard |
| M4 | Notarized build |

Docs: [`docs/prd.md`](docs/prd.md) (scope, non-goals), [`docs/security.md`](docs/security.md), [`HERMES.md`](HERMES.md) (working notes).

Built by [Melvern Mogens](https://github.com/MelvernMogens).
