import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Universal Image Copy")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.statusText)
                Text(model.lastSuccessSummary)
                Text(model.automationSummary)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Divider()

            Toggle("Automatic Slides Copy", isOn: $model.automaticCopyEnabled)

            Button("Refresh Permissions") {
                model.refreshMonitoringPermissions()
            }

            Text("Manual hotkey: \(model.hotKeyDisplay)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}
