import AppKit
import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case rename = "批量更名"
    case resize = "调整尺寸"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .rename: return "character.cursor.ibeam"
        case .resize: return "aspectratio"
        }
    }
}

enum NameCaseRule: String, CaseIterable, Identifiable, Codable {
    case unchanged = "保持不变"
    case lowercase = "全部小写"
    case uppercase = "全部大写"
    case title = "单词首字母大写"

    var id: String { rawValue }
}

enum OutputFormat: String, CaseIterable, Identifiable, Codable {
    case original = "保持原格式"
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    case tiff = "TIFF"

    var id: String { rawValue }
    var fileExtension: String? {
        switch self {
        case .original: return nil
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }
}

enum ResizeStrategy: String, CaseIterable, Identifiable, Codable {
    case fit = "适应边界"
    case fill = "填充并裁剪"
    case stretch = "拉伸到尺寸"

    var id: String { rawValue }
    var help: String {
        switch self {
        case .fit: return "保持比例，完整放入目标宽高"
        case .fill: return "保持比例，居中裁掉超出区域"
        case .stretch: return "不保持比例，精确使用目标宽高"
        }
    }
}

enum ResizeDimensionMode: String, CaseIterable, Identifiable, Codable {
    case longEdge = "仅修改长边"
    case widthAndHeight = "同时修改宽高"
    case percentage = "按百分比"

    var id: String { rawValue }
}

struct RenameOptions: Equatable, Codable {
    var template = "{name}"
    var prefix = ""
    var suffix = ""
    var find = ""
    var replacement = ""
    var useRegex = false
    var caseRule: NameCaseRule = .unchanged
    var changeExtension = false
    var newExtension = "jpg"
    var sequenceStart = 1
    var sequenceStep = 1
    var sequenceDigits = 3
    var insertEnabled = false
    var insertText = ""
    var insertAfterPosition = 0

    private enum CodingKeys: String, CodingKey {
        case template, prefix, suffix, find, replacement, useRegex, caseRule
        case changeExtension, newExtension, sequenceStart, sequenceStep, sequenceDigits
        case insertEnabled, insertText, insertAfterPosition
    }

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        template = try container.decodeIfPresent(String.self, forKey: .template) ?? "{name}"
        prefix = try container.decodeIfPresent(String.self, forKey: .prefix) ?? ""
        suffix = try container.decodeIfPresent(String.self, forKey: .suffix) ?? ""
        find = try container.decodeIfPresent(String.self, forKey: .find) ?? ""
        replacement = try container.decodeIfPresent(String.self, forKey: .replacement) ?? ""
        useRegex = try container.decodeIfPresent(Bool.self, forKey: .useRegex) ?? false
        caseRule = try container.decodeIfPresent(NameCaseRule.self, forKey: .caseRule) ?? .unchanged
        changeExtension = try container.decodeIfPresent(Bool.self, forKey: .changeExtension) ?? false
        newExtension = try container.decodeIfPresent(String.self, forKey: .newExtension) ?? "jpg"
        sequenceStart = try container.decodeIfPresent(Int.self, forKey: .sequenceStart) ?? 1
        sequenceStep = try container.decodeIfPresent(Int.self, forKey: .sequenceStep) ?? 1
        sequenceDigits = try container.decodeIfPresent(Int.self, forKey: .sequenceDigits) ?? 3
        insertEnabled = try container.decodeIfPresent(Bool.self, forKey: .insertEnabled) ?? false
        insertText = try container.decodeIfPresent(String.self, forKey: .insertText) ?? ""
        insertAfterPosition = try container.decodeIfPresent(Int.self, forKey: .insertAfterPosition) ?? 0
    }
}

struct ResizeOptions: Equatable, Codable {
    var dimensionMode: ResizeDimensionMode = .longEdge
    var longEdge = 1_920
    var width = 1_920
    var height = 1_080
    var percent = 50
    var strategy: ResizeStrategy = .fit
    var doNotEnlarge = true
    var format: OutputFormat = .original
    var quality = 0.88
    var suffix = ""
    var outputDirectory: URL?

    private enum CodingKeys: String, CodingKey {
        case dimensionMode, longEdge, usePercent, width, height, percent, strategy
        case doNotEnlarge, format, quality, suffix, outputDirectory
    }

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let mode = try container.decodeIfPresent(ResizeDimensionMode.self, forKey: .dimensionMode) {
            dimensionMode = mode
        } else {
            let legacyPercent = try container.decodeIfPresent(Bool.self, forKey: .usePercent) ?? false
            dimensionMode = legacyPercent ? .percentage : .widthAndHeight
        }
        longEdge = try container.decodeIfPresent(Int.self, forKey: .longEdge) ?? 1_920
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 1_920
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 1_080
        percent = try container.decodeIfPresent(Int.self, forKey: .percent) ?? 50
        strategy = try container.decodeIfPresent(ResizeStrategy.self, forKey: .strategy) ?? .fit
        doNotEnlarge = try container.decodeIfPresent(Bool.self, forKey: .doNotEnlarge) ?? true
        format = try container.decodeIfPresent(OutputFormat.self, forKey: .format) ?? .original
        quality = try container.decodeIfPresent(Double.self, forKey: .quality) ?? 0.88
        suffix = ""
        outputDirectory = try container.decodeIfPresent(URL.self, forKey: .outputDirectory)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dimensionMode, forKey: .dimensionMode)
        try container.encode(longEdge, forKey: .longEdge)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(percent, forKey: .percent)
        try container.encode(strategy, forKey: .strategy)
        try container.encode(doNotEnlarge, forKey: .doNotEnlarge)
        try container.encode(format, forKey: .format)
        try container.encode(quality, forKey: .quality)
        try container.encode("", forKey: .suffix)
        try container.encodeIfPresent(outputDirectory, forKey: .outputDirectory)
    }
}

struct RenamePreset: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var options: RenameOptions

    init(id: UUID = UUID(), name: String, options: RenameOptions) {
        self.id = id
        self.name = name
        self.options = options
    }
}

struct ResizePreset: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var options: ResizeOptions

    init(id: UUID = UUID(), name: String, options: ResizeOptions) {
        self.id = id
        self.name = name
        self.options = options
    }
}

struct ImageEntry: Identifiable {
    let id: UUID
    var url: URL
    var isIncluded: Bool
    var pixelWidth: Int
    var pixelHeight: Int
    var fileSize: Int64
    var status: String

    init(url: URL, isIncluded: Bool = true, pixelWidth: Int, pixelHeight: Int, fileSize: Int64, status: String = "待处理") {
        self.id = UUID()
        self.url = url
        self.isIncluded = isIncluded
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSize = fileSize
        self.status = status
    }

    var fileName: String { url.lastPathComponent }
    var stem: String { url.deletingPathExtension().lastPathComponent }
    var ext: String { url.pathExtension }
    var dimensionsText: String { "\(pixelWidth) × \(pixelHeight)" }
    var sizeText: String { ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file) }
}

struct RenamePreview {
    let fileName: String
    let warning: String?
}

enum ResizeMath {
    static func targetSize(source: NSSize, options: ResizeOptions) -> NSSize {
        guard source.width > 0, source.height > 0 else { return .zero }
        if options.dimensionMode == .percentage {
            let scale = max(Double(options.percent), 1) / 100
            return scaledSize(source: source, scale: options.doNotEnlarge ? min(scale, 1) : scale)
        }

        if options.dimensionMode == .longEdge {
            var scale = CGFloat(max(options.longEdge, 1)) / max(source.width, source.height)
            if options.doNotEnlarge { scale = min(scale, 1) }
            return scaledSize(source: source, scale: scale)
        }

        let box = NSSize(width: max(options.width, 1), height: max(options.height, 1))
        if options.strategy == .stretch || options.strategy == .fill { return box }

        var scale = min(box.width / source.width, box.height / source.height)
        if options.doNotEnlarge { scale = min(scale, 1) }
        return NSSize(
            width: max(1, (source.width * scale).rounded()),
            height: max(1, (source.height * scale).rounded())
        )
    }

    private static func scaledSize(source: NSSize, scale: CGFloat) -> NSSize {
        NSSize(
            width: max(1, (source.width * scale).rounded()),
            height: max(1, (source.height * scale).rounded())
        )
    }
}

enum ImageOutputNaming {
    static func destinationURL(for entry: ImageEntry, in directory: URL, format: OutputFormat) -> URL {
        if let outputExtension = format.fileExtension {
            return directory.appendingPathComponent(entry.stem).appendingPathExtension(outputExtension)
        }
        return directory.appendingPathComponent(entry.fileName)
    }
}
