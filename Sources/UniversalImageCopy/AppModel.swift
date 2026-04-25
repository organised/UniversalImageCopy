import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var automaticCopyEnabled: Bool = true
    @Published var hasInputMonitoringAccess: Bool = false
    @Published var statusText: String = "Starting app-only Google Slides monitor..."
    @Published var copyAttempt = CopyAttemptState()

    private let browserContextDetector = BrowserContextDetector()
    private let copyCommandMonitor = CopyCommandMonitor()
    private var automaticCopyTask: Task<Void, Never>?
    private lazy var hotKeyManager = GlobalHotKeyManager { [weak self] in
        Task { @MainActor in
            await self?.performCopy(trigger: "Hotkey", allowManualFallback: true)
        }
    }

    init() {
        copyCommandMonitor.onAccessChanged = { [weak self] hasAccess in
            Task { @MainActor in
                self?.hasInputMonitoringAccess = hasAccess
                self?.refreshStatusText()
            }
        }
        copyCommandMonitor.onCopyCommand = { [weak self] in
            Task { @MainActor in
                await self?.handleGlobalCopyCommand()
            }
        }

        hasInputMonitoringAccess = copyCommandMonitor.hasListenAccess
        copyCommandMonitor.start()
        hotKeyManager.start()
        refreshStatusText()
    }

    var lastSuccessSummary: String {
        if let path = copyAttempt.succeededPath {
            return "Last success: \(path.rawValue)"
        }
        return "No successful copy yet"
    }

    var hotKeyDisplay: String {
        GlobalHotKeyManager.Shortcut.default.displayString
    }

    var menuBarSymbolName: String {
        switch copyAttempt.status {
        case .idle:
            return automaticCopyEnabled ? "doc.on.clipboard" : "pause.circle"
        case .running:
            return "hourglass"
        case .succeeded:
            return "photo.on.rectangle.angled"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var automationSummary: String {
        if automaticCopyEnabled {
            return "Automatic Google Slides copy conversion is on."
        }
        return "Automatic Google Slides copy conversion is off."
    }

    func performCopy(trigger: String, allowManualFallback: Bool = true) async {
        guard copyAttempt.status != .running else {
            copyAttempt.log("Skipped \(trigger.lowercased()) because a copy pipeline is already running")
            return
        }

        copyAttempt.reset(detail: "\(trigger) copy running")
        copyAttempt.log("Starting copy pipeline from \(trigger)")

        do {
            copyAttempt.activePath = .clipboardHTML
            copyAttempt.log("Trying clipboard HTML source recovery")
            let result = try await ClipboardHTMLExtractor.recoverImage()
            try PasteboardWriter.writePNG(image: result.image)
            finishSuccess(path: .clipboardHTML, detail: result.sourceDescription)
            return
        } catch {
            copyAttempt.log("Clipboard HTML path failed: \(error.localizedDescription)", isError: true)
        }

        guard allowManualFallback else {
            finishFailure(detail: "Automatic copy could not recover a real image from the clipboard. The original clipboard contents were left in place.")
            return
        }

        do {
            copyAttempt.activePath = .manualRegion
            copyAttempt.log("Falling back to manual region capture")
            let image = try await ManualRegionCapture.captureInteractive()
            try PasteboardWriter.writePNG(image: image)
            finishSuccess(path: .manualRegion, detail: "Captured via native macOS region selection")
        } catch {
            finishFailure(detail: "Manual region fallback failed: \(error.localizedDescription)")
        }
    }

    func refreshMonitoringPermissions() {
        copyCommandMonitor.refreshAccess()
        if !copyCommandMonitor.hasListenAccess {
            copyCommandMonitor.requestAccess()
        }
        copyCommandMonitor.start()
        hasInputMonitoringAccess = copyCommandMonitor.hasListenAccess
        refreshStatusText()
    }

    private func handleGlobalCopyCommand() async {
        guard automaticCopyEnabled else { return }
        guard hasInputMonitoringAccess else {
            refreshStatusText()
            return
        }
        guard copyAttempt.status != .running else { return }
        guard let context = browserContextDetector.frontmostGoogleSlidesContext() else { return }

        copyAttempt.log("Detected Command-C in \(context.browserName) Google Slides")

        let pasteboard = NSPasteboard.general
        let startingChangeCount = pasteboard.changeCount
        automaticCopyTask?.cancel()
        automaticCopyTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 140_000_000)
            await self.waitForPasteboardChange(from: startingChangeCount)
            guard !Task.isCancelled else { return }
            await self.performCopy(trigger: "Automatic Copy", allowManualFallback: false)
        }
    }

    private func waitForPasteboardChange(from initialChangeCount: Int) async {
        let deadline = Date().addingTimeInterval(0.7)
        while NSPasteboard.general.changeCount == initialChangeCount, Date() < deadline {
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
    }

    private func finishSuccess(path: ExtractionPath, detail: String) {
        copyAttempt.status = .succeeded
        copyAttempt.succeededPath = path
        copyAttempt.activePath = path
        copyAttempt.finishedAt = Date()
        copyAttempt.detail = detail
        copyAttempt.log("Success via \(path.rawValue): \(detail)")
        refreshStatusText()
    }

    private func finishFailure(detail: String) {
        copyAttempt.status = .failed
        copyAttempt.finishedAt = Date()
        copyAttempt.detail = detail
        copyAttempt.log(detail, isError: true)
        refreshStatusText()
    }

    private func refreshStatusText() {
        if !hasInputMonitoringAccess {
            statusText = "Input Monitoring access is required for automatic Google Slides copy detection."
            return
        }

        switch copyAttempt.status {
        case .running:
            statusText = "Converting the current Google Slides copy into PNG..."
        case .succeeded:
            statusText = "Automatic Google Slides conversion is ready."
        case .failed:
            statusText = "Automatic mode is running, but the last conversion failed."
        case .idle:
            statusText = automaticCopyEnabled
                ? "Watching for Command-C in Google Slides."
                : "Automatic Google Slides monitoring is paused."
        }
    }
}
