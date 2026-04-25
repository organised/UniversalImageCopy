import SwiftUI
import AppKit

@main
struct UniversalImageCopyApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            Label("Universal Image Copy", systemImage: model.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}
