# Switchboard PRD

## 1. Problem
Common Mac toggles are scattered across System Settings, Control Center and terminal
`defaults` commands. One Switch solves this but is paid. Switchboard is a personal clone.

## 2. User
Melvern, on his own Mac. Wants it minimal: small rows and no notifications for routine actions.

## 3. Parts inventory
Status item + popover · switch catalogue (SwitchKit) · settings (order/hide/login item) ·
CLI (`--probe/--set/--run`) · app bundle + icon · permissions (Automation, Bluetooth).

## 4. Scope (M1, done)
13 built-in switches plus one row per paired Bluetooth audio device. Errors show inline in the
popover, and destructive actions (Empty Trash) confirm first.

## 5. Non-goals
App Store distribution · syncing settings · a Windows/Linux port.

## 6. What not to oversell
Safe to say: "Toggles these Mac settings in one click on current macOS."
Not safe to say: "Will keep working on every future macOS." Night Shift and Lock Screen use
private APIs and can break on an OS update. The row then hides itself instead of crashing.

## 7. Milestones
See CLAUDE.md table: M2 hotkeys + Shortcuts, M3 more switches, M4 notarization.

## 8. Backlog
Per-switch hotkeys · Focus modes · True Tone · Low Power Mode · Wi-Fi/Bluetooth power ·
Clean Keyboard (lock input 60 s) · Hide notch / black wallpaper · Display resolution presets ·
Caffeinate while an app is running.

## 9. Open questions
- Notarization needs a paid Apple developer account ($99/yr). Is it worth it for personal use?
- Focus/DND has no public write API. Shortcuts.app bridging is the likely route.
