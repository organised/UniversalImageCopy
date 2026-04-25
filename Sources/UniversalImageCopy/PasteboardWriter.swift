import AppKit
import Foundation

enum PasteboardWriter {
    static func writePNG(image: NSImage, to pasteboard: NSPasteboard = .general) throws {
        guard let pngData = ImageUtilities.pngData(from: image) else {
            throw NSError(domain: "UniversalImageCopy.PasteboardWriter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to encode PNG data."
            ])
        }

        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)
        if let tiffData = image.tiffRepresentation {
            item.setData(tiffData, forType: .tiff)
        }

        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else {
            throw NSError(domain: "UniversalImageCopy.PasteboardWriter", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to write PNG data to the pasteboard."
            ])
        }
    }
}
