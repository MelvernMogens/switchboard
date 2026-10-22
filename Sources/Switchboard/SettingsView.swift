import ServiceManagement
import SwiftUI
import SwitchKit

struct SettingsView: View {
    @ObservedObject var model: BoardModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drag to reorder. Untick to hide from the menu.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            List {
                ForEach(model.allItems, id: \.id) { item in
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(
                            get: { !model.hidden.contains(item.id) },
                            set: { model.setHidden(item.id, !$0) }
                        )).labelsHidden()
                        Image(systemName: item.symbol).frame(width: 18).foregroundStyle(.secondary)
                        Text(item.displayTitle)
                        Spacer()
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                    }
                }
                .onMove { model.move(from: $0, to: $1) }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError {
                Text(loginError).font(.system(size: 11)).foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(width: 340, height: 460)
        .onAppear { model.refresh() }
    }
}
