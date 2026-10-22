import Foundation

// Switches backed by `defaults`, AppleScript and stock CLI tools.

public final class DarkModeSwitch: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "darkMode", title: "Dark Mode", symbol: "moon.circle", style: .toggle)
    }
    public override func readState() -> Bool {
        let r = runner.run(Tool.defaults, ["read", "-g", "AppleInterfaceStyle"])
        return r.ok && r.output == "Dark"
    }
    public override func setState(_ on: Bool) throws {
        _ = try runner.appleScript(
            "tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
    }
}

public final class HideDockSwitch: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "hideDock", title: "Auto-hide Dock", symbol: "dock.rectangle", style: .toggle)
    }
    public override func readState() -> Bool {
        runner.defaultsBool("com.apple.dock", "autohide") ?? false
    }
    public override func setState(_ on: Bool) throws {
        _ = try runner.appleScript(
            "tell application \"System Events\" to tell dock preferences to set autohide to \(on)")
    }
}

public final class HideDesktopSwitch: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "hideDesktop", title: "Hide Desktop Icons", symbol: "eye.slash", style: .toggle)
    }
    /// On = icons hidden. Missing key means Finder shows them.
    public override func readState() -> Bool {
        runner.defaultsBool("com.apple.finder", "CreateDesktop") == false
    }
    public override func setState(_ on: Bool) throws {
        let w = runner.run(Tool.defaults, ["write", "com.apple.finder", "CreateDesktop", "-bool", on ? "false" : "true"])
        guard w.ok else { throw SwitchError.failed(w.output) }
        runner.run(Tool.killall, ["Finder"])
    }
}

public final class HiddenFilesSwitch: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "hiddenFiles", title: "Show Hidden Files", symbol: "doc.text.magnifyingglass", style: .toggle)
    }
    public override func readState() -> Bool {
        runner.defaultsBool("com.apple.finder", "AppleShowAllFiles") ?? false
    }
    public override func setState(_ on: Bool) throws {
        let w = runner.run(Tool.defaults, ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", on ? "true" : "false"])
        guard w.ok else { throw SwitchError.failed(w.output) }
        runner.run(Tool.killall, ["Finder"])
    }
}

public final class MuteSwitch: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "mute", title: "Mute", symbol: "speaker.slash", style: .toggle)
    }
    public override func readState() -> Bool {
        let r = runner.run(Tool.osascript, ["-e", "output muted of (get volume settings)"])
        return r.ok && r.output == "true"
    }
    public override func setState(_ on: Bool) throws {
        // Standard Additions — no Automation permission needed.
        let r = runner.run(Tool.osascript, ["-e", "set volume output muted \(on)"])
        guard r.ok else { throw SwitchError.failed(r.output) }
    }
}

public final class ScreenSaverAction: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "screenSaver", title: "Start Screen Saver", symbol: "tv", style: .action)
    }
    public override func perform() throws {
        let r = runner.run(Tool.open, ["-a", "ScreenSaverEngine"])
        guard r.ok else { throw SwitchError.failed(r.output) }
    }
}

public final class SleepDisplayAction: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "sleepDisplay", title: "Sleep Display", symbol: "moon.zzz", style: .action)
    }
    public override func perform() throws {
        let r = runner.run(Tool.pmset, ["displaysleepnow"])
        guard r.ok else { throw SwitchError.failed(r.output) }
    }
}

public final class EmptyTrashAction: SwitchItem, @unchecked Sendable {
    let runner: CommandRunner
    public init(runner: CommandRunner) {
        self.runner = runner
        super.init(id: "emptyTrash", title: "Empty Trash", symbol: "trash", style: .action,
                   confirm: "Empty the Trash? This can't be undone.")
    }
    public override func perform() throws {
        _ = try runner.appleScript("tell application \"Finder\" to empty trash", target: "Finder")
    }
}
