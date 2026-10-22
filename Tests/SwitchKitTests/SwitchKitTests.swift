import XCTest
@testable import SwitchKit

final class FakeRunner: CommandRunner {
    var calls: [[String]] = []
    var responses: [String: CommandResult] = [:]  // keyed by joined args

    func run(_ tool: String, _ args: [String]) -> CommandResult {
        calls.append([tool] + args)
        return responses[args.joined(separator: " ")] ?? CommandResult(status: 0, output: "")
    }
}

final class ShellSwitchTests: XCTestCase {
    func testDarkModeReadsGlobalStyle() {
        let r = FakeRunner()
        r.responses["read -g AppleInterfaceStyle"] = CommandResult(status: 0, output: "Dark")
        XCTAssertTrue(DarkModeSwitch(runner: r).readState())
        r.responses["read -g AppleInterfaceStyle"] = CommandResult(status: 1, output: "does not exist")
        XCTAssertFalse(DarkModeSwitch(runner: r).readState())
    }

    func testDarkModeSetUsesSystemEvents() throws {
        let r = FakeRunner()
        try DarkModeSwitch(runner: r).setState(true)
        XCTAssertEqual(r.calls.last?[0], Tool.osascript)
        XCTAssertTrue(r.calls.last![2].contains("set dark mode to true"))
    }

    func testAutomationDeniedIsReadable() {
        let r = FakeRunner()
        r.responses.values.forEach { _ in }
        let src = "tell application \"System Events\" to tell appearance preferences to set dark mode to false"
        r.responses["-e \(src)"] = CommandResult(status: 1, output: "execution error: Not authorized to send Apple events to System Events. (-1743)")
        XCTAssertThrowsError(try DarkModeSwitch(runner: r).setState(false)) { err in
            XCTAssertEqual(err as? SwitchError, .automationDenied(app: "System Events"))
            XCTAssertTrue(err.localizedDescription.contains("Automation"))
        }
    }

    func testHideDesktopInvertsCreateDesktopAndRestartsFinder() throws {
        let r = FakeRunner()
        let s = HideDesktopSwitch(runner: r)
        XCTAssertFalse(s.readState(), "missing key = icons shown")
        r.responses["read com.apple.finder CreateDesktop"] = CommandResult(status: 0, output: "0")
        XCTAssertTrue(s.readState())
        r.calls = []
        try s.setState(true)
        XCTAssertEqual(r.calls[0], [Tool.defaults, "write", "com.apple.finder", "CreateDesktop", "-bool", "false"])
        XCTAssertEqual(r.calls[1], [Tool.killall, "Finder"])
    }

    func testHiddenFilesWritesBool() throws {
        let r = FakeRunner()
        try HiddenFilesSwitch(runner: r).setState(true)
        XCTAssertEqual(r.calls[0], [Tool.defaults, "write", "com.apple.finder", "AppleShowAllFiles", "-bool", "true"])
    }

    func testDockReadsAutohide() {
        let r = FakeRunner()
        r.responses["read com.apple.dock autohide"] = CommandResult(status: 0, output: "1")
        XCTAssertTrue(HideDockSwitch(runner: r).readState())
    }

    func testFailedWriteThrows() {
        let r = FakeRunner()
        r.responses["write com.apple.finder AppleShowAllFiles -bool true"] = CommandResult(status: 1, output: "boom")
        XCTAssertThrowsError(try HiddenFilesSwitch(runner: r).setState(true))
        XCTAssertFalse(r.calls.contains([Tool.killall, "Finder"]), "don't restart Finder after a failed write")
    }

    func testMute() throws {
        let r = FakeRunner()
        r.responses["-e output muted of (get volume settings)"] = CommandResult(status: 0, output: "true")
        let m = MuteSwitch(runner: r)
        XCTAssertTrue(m.readState())
        try m.setState(false)
        XCTAssertEqual(r.calls.last, [Tool.osascript, "-e", "set volume output muted false"])
    }

    func testEmptyTrashNeedsConfirmation() {
        XCTAssertNotNil(EmptyTrashAction(runner: FakeRunner()).confirm)
    }
}

final class KeepAwakeTests: XCTestCase {
    func testAssertionLifecycle() throws {
        let k = KeepAwakeSwitch()
        XCTAssertFalse(k.readState())
        try k.start(for: 3600)
        XCTAssertTrue(k.readState())
        XCTAssertEqual(k.detail, "1h 0m")
        k.stop()
        XCTAssertFalse(k.readState())
        XCTAssertNil(k.detail)
    }

    func testFormat() {
        XCTAssertEqual(KeepAwakeSwitch.format(remaining: 899), "15m")
        XCTAssertEqual(KeepAwakeSwitch.format(remaining: 5400), "1h 30m")
        XCTAssertEqual(KeepAwakeSwitch.format(remaining: -5), "0m")
    }
}

final class RegistryTests: XCTestCase {
    private func store() -> UserDefaults {
        let name = "switchboard.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func item(_ id: String) -> SwitchItem { SwitchItem(id: id, title: id, symbol: "x", style: .action) }

    func testOrderingKeepsUnknownsAtEndInDefaultOrder() {
        let items = ["a", "b", "c", "d"].map(item)
        let out = SwitchRegistry.ordered(items, by: ["c", "a", "zz"]).map(\.id)
        XCTAssertEqual(out, ["c", "a", "b", "d"])
    }

    func testDuplicateIdsInSavedOrderDontCrash() {
        let out = SwitchRegistry.ordered(["a", "b"].map(item), by: ["b", "b", "a"]).map(\.id)
        XCTAssertEqual(out, ["b", "a"])
    }

    func testHiddenAndOrderPersist() {
        let s = store()
        let reg = SwitchRegistry(runner: FakeRunner(), store: s)
        reg.setHidden("mute", true)
        reg.order = ["lockScreen", "darkMode"]
        let ids = reg.visible(bluetooth: []).map(\.id)
        XCTAssertFalse(ids.contains("mute"))
        let reg2 = SwitchRegistry(runner: FakeRunner(), store: s)
        XCTAssertEqual(reg2.hidden, ["mute"])
        let all = reg2.all(bluetooth: []).map(\.id)
        if all.contains("lockScreen") { XCTAssertEqual(all.first, "lockScreen") }
        XCTAssertTrue(all.contains("darkMode"))
        XCTAssertTrue(all.contains("mute"), "hidden items still listed in settings")
    }

    func testBluetoothAudioClass() {
        // Headphones: major class 0x04 in bits 8-12.
        XCTAssertTrue(BluetoothAudioSwitch.isAudio(classOfDevice: 0x240418))
        // Keyboard (peripheral 0x05).
        XCTAssertFalse(BluetoothAudioSwitch.isAudio(classOfDevice: 0x002540))
    }
}

final class EjectDisksTests: XCTestCase {
    func testRuleNeverTouchesBootDisk() {
        XCTAssertFalse(EjectDisksAction.isEjectable(path: "/", ejectable: false, removable: false, local: true, isInternal: true, root: true))
        XCTAssertFalse(EjectDisksAction.isEjectable(path: "/System/Volumes/Data", ejectable: false, removable: false, local: true, isInternal: true, root: false))
        XCTAssertFalse(EjectDisksAction.isEjectable(path: "/Volumes/Macintosh HD", ejectable: false, removable: false, local: true, isInternal: true, root: false))
    }

    func testRuleCatchesUsbDmgNetworkAndExternalSsd() {
        XCTAssertTrue(EjectDisksAction.isEjectable(path: "/Volumes/USB", ejectable: true, removable: true, local: true, isInternal: false, root: false))
        XCTAssertTrue(EjectDisksAction.isEjectable(path: "/Volumes/Installer", ejectable: true, removable: false, local: true, isInternal: true, root: false))
        XCTAssertTrue(EjectDisksAction.isEjectable(path: "/Volumes/share", ejectable: false, removable: false, local: false, isInternal: nil, root: false))
        XCTAssertTrue(EjectDisksAction.isEjectable(path: "/Volumes/T7", ejectable: false, removable: false, local: true, isInternal: false, root: false))
    }

    func testEjectsAllAndReportsStuckOnes() {
        let vols = ["A", "B", "C"].map { EjectableVolume(url: URL(fileURLWithPath: "/Volumes/\($0)"), name: $0) }
        var ejected: [String] = []
        let a = EjectDisksAction(list: { vols }, eject: { url in
            if url.lastPathComponent == "B" { throw NSError(domain: "busy", code: 16) }
            ejected.append(url.lastPathComponent)
        })
        XCTAssertEqual(a.detail, "3")
        XCTAssertThrowsError(try a.perform()) { XCTAssertTrue($0.localizedDescription.contains("B")) }
        XCTAssertEqual(ejected, ["A", "C"], "one busy disk must not stop the others")
    }

    func testNothingToEject() {
        let a = EjectDisksAction(list: { [] }, eject: { _ in XCTFail("nothing to eject") })
        XCTAssertNil(a.detail)
        XCTAssertThrowsError(try a.perform())
    }
}
