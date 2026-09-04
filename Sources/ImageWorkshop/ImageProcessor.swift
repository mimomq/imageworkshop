import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageProcessingError: LocalizedError {
    case cannotRead
    case cannotRender
    case cannotEncode(String)
    case unsupportedOutputFormat(String)

    var errorDescription: String? {
        switch self {
        case .cannotRead: return "无法读取图片，可能是文件已损坏或格式不受支持"
        case .cannotRender: return "无法渲染图片，请尝试较小的目标尺寸"
        case .cannotEncode(let format): return "无法编码为 \(format)"
        case .unsupportedOutputFormat(let format): return "不支持输出为 \(format) 格式"
        }
    }
}

enum ImageProcessor {
    /// ImageIO honors embedded ICC profiles here, then Core Graphics converts
    /// to standard sRGB. This covers common RGB, Display P3, Adobe RGB,
    /// grayscale and CMYK JPEG/TIFF images, plus PNG, HEIC and WebP.
    static func process(sourceURL: URL, destinationURL: URL, options: ResizeOptions) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageProcessingError.cannotRead
        }

        let sourceSize = CGSize(width: sourceImage.width, height: sourceImage.height)
        let targetSize = ResizeMath.targetSize(source: sourceSize, options: options)
        let width = max(Int(targetSize.width.rounded()), 1)
        let height = max(Int(targetSize.height.rounded()), 1)
        let outputExtension = destinationURL.pathExtension.lowercased()
        let preservesTransparency = ["png", "gif", "webp"].contains(outputExtension)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ImageProcessingError.cannotRender
        }

        context.interpolationQuality = .high
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.setBlendMode(.copy)
        context.setFillColor(preservesTransparency ? CGColor.clear : CGColor.white)
        context.fill(canvas)

        let destinationRect: CGRect
        if options.strategy == .fill && options.dimensionMode == .widthAndHeight {
            let scale = max(CGFloat(width) / CGFloat(sourceImage.width), CGFloat(height) / CGFloat(sourceImage.height))
            let drawWidth = CGFloat(sourceImage.width) * scale
            let drawHeight = CGFloat(sourceImage.height) * scale
            destinationRect = CGRect(
                x: (CGFloat(width) - drawWidth) / 2,
                y: (CGFloat(height) - drawHeight) / 2,
                width: drawWidth,
                height: drawHeight
            )
        } else {
            destinationRect = canvas
        }
        context.setBlendMode(.normal)
        context.draw(sourceImage, in: destinationRect)

        guard let outputImage = context.makeImage() else { throw ImageProcessingError.cannotRender }
        try write(outputImage, to: destinationURL, quality: options.quality)
    }

    @discardableResult
    static func processReplacing(sourceURL: URL, destinationURL: URL, options: ResizeOptions) throws -> Bool {
        let fileManager = FileManager.default
        let directory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = directory
            .appendingPathComponent(".imageworkshop-output-\(UUID().uuidString)")
            .appendingPathExtension(destinationURL.pathExtension)
        let didReplace = fileManager.fileExists(atPath: destinationURL.path)

        do {
            try process(sourceURL: sourceURL, destinationURL: temporaryURL, options: options)
            if didReplace {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            }
            return didReplace
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func write(_ image: CGImage, to destinationURL: URL, quality: Double) throws {
        let formatName = destinationURL.pathExtension.uppercased()
        guard let type = outputType(for: destinationURL.pathExtension) else {
            throw ImageProcessingError.unsupportedOutputFormat(formatName)
        }
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, type.identifier as CFString, 1, nil) else {
            throw ImageProcessingError.cannotEncode(formatName)
        }

        var properties: [CFString: Any] = [:]
        if type == .jpeg || type == .heic || type == .webP {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0.1), 1)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageProcessingError.cannotEncode(formatName)
        }
    }

    private static func outputType(for extensionName: String) -> UTType? {
        switch extensionName.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        case "tif", "tiff": return .tiff
        case "gif": return .gif
        case "bmp": return .bmp
        case "webp": return .webP
        default: return nil
        }
    }
}
