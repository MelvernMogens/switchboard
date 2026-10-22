import Foundation

public enum SwitchStyle: Equatable {
    case toggle
    case action
}

/// One row in the panel. Toggles report and set state; actions just run.
/// Subclasses override what applies. All calls may block — run them off the main thread.
open class SwitchItem: Identifiable, @unchecked Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let style: SwitchStyle
    /// Ask before running (destructive actions).
    public let confirm: String?

    public init(id: String, title: String, symbol: String, style: SwitchStyle, confirm: String? = nil) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.style = style
        self.confirm = confirm
    }

    /// Dynamic label (e.g. the AirPods' real name). Defaults to title.
    open var displayTitle: String { title }
    /// Small trailing text (e.g. "45m left"). nil = none.
    open var detail: String? { nil }
    /// false hides the row (e.g. no audio device paired, no Night Shift support).
    open var isAvailable: Bool { true }
    open func readState() -> Bool { false }
    open func setState(_ on: Bool) throws {}
    open func perform() throws {}
}
