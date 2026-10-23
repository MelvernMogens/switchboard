import AppKit
import SwiftUI
import SwitchKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var model: BoardModel!

    func applicationDidFinishLaunching(_ note: Notification) {
        MainActor.assumeIsolated {
            model = BoardModel()
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = statusItem.button {
                button.image = StatusIcon.make()
                button.action = #selector(togglePopover)
                button.target = self
            }
            popover.behavior = .transient
            popover.animates = false
            popover.delegate = self
            let host = NSHostingController(
                rootView: PanelView(model: model, openSettings: { [weak self] in self?.openSettings() }))
            host.sizingOptions = .preferredContentSize  // popover tracks SwiftUI height as rows change
            popover.contentViewController = host
            model.refresh()
        }
        if CommandLine.arguments.contains("--open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.togglePopover() }
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            MainActor.assumeIsolated { model.error = nil }
            // Show with the cached rows (instant), then refresh state underneath.
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            MainActor.assumeIsolated { model.refresh() }
        }
    }

    func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Switchboard Settings"
            w.isReleasedWhenClosed = false
            w.contentViewController = NSHostingController(rootView: SettingsView(model: MainActor.assumeIsolated { model }))
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

// `Switchboard --probe` prints every switch's availability + state, then exits (no UI).
if CommandLine.arguments.contains("--probe") {
    let reg = SwitchRegistry()
    let bt = BluetoothAudioSwitch.pairedAudio()
    for item in reg.all(bluetooth: bt) {
        let state = item.style == .toggle ? (item.readState() ? "on" : "off") : "action"
        print("\(item.id)\t\(item.displayTitle)\t\(state)")
    }
    exit(0)
}

// `Switchboard --set <id> on|off` / `--run <id>`: scriptable from Shortcuts or the terminal.
if let i = CommandLine.arguments.firstIndex(where: { $0 == "--set" || $0 == "--run" }),
   CommandLine.arguments.count > i + 1 {
    let args = CommandLine.arguments
    let id = args[i + 1]
    guard let item = SwitchRegistry().all().first(where: { $0.id == id }) else {
        FileHandle.standardError.write(Data("unknown switch: \(id)\n".utf8)); exit(2)
    }
    do {
        if args[i] == "--run" { try item.perform() } else { try item.setState(args.count > i + 2 && args[i + 2] == "on") }
        if item.style == .toggle { print(item.readState() ? "on" : "off") }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8)); exit(1)
    }
}

// `Switchboard --snapshot out.png [seconds]`: renders the panel with Keep Awake on
// (0 / omitted = indefinitely) to a PNG, for checking the UI without clicking the menu bar.
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
    MainActor.assumeIsolated {
        let args = CommandLine.arguments
        let secs = args.count > i + 2 ? TimeInterval(args[i + 2]) ?? 0 : 0
        let store = UserDefaults(suiteName: "switchboard.snapshot")!
        let model = BoardModel(registry: SwitchRegistry(store: store))
        try? model.registry.keepAwake.start(for: secs > 0 ? secs : nil)
        model.rows = model.registry.all(bluetooth: []).map {
            .init(item: $0, on: $0.style == .toggle ? $0.readState() : false, detail: $0.detail, title: $0.displayTitle)
        }
        let view = PanelView(model: model, openSettings: {})
            .padding(.vertical, 4).background(Color(white: 0.16)).environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: view)
        r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: args[i + 1]))
        }
        model.registry.keepAwake.stop()
        store.removePersistentDomain(forName: "switchboard.snapshot")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
