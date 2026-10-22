import SwiftUI
import SwitchKit

@MainActor
final class BoardModel: ObservableObject {
    struct Row: Identifiable {
        let item: SwitchItem
        var on: Bool
        var detail: String?
        var title: String
        var id: String { item.id }
    }

    @Published var rows: [Row] = []
    @Published var allItems: [SwitchItem] = []
    @Published var busy: Set<String> = []
    @Published var error: String?
    @Published var hidden: Set<String> = []

    let registry: SwitchRegistry
    private let work = DispatchQueue(label: "switchboard.work", qos: .userInitiated)

    init(registry: SwitchRegistry = SwitchRegistry()) {
        self.registry = registry
        hidden = registry.hidden
        registry.keepAwake.onExpire = { [weak self] in Task { @MainActor in self?.refresh() } }
    }

    /// Reads every switch's state off the main thread (defaults/osascript block).
    func refresh() {
        let registry = registry
        work.async {
            let all = registry.all()
            let hidden = registry.hidden
            let rows = all.filter { !hidden.contains($0.id) }.map {
                Row(item: $0, on: $0.style == .toggle ? $0.readState() : false,
                    detail: $0.detail, title: $0.displayTitle)
            }
            DispatchQueue.main.async {
                self.allItems = all
                self.hidden = hidden
                self.rows = rows
            }
        }
    }

    func activate(_ row: Row) {
        let item = row.item
        if let prompt = item.confirm, !confirm(prompt) { return }
        busy.insert(item.id)
        error = nil
        let target = !row.on
        work.async {
            var failure: String?
            do {
                if item.style == .toggle { try item.setState(target) } else { try item.perform() }
            } catch {
                failure = error.localizedDescription
            }
            DispatchQueue.main.async {
                self.busy.remove(item.id)
                self.error = failure
                self.refresh()
            }
        }
    }

    func keepAwake(for duration: TimeInterval?) {
        do { try registry.keepAwake.start(for: duration) } catch { self.error = error.localizedDescription }
        refresh()
    }

    func setHidden(_ id: String, _ isHidden: Bool) {
        registry.setHidden(id, isHidden)
        refresh()
    }

    func move(from: IndexSet, to: Int) {
        var ids = allItems.map(\.id)
        ids.move(fromOffsets: from, toOffset: to)
        registry.order = ids
        allItems.move(fromOffsets: from, toOffset: to)
        refresh()
    }

    private func confirm(_ text: String) -> Bool {
        let a = NSAlert()
        a.messageText = text
        a.addButton(withTitle: "Continue")
        a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return a.runModal() == .alertFirstButtonReturn
    }
}
