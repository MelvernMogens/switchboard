import SwiftUI
import SwitchKit

struct PanelView: View {
    @ObservedObject var model: BoardModel
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Switchboard").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: openSettings) { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless).help("Settings")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .buttonStyle(.borderless).help("Quit Switchboard")
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(sections.enumerated()), id: \.offset) { idx, section in
                    if idx > 0 { Divider().padding(.horizontal, 8).padding(.vertical, 4) }
                    ForEach(section) { row in
                        SwitchRow(row: row, busy: model.busy.contains(row.id), model: model)
                    }
                }
            }
            .padding(.horizontal, 6)

            if let error = model.error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.top, 6)
            }
            Spacer(minLength: 8)
        }
        .frame(width: 280)
    }
}

extension PanelView {
    /// Switches, then one-shot actions, then Bluetooth devices; user order kept inside each.
    var sections: [[BoardModel.Row]] {
        let devices = model.rows.filter { $0.item is BluetoothAudioSwitch }
        let toggles = model.rows.filter { $0.item.style == .toggle && !($0.item is BluetoothAudioSwitch) }
        let actions = model.rows.filter { $0.item.style == .action }
        return [toggles, actions, devices].filter { !$0.isEmpty }
    }
}

struct SwitchRow: View {
    let row: BoardModel.Row
    let busy: Bool
    @ObservedObject var model: BoardModel
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: row.item.symbol)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundStyle(row.on ? Color.accentColor : .secondary)
            if let awake = row.item as? KeepAwakeSwitch {
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.title).font(.system(size: 13)).lineLimit(1)
                    if row.on {
                        // Ticks every second so the countdown is live while the popover is open.
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Text(awake.status(at: ctx.date) ?? "")
                                .font(.system(size: 10.5).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 4)
                Menu {
                    ForEach(KeepAwakeSwitch.durations, id: \.0) { label, secs in
                        Toggle(label, isOn: Binding(
                            get: { awake.mode == secs },
                            set: { _ in model.keepAwake(for: secs) }))
                    }
                    if row.on {
                        Divider()
                        Button("Turn Off") { model.activate(row) }
                    }
                } label: { Image(systemName: "timer") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Keep awake for…")
            } else {
                Text(row.title).font(.system(size: 13)).lineLimit(1)
                Spacer(minLength: 4)
                if let detail = row.detail {
                    Text(detail).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            trailing
        }
        .padding(.horizontal, 8).frame(minHeight: 27).padding(.vertical, row.on && row.item is KeepAwakeSwitch ? 2 : 0)
        .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.07) : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { if !busy { model.activate(row) } }
    }

    @ViewBuilder private var trailing: some View {
        if busy {
            ProgressView().controlSize(.mini).frame(width: 26)
        } else if row.item.style == .toggle {
            Toggle("", isOn: Binding(get: { row.on }, set: { _ in model.activate(row) }))
                .toggleStyle(.switch).controlSize(.mini).labelsHidden()
        } else {
            Image(systemName: "return").font(.system(size: 10))
                .foregroundStyle(.tertiary).opacity(hover ? 1 : 0).frame(width: 26)
        }
    }
}
