# Switchboard

All the Mac's little switches in one menu-bar click, a self-built One Switch.

Toggling Dark Mode, keeping the Mac awake, hiding desktop icons before a screen recording,
or ejecting every disk before unplugging normally takes a trip into System Settings or the
terminal. Switchboard puts them all in a single popover.

## What's in it

| Switches (toggle) | Actions (one-shot) | Devices |
|---|---|---|
| Dark Mode · Keep Awake (Indefinitely or 15m–5h; shows the mode / live countdown under the title, toggle reuses your last pick) · Night Shift · Mute · Hide Desktop Icons · Auto-hide Dock · Show Hidden Files | Start Screen Saver · Sleep Display · Lock Screen · **Eject Disks** · Empty Trash (asks first) | Every paired Bluetooth audio device (AirPods, headphones): connect / disconnect |

Settings: drag to reorder, untick to hide, launch at login.

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

## Limits
- Uses private macOS APIs for Night Shift and Lock Screen. A future macOS can break them, and the row then hides itself.
- Dark Mode, Dock and Empty Trash ask for Automation permission the first time.
- Eject Disks skips any disk with an open file and tells you which one. It never touches the boot disk.
- The build is ad-hoc signed (personal use), not notarized.

## Getting started
```bash
git clone <this repo> && cd switchboard
swift test
scripts/build-app.sh --install
```

## Commands
| Command | What |
|---|---|
| `swift test` | unit tests |
| `.build/debug/Switchboard --probe` | list switches + live state |
| `.build/debug/Switchboard --set nightShift on` | flip a switch from the terminal / Shortcuts |
| `.build/debug/Switchboard --run ejectDisks` | run an action |
| `.build/debug/Switchboard --snapshot out.png [secs]` | render the panel (Keep Awake on) to a PNG |
| `scripts/build-app.sh --install` | build + install to /Applications |

## Roadmap
| | |
|---|---|
| M1 | Popover, 13 switches, settings, CLI ✅ |
| M2 | Global hotkeys + Shortcuts actions |
| M3 | Focus/DND, True Tone, Low Power, Wi-Fi/BT power, Clean Keyboard |
| M4 | Notarized build |

## Docs
- [`docs/prd.md`](docs/prd.md): scope, non-goals, open questions
- [`HERMES.md`](HERMES.md): working notes
