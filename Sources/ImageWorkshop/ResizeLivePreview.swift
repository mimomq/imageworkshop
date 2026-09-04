import AppKit
import ImageIO
import SwiftUI

struct ResizeLivePreview: View {
    let entry: ImageEntry
    let options: ResizeOptions
    @State private var previewImage: NSImage?

    private var targetSize: NSSize {
        ResizeMath.targetSize(
            source: NSSize(width: entry.pixelWidth, height: entry.pixelHeight),
            options: options
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                if let previewImage {
                    previewSurface(image: previewImage)
                        .padding(8)
                } else {
                    ProgressView()
                }
            }
            .frame(height: 168)

            HStack(spacing: 6) {
                Text(entry.dimensionsText)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                Text("\(Int(targetSize.width)) × \(Int(targetSize.height))")
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
            }
            .font(.caption.monospacedDigit())
            Text(entry.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .task(id: entry.url) {
            previewImage = nil
            let url = entry.url
            let image = await Task.detached(priority: .utility) {
                Self.downsampledCGImage(at: url)
            }.value
            guard !Task.isCancelled else { return }
            if let image {
                previewImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            } else {
                previewImage = nil
            }
        }
    }

    @ViewBuilder
    private func previewSurface(image: NSImage) -> some View {
        let ratio = max(targetSize.width / max(targetSize.height, 1), 0.01)
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                if options.dimensionMode == .widthAndHeight && options.strategy == .stretch {
                    Image(nsImage: image)
                        .resizable()
                } else {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: options.dimensionMode == .widthAndHeight && options.strategy == .fill ? .fill : .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.primary.opacity(0.12))
            }
    }

    nonisolated private static func downsampledCGImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 900
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
