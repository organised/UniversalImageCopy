import AppKit
import Foundation

struct BrowserContext {
    let browserName: String
    let browserBundleIdentifier: String
    let activeURL: URL?
    let activeTabTitle: String?

    var isGoogleSlides: Bool {
        if let activeURL {
            return activeURL.absoluteString.contains("docs.google.com/presentation")
        }
        if let activeTabTitle {
            return activeTabTitle.localizedCaseInsensitiveContains("Google Slides")
        }
        return false
    }
}

final class BrowserContextDetector {
    private struct BrowserDescriptor {
        let bundleIdentifier: String
        let appleScriptName: String
        let displayName: String
    }

    private let supportedBrowsers: [BrowserDescriptor] = [
        BrowserDescriptor(bundleIdentifier: "com.google.Chrome", appleScriptName: "Google Chrome", displayName: "Google Chrome"),
        BrowserDescriptor(bundleIdentifier: "com.google.Chrome.canary", appleScriptName: "Google Chrome Canary", displayName: "Google Chrome Canary"),
        BrowserDescriptor(bundleIdentifier: "org.chromium.Chromium", appleScriptName: "Chromium", displayName: "Chromium"),
        BrowserDescriptor(bundleIdentifier: "com.brave.Browser", appleScriptName: "Brave Browser", displayName: "Brave Browser"),
        BrowserDescriptor(bundleIdentifier: "com.microsoft.edgemac", appleScriptName: "Microsoft Edge", displayName: "Microsoft Edge")
    ]

    func frontmostGoogleSlidesContext() -> BrowserContext? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier,
              let descriptor = supportedBrowsers.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return nil
        }

        let activeURL = activeTabURL(for: descriptor.appleScriptName)
        let activeTabTitle = activeTabTitle(for: descriptor.appleScriptName)
        let context = BrowserContext(
            browserName: descriptor.displayName,
            browserBundleIdentifier: descriptor.bundleIdentifier,
            activeURL: activeURL,
            activeTabTitle: activeTabTitle
        )

        return context.isGoogleSlides ? context : nil
    }

    private func activeTabURL(for appName: String) -> URL? {
        let script = """
        tell application "\(appName)"
            if it is running then
                try
                    return URL of active tab of front window
                on error
                    return ""
                end try
            end if
        end tell
        """

        guard let value = runAppleScript(script),
              !value.isEmpty else {
            return nil
        }
        return URL(string: value)
    }

    private func activeTabTitle(for appName: String) -> String? {
        let script = """
        tell application "\(appName)"
            if it is running then
                try
                    return title of active tab of front window
                on error
                    return ""
                end try
            end if
        end tell
        """

        guard let value = runAppleScript(script),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func runAppleScript(_ source: String) -> String? {
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: source)
        let value = script?.executeAndReturnError(&errorInfo).stringValue
        if value == nil, let errorInfo {
            NSLog("UniversalImageCopy AppleScript error: %@", errorInfo)
        }
        return value
    }
}
