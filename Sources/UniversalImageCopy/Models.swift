import CoreGraphics
import Foundation

enum ExtractionPath: String, Codable, CaseIterable, Identifiable {
    case clipboardHTML = "Clipboard HTML"
    case manualRegion = "Manual Region"

    var id: String { rawValue }
}

enum AttemptStatus: String, Codable {
    case idle
    case running
    case succeeded
    case failed
}

struct AppLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let message: String
    let isError: Bool

    init(id: UUID = UUID(), timestamp: Date = Date(), message: String, isError: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.isError = isError
    }
}

struct CopyAttemptState {
    var status: AttemptStatus = .idle
    var activePath: ExtractionPath?
    var succeededPath: ExtractionPath?
    var startedAt: Date?
    var finishedAt: Date?
    var detail: String = "Idle"
    var logs: [AppLogEntry] = []

    mutating func reset(detail: String) {
        status = .running
        activePath = nil
        succeededPath = nil
        startedAt = Date()
        finishedAt = nil
        self.detail = detail
        logs.removeAll(keepingCapacity: true)
    }

    mutating func log(_ message: String, isError: Bool = false) {
        logs.insert(AppLogEntry(message: message, isError: isError), at: 0)
        if logs.count > 40 {
            logs.removeLast(logs.count - 40)
        }
    }
}

struct RectPayload: Codable, Hashable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct SizePayload: Codable, Hashable {
    let width: Double
    let height: Double
}
