import AppKit
import Foundation

enum ClipboardHTMLExtractorError: LocalizedError {
    case missingHTML
    case noImageSourceFound
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingHTML:
            return "Clipboard did not include HTML."
        case .noImageSourceFound:
            return "Clipboard HTML did not expose a recoverable image source."
        case .downloadFailed(let value):
            return "Failed to download image source: \(value)"
        }
    }
}

struct ClipboardHTMLExtractionResult {
    let image: NSImage
    let sourceDescription: String
}

enum ClipboardHTMLExtractor {
    static func recoverImage(from pasteboard: NSPasteboard = .general) async throws -> ClipboardHTMLExtractionResult {
        guard let html = htmlString(from: pasteboard) else {
            throw ClipboardHTMLExtractorError.missingHTML
        }

        for source in candidateSources(from: html) {
            if source.hasPrefix("data:image/") {
                let image = try ImageUtilities.image(fromDataURL: source)
                return ClipboardHTMLExtractionResult(image: image, sourceDescription: "Recovered from clipboard HTML data URL")
            }

            if let resolved = resolveWrappedURL(source),
               let image = try await downloadImage(from: resolved) {
                return ClipboardHTMLExtractionResult(image: image, sourceDescription: "Recovered from clipboard HTML URL")
            }
        }

        throw ClipboardHTMLExtractorError.noImageSourceFound
    }

    private static func htmlString(from pasteboard: NSPasteboard) -> String? {
        if let direct = pasteboard.string(forType: .html) {
            return direct
        }

        guard let data = pasteboard.data(forType: .html) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func candidateSources(from html: String) -> [String] {
        let patterns = [
            #"src\s*=\s*["']([^"']+)["']"#,
            #"href\s*=\s*["']([^"']+\.(?:png|jpg|jpeg|webp|gif)(?:\?[^"']*)?)["']"#,
            #"url\((['"]?)(data:image[^)'"]+|https?://[^)'"]+)\1\)"#
        ]

        var values: [String] = []
        for pattern in patterns {
            let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            expression?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match else { return }
                let captureIndex = match.numberOfRanges > 2 ? 2 : 1
                guard let captureRange = Range(match.range(at: captureIndex), in: html) else { return }
                values.append(String(html[captureRange]))
            }
        }

        if let wrapperRange = html.range(of: #"imgurl=([^"&]+)"#, options: .regularExpression) {
            let fragment = String(html[wrapperRange])
            let parts = fragment.split(separator: "=")
            if parts.count == 2 {
                values.append(String(parts[1]))
            }
        }

        var unique: [String] = []
        var seen = Set<String>()
        for value in values.compactMap({ $0.removingPercentEncoding ?? $0 }) where !seen.contains(value) {
            seen.insert(value)
            unique.append(value)
        }
        return unique
    }

    private static func resolveWrappedURL(_ value: String) -> URL? {
        if let url = URL(string: value), url.scheme != nil {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let imageURL = components.queryItems?.first(where: { $0.name == "imgurl" })?.value,
               let resolved = URL(string: imageURL) {
                return resolved
            }
            return url
        }

        if value.hasPrefix("//") {
            return URL(string: "https:\(value)")
        }

        return URL(string: value)
    }

    private static func downloadImage(from url: URL) async throws -> NSImage? {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ClipboardHTMLExtractorError.downloadFailed(url.absoluteString)
        }
        return ImageUtilities.image(from: data)
    }
}
