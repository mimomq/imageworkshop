import AppKit
import Foundation
import ImageIO

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var section: WorkspaceSection = .rename
    @Published var entries: [ImageEntry] = []
    @Published var renameOptions = RenameOptions()
    @Published var resizeOptions = ResizeOptions()
    @Published private(set) var renamePresets: [RenamePreset]
    @Published private(set) var resizePresets: [ResizePreset]
    @Published var selection: Set<UUID> = []
    @Published var isWorking = false
    @Published var progress = 0.0
    @Published var message: String?
    @Published var showMessage = false

    private var lastRenameBatch: [(old: URL, new: URL)] = []
    private var commandRangeAnchor: UUID?
    private let supportedExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "bmp", "webp"])
    private let defaults: UserDefaults
    private static let renamePresetsKey = "local.imageworkshop.rename-presets.v1"
    private static let resizePresetsKey = "local.imageworkshop.resize-presets.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.renamePresets = Self.load([RenamePreset].self, key: Self.renamePresetsKey, defaults: defaults) ?? []
        self.resizePresets = Self.load([ResizePreset].self, key: Self.resizePresetsKey, defaults: defaults) ?? []
    }

    var includedEntries: [ImageEntry] { entries.filter(\.isIncluded) }
    var canUndoRename: Bool { !lastRenameBatch.isEmpty && !isWorking }
    var previewEntry: ImageEntry? {
        entries.first(where: { selection.contains($0.id) }) ?? includedEntries.first ?? entries.first
    }

    func saveRenamePreset(named rawName: String) {
        let name = normalizedPresetName(rawName, fallback: "更名方案 \(renamePresets.count + 1)")
        if let index = renamePresets.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            renamePresets[index].options = renameOptions
        } else {
            renamePresets.append(RenamePreset(name: name, options: renameOptions))
        }
        persistPresets()
    }

    func saveResizePreset(named rawName: String) {
        let name = normalizedPresetName(rawName, fallback: "尺寸方案 \(resizePresets.count + 1)")
        if let index = resizePresets.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            resizePresets[index].options = resizeOptions
        } else {
            resizePresets.append(ResizePreset(name: name, options: resizeOptions))
        }
        persistPresets()
    }

    func apply(renamePreset: RenamePreset) {
        renameOptions = renamePreset.options
    }

    func apply(resizePreset: ResizePreset) {
        resizeOptions = resizePreset.options
        resizeOptions.suffix = ""
    }

    func delete(renamePreset: RenamePreset) {
        renamePresets.removeAll { $0.id == renamePreset.id }
        persistPresets()
    }

    func delete(resizePreset: ResizePreset) {
        resizePresets.removeAll { $0.id == resizePreset.id }
        persistPresets()
    }

    func preview(for entry: ImageEntry) -> RenamePreview {
        let included = includedEntries
        let index = included.firstIndex(where: { $0.id == entry.id }) ?? 0
        return RenameEngine.preview(entry: entry, index: index, options: renameOptions)
    }

    func targetDimensions(for entry: ImageEntry) -> String {
        let size = ResizeMath.targetSize(
            source: NSSize(width: entry.pixelWidth, height: entry.pixelHeight),
            options: resizeOptions
        )
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    func openFiles() {
        let panel = NSOpenPanel()
        panel.title = "选择图片"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择图片文件夹"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择输出文件夹"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { resizeOptions.outputDirectory = panel.url }
    }

    func add(urls: [URL]) {
        var discovered: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                while let item = enumerator?.nextObject() as? URL {
                    if supportedExtensions.contains(item.pathExtension.lowercased()) { discovered.append(item) }
                }
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                discovered.append(url)
            }
        }

        let knownPaths = Set(entries.map { $0.url.standardizedFileURL.path })
        for url in discovered where !knownPaths.contains(url.standardizedFileURL.path) {
            if let metadata = Self.metadata(for: url) {
                entries.append(ImageEntry(
                    url: url,
                    pixelWidth: metadata.width,
                    pixelHeight: metadata.height,
                    fileSize: metadata.fileSize
                ))
            }
        }
        entries.sort { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
    }

    func removeSelected() {
        entries.removeAll { selection.contains($0.id) }
        selection.removeAll()
        commandRangeAnchor = nil
    }

    func clear() {
        entries.removeAll()
        selection.removeAll()
        commandRangeAnchor = nil
        lastRenameBatch.removeAll()
    }

    func setAllIncluded(_ included: Bool) {
        for index in entries.indices { entries[index].isIncluded = included }
    }

    func updateTableSelection(_ proposed: Set<UUID>, commandPressed: Bool) {
        let added = proposed.subtracting(selection)
        guard commandPressed, added.count == 1, let endpoint = added.first else {
            selection = proposed
            commandRangeAnchor = nil
            return
        }

        if let anchor = commandRangeAnchor,
           let anchorIndex = entries.firstIndex(where: { $0.id == anchor }),
           let endpointIndex = entries.firstIndex(where: { $0.id == endpoint }) {
            let bounds = min(anchorIndex, endpointIndex)...max(anchorIndex, endpointIndex)
            selection = proposed.union(bounds.map { entries[$0].id })
            commandRangeAnchor = nil
        } else {
            selection = proposed
            commandRangeAnchor = endpoint
        }
    }

    func includeOnlySelection() {
        guard !selection.isEmpty else { return }
        for index in entries.indices {
            entries[index].isIncluded = selection.contains(entries[index].id)
        }
    }

    func toggleIncludedForSelection() {
        guard !selection.isEmpty else { return }
        let shouldInclude = selection.contains { id in
            entries.first(where: { $0.id == id })?.isIncluded == false
        }
        for index in entries.indices where selection.contains(entries[index].id) {
            entries[index].isIncluded = shouldInclude
        }
    }

    func applyRename() {
        guard !isWorking else { return }
        let selected = entries.indices.filter { entries[$0].isIncluded }
        guard !selected.isEmpty else { present("请先勾选需要更名的图片") ; return }

        var planned: [(index: Int, old: URL, target: URL)] = []
        var targets = Set<String>()
        for (sequence, index) in selected.enumerated() {
            let entry = entries[index]
            let result = RenameEngine.preview(entry: entry, index: sequence, options: renameOptions)
            if let warning = result.warning { present("\(entry.fileName)：\(warning)"); return }
            let target = entry.url.deletingLastPathComponent().appendingPathComponent(result.fileName)
            let key = target.standardizedFileURL.path.lowercased()
            if targets.contains(key) { present("目标名称重复：\(result.fileName)"); return }
            targets.insert(key)
            planned.append((index, entry.url, target))
        }

        let changes = planned.filter { $0.old != $0.target }
        guard !changes.isEmpty else { present("预览名称与原名称相同，无需更名"); return }
        let movingSources = Set(changes.map { $0.old.standardizedFileURL.path.lowercased() })
        for change in changes where FileManager.default.fileExists(atPath: change.target.path) {
            let targetKey = change.target.standardizedFileURL.path.lowercased()
            if !movingSources.contains(targetKey) {
                present("已有同名文件：\(change.target.lastPathComponent)")
                return
            }
        }
        isWorking = true
        var staged: [(index: Int, old: URL, temp: URL, target: URL)] = []
        var completed: [(index: Int, old: URL, temp: URL, target: URL)] = []
        do {
            for change in changes {
                let temp = change.old.deletingLastPathComponent()
                    .appendingPathComponent(".imageworkshop-\(UUID().uuidString)")
                try FileManager.default.moveItem(at: change.old, to: temp)
                staged.append((change.index, change.old, temp, change.target))
            }
            for item in staged {
                try FileManager.default.moveItem(at: item.temp, to: item.target)
                entries[item.index].url = item.target
                entries[item.index].status = "更名成功"
                completed.append(item)
            }
            lastRenameBatch = completed.map { ($0.old, $0.target) }
            isWorking = false
            present("已成功更名 \(completed.count) 张图片，可用 ⌘Z 撤销")
        } catch {
            var rollbackItems: [(index: Int, old: URL, temp: URL)] = []
            for item in completed where FileManager.default.fileExists(atPath: item.target.path) {
                let rollbackTemp = item.old.deletingLastPathComponent()
                    .appendingPathComponent(".imageworkshop-rollback-\(UUID().uuidString)")
                if (try? FileManager.default.moveItem(at: item.target, to: rollbackTemp)) != nil {
                    rollbackItems.append((item.index, item.old, rollbackTemp))
                }
            }
            for item in staged where FileManager.default.fileExists(atPath: item.temp.path) {
                rollbackItems.append((item.index, item.old, item.temp))
            }
            for item in rollbackItems {
                if (try? FileManager.default.moveItem(at: item.temp, to: item.old)) != nil {
                    entries[item.index].url = item.old
                    entries[item.index].status = "已回滚"
                }
            }
            isWorking = false
            present("更名失败：\(error.localizedDescription)")
        }
    }

    func undoLastRename() {
        guard canUndoRename else { return }
        var failed = 0
        for item in lastRenameBatch.reversed() {
            do {
                guard FileManager.default.fileExists(atPath: item.new.path),
                      !FileManager.default.fileExists(atPath: item.old.path) else { failed += 1; continue }
                try FileManager.default.moveItem(at: item.new, to: item.old)
                if let index = entries.firstIndex(where: { $0.url == item.new }) {
                    entries[index].url = item.old
                    entries[index].status = "已撤销"
                }
            } catch { failed += 1 }
        }
        let count = lastRenameBatch.count - failed
        lastRenameBatch.removeAll()
        present(failed == 0 ? "已撤销 \(count) 项更名" : "已撤销 \(count) 项，\(failed) 项无法恢复")
    }

    func processImages() {
        guard !isWorking else { return }
        let selectedIDs = entries.filter(\.isIncluded).map(\.id)
        guard !selectedIDs.isEmpty else { present("请先勾选需要处理的图片"); return }
        let options = resizeOptions
        let fallbackRoot = entries.first?.url.deletingLastPathComponent().appendingPathComponent("图匠输出")
        guard let outputRoot = options.outputDirectory ?? fallbackRoot else { return }

        isWorking = true
        progress = 0
        Task {
            var succeeded = 0
            var failed = 0
            try? FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
            for (offset, id) in selectedIDs.enumerated() {
                guard let index = entries.firstIndex(where: { $0.id == id }) else { continue }
                let entry = entries[index]
                let destination = ImageOutputNaming.destinationURL(
                    for: entry,
                    in: outputRoot,
                    format: options.format
                )
                do {
                    let replaced = try await Task.detached(priority: .userInitiated) {
                        try ImageProcessor.processReplacing(sourceURL: entry.url, destinationURL: destination, options: options)
                    }.value
                    entries[index].status = replaced
                        ? "已覆盖：\(destination.lastPathComponent)"
                        : "已输出：\(destination.lastPathComponent)"
                    succeeded += 1
                } catch {
                    entries[index].status = "失败：\(error.localizedDescription)"
                    failed += 1
                }
                progress = Double(offset + 1) / Double(selectedIDs.count)
                await Task.yield()
            }
            isWorking = false
            if failed == 0 {
                present("已处理 \(succeeded) 张图片\n输出到：\(outputRoot.path)")
                NSWorkspace.shared.activateFileViewerSelecting([outputRoot])
            } else {
                present("处理完成：成功 \(succeeded) 张，失败 \(failed) 张")
            }
        }
    }

    private func present(_ text: String) {
        message = text
        showMessage = true
    }

    private func normalizedPresetName(_ rawName: String, fallback: String) -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
    }

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(renamePresets) {
            defaults.set(data, forKey: Self.renamePresetsKey)
        }
        if let data = try? JSONEncoder().encode(resizePresets) {
            defaults.set(data, forKey: Self.resizePresetsKey)
        }
    }

    private static func load<Value: Decodable>(_ type: Value.Type, key: String, defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func metadata(for url: URL) -> (width: Int, height: Int, fileSize: Int64)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { return nil }
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return (width.intValue, height.intValue, fileSize)
    }
}
