import Foundation

enum RenameEngine {
    static func preview(entry: ImageEntry, index: Int, options: RenameOptions) -> RenamePreview {
        let paddedIndex = String(format: "%0*d", max(options.sequenceDigits, 1), options.sequenceStart + index * options.sequenceStep)
        let values = [
            "{name}": entry.stem,
            "{ext}": entry.ext,
            "{parent}": entry.url.deletingLastPathComponent().lastPathComponent,
            "{index}": paddedIndex,
            "{width}": String(entry.pixelWidth),
            "{height}": String(entry.pixelHeight),
            "{date}": Self.dateString(for: entry.url)
        ]

        var stem = options.template.isEmpty ? entry.stem : options.template
        for (token, value) in values { stem = stem.replacingOccurrences(of: token, with: value) }

        if !options.find.isEmpty {
            if options.useRegex {
                do {
                    let regex = try NSRegularExpression(pattern: options.find)
                    let range = NSRange(stem.startIndex..<stem.endIndex, in: stem)
                    stem = regex.stringByReplacingMatches(in: stem, range: range, withTemplate: options.replacement)
                } catch {
                    return RenamePreview(fileName: entry.fileName, warning: "正则表达式无效")
                }
            } else {
                stem = stem.replacingOccurrences(of: options.find, with: options.replacement)
            }
        }

        if options.insertEnabled && !options.insertText.isEmpty {
            let offset = min(max(options.insertAfterPosition, 0), stem.count)
            let insertionIndex = stem.index(stem.startIndex, offsetBy: offset)
            stem.insert(contentsOf: options.insertText, at: insertionIndex)
        }

        stem = options.prefix + stem + options.suffix
        switch options.caseRule {
        case .unchanged: break
        case .lowercase: stem = stem.lowercased()
        case .uppercase: stem = stem.uppercased()
        case .title: stem = stem.capitalized
        }

        stem = sanitize(stem)
        var ext = options.changeExtension ? options.newExtension : entry.ext
        ext = ext.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        ext = sanitize(ext)

        guard !stem.isEmpty else { return RenamePreview(fileName: entry.fileName, warning: "文件名不能为空") }
        guard !ext.isEmpty else { return RenamePreview(fileName: stem, warning: nil) }
        return RenamePreview(fileName: "\(stem).\(ext)", warning: nil)
    }

    static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dateString(for url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
