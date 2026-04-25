import AppKit
import Foundation

enum ManualRegionCaptureError: LocalizedError {
    case cancelled
    case missingImage

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Manual region capture was cancelled."
        case .missingImage:
            return "macOS region capture did not place an image on the pasteboard."
        }
    }
}

enum ManualRegionCapture {
    @MainActor
    static func captureInteractive() async throws -> NSImage {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c", "-t", "png"]

        try process.run()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ManualRegionCaptureError.cancelled)
                }
            }
        }

        try await Task.sleep(nanoseconds: 180_000_000)

        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png),
           let image = NSImage(data: data) {
            return image
        }
        if let data = pasteboard.data(forType: .tiff),
           let image = NSImage(data: data) {
            return image
        }

        throw ManualRegionCaptureError.missingImage
    }
}
