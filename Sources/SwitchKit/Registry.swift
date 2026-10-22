import Foundation

/// Builds the list of switches and applies the user's order / hidden set.
public final class SwitchRegistry: @unchecked Sendable {
    public let keepAwake: KeepAwakeSwitch
    private let builtIns: [SwitchItem]
    private let store: UserDefaults

    static let orderKey = "switchOrder"
    static let hiddenKey = "hiddenSwitches"

    public init(runner: CommandRunner = ProcessRunner(), store: UserDefaults = .standard) {
        self.store = store
        keepAwake = KeepAwakeSwitch()
        builtIns = [
            DarkModeSwitch(runner: runner),
            keepAwake,
            NightShiftSwitch(),
            MuteSwitch(runner: runner),
            HideDesktopSwitch(runner: runner),
            HideDockSwitch(runner: runner),
            HiddenFilesSwitch(runner: runner),
            ScreenSaverAction(runner: runner),
            SleepDisplayAction(runner: runner),
            LockScreenAction(),
            EjectDisksAction(),
            EmptyTrashAction(runner: runner),
        ]
    }

    /// Every available switch (Bluetooth devices re-scanned each call), in the user's order.
    public func all(bluetooth: [SwitchItem] = BluetoothAudioSwitch.pairedAudio()) -> [SwitchItem] {
        let items = (builtIns + bluetooth).filter(\.isAvailable)
        return Self.ordered(items, by: order)
    }

    public func visible(bluetooth: [SwitchItem] = BluetoothAudioSwitch.pairedAudio()) -> [SwitchItem] {
        let hidden = self.hidden
        return all(bluetooth: bluetooth).filter { !hidden.contains($0.id) }
    }

    /// Known ids first in saved order; new ids keep their default position at the end.
    static func ordered(_ items: [SwitchItem], by order: [String]) -> [SwitchItem] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return items.enumerated().sorted { a, b in
            let ra = rank[a.element.id] ?? Int.max
            let rb = rank[b.element.id] ?? Int.max
            return ra != rb ? ra < rb : a.offset < b.offset
        }.map(\.element)
    }

    public var order: [String] {
        get { store.stringArray(forKey: Self.orderKey) ?? [] }
        set { store.set(newValue, forKey: Self.orderKey) }
    }

    public var hidden: Set<String> {
        get { Set(store.stringArray(forKey: Self.hiddenKey) ?? []) }
        set { store.set(Array(newValue).sorted(), forKey: Self.hiddenKey) }
    }

    public func setHidden(_ id: String, _ isHidden: Bool) {
        var h = hidden
        if isHidden { h.insert(id) } else { h.remove(id) }
        hidden = h
    }
}
