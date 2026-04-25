import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageDecodeError: LocalizedError {
    case invalidDataURL
    case unsupportedImage
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidDataURL:
            return "Invalid image data URL."
        case .unsupportedImage:
            return "Unsupported image payload."
        case .imageCreationFailed:
            return "Unable to create image."
        }
    }
}

enum ImageUtilities {
    static func image(from data: Data) -> NSImage? {
        NSImage(data: data)
    }

    static func image(fromDataURL string: String) throws -> NSImage {
        let data = try dataFromDataURL(string)
        guard let image = NSImage(data: data) else {
            throw ImageDecodeError.unsupportedImage
        }
        return image
    }

    static func dataFromDataURL(_ string: String) throws -> Data {
        guard string.hasPrefix("data:"),
              let commaIndex = string.firstIndex(of: ",") else {
            throw ImageDecodeError.invalidDataURL
        }

        let header = String(string[..<commaIndex])
        let payload = String(string[string.index(after: commaIndex)...])
        if header.contains(";base64") {
            guard let data = Data(base64Encoded: payload) else {
                throw ImageDecodeError.invalidDataURL
            }
            return data
        }

        guard let decoded = payload.removingPercentEncoding,
              let data = decoded.data(using: .utf8) else {
            throw ImageDecodeError.invalidDataURL
        }
        return data
    }

    static func pngData(from image: NSImage) -> Data? {
        guard let cgImage = cgImage(from: image) else { return nil }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }

    static func crop(_ image: NSImage, to rect: CGRect) -> NSImage? {
        guard let cgImage = cgImage(from: image) else { return nil }
        let integralRect = rect.integral
        guard integralRect.width > 0,
              integralRect.height > 0,
              let cropped = cgImage.cropping(to: integralRect) else {
            return nil
        }
        return NSImage(cgImage: cropped, size: NSSize(width: integralRect.width, height: integralRect.height))
    }

    static func cgImage(from image: NSImage) -> CGImage? {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}
