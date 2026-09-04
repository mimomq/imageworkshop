import AppKit
import SwiftUI
import XCTest
@testable import ImageWorkshop

final class ImageWorkshopTests: XCTestCase {
    func testRenameTemplatePipeline() throws {
        let url = URL(fileURLWithPath: "/Users/demo/相册/Summer Photo.JPG")
        let entry = ImageEntry(url: url, pixelWidth: 4000, pixelHeight: 3000, fileSize: 100)
        var options = RenameOptions()
        options.template = "{parent}_{index}_{width}x{height}_{name}"
        options.find = " "
        options.replacement = "-"
        options.prefix = "旅行_"
        options.sequenceStart = 7
        options.sequenceDigits = 3
        options.changeExtension = true
        options.newExtension = ".png"

        let result = RenameEngine.preview(entry: entry, index: 0, options: options)
        XCTAssertEqual(result.fileName, "旅行_相册_007_4000x3000_Summer-Photo.png")
        XCTAssertNil(result.warning)
    }

    func testInvalidRegexReturnsWarning() {
        let entry = ImageEntry(url: URL(fileURLWithPath: "/tmp/a.jpg"), pixelWidth: 1, pixelHeight: 1, fileSize: 1)
        var options = RenameOptions()
        options.find = "["
        options.useRegex = true
        XCTAssertEqual(RenameEngine.preview(entry: entry, index: 0, options: options).warning, "正则表达式无效")
    }

    func testFitAndDoNotEnlarge() {
        var options = ResizeOptions()
        options.dimensionMode = .widthAndHeight
        options.width = 1000
        options.height = 1000
        options.strategy = .fit
        XCTAssertEqual(ResizeMath.targetSize(source: NSSize(width: 4000, height: 2000), options: options), NSSize(width: 1000, height: 500))

        options.width = 8000
        options.height = 8000
        options.doNotEnlarge = true
        XCTAssertEqual(ResizeMath.targetSize(source: NSSize(width: 4000, height: 2000), options: options), NSSize(width: 4000, height: 2000))
    }

    func testPercentResize() {
        var options = ResizeOptions()
        options.dimensionMode = .percentage
        options.percent = 25
        XCTAssertEqual(ResizeMath.targetSize(source: NSSize(width: 4032, height: 3024), options: options), NSSize(width: 1008, height: 756))
    }

    func testLongEdgeKeepsLandscapeAndPortraitAspectRatio() {
        var options = ResizeOptions()
        options.dimensionMode = .longEdge
        options.longEdge = 1_000
        options.doNotEnlarge = false

        XCTAssertEqual(
            ResizeMath.targetSize(source: NSSize(width: 4_000, height: 3_000), options: options),
            NSSize(width: 1_000, height: 750)
        )
        XCTAssertEqual(
            ResizeMath.targetSize(source: NSSize(width: 3_000, height: 4_000), options: options),
            NSSize(width: 750, height: 1_000)
        )
    }

    func testRenameInsertionUsesCharacterPosition() {
        let entry = ImageEntry(
            url: URL(fileURLWithPath: "/tmp/春天照片.jpg"),
            pixelWidth: 100,
            pixelHeight: 100,
            fileSize: 1
        )
        var options = RenameOptions()
        options.insertEnabled = true
        options.insertAfterPosition = 2
        options.insertText = "_旅行_"

        XCTAssertEqual(
            RenameEngine.preview(entry: entry, index: 0, options: options).fileName,
            "春天_旅行_照片.jpg"
        )
    }

    func testRealPNGResizeOutput() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.png")
        let destination = root.appendingPathComponent("output.png")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 200,
            pixelsHigh: 100,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: source)

        var options = ResizeOptions()
        options.dimensionMode = .widthAndHeight
        options.width = 50
        options.height = 50
        options.strategy = .fit
        options.format = .png
        try ImageProcessor.process(sourceURL: source, destinationURL: destination, options: options)

        let output = try XCTUnwrap(NSImage(contentsOf: destination))
        var rect = NSRect(origin: .zero, size: output.size)
        let cgImage = try XCTUnwrap(output.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        XCTAssertEqual(cgImage.width, 50)
        XCTAssertEqual(cgImage.height, 25)
    }

    func testLongEdgeResizeForOptionalExternalFixture() throws {
        guard let fixturePath = ProcessInfo.processInfo.environment["IMAGE_WORKSHOP_FIXTURE"] else {
            throw XCTSkip("没有提供本地图片回归样本")
        }
        let source = URL(fileURLWithPath: fixturePath)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let destination = root.appendingPathComponent("D001.jpg")
        var options = ResizeOptions()
        options.dimensionMode = .longEdge
        options.longEdge = 600
        options.format = .original
        try ImageProcessor.process(sourceURL: source, destinationURL: destination, options: options)

        let output = try XCTUnwrap(NSImage(contentsOf: destination))
        var rect = NSRect(origin: .zero, size: output.size)
        let cgImage = try XCTUnwrap(output.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        XCTAssertEqual(max(cgImage.width, cgImage.height), 600)
    }

    func testResizeKeepsOriginalNameAndReplacesExistingResult() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceDirectory = root.appendingPathComponent("source")
        let outputDirectory = root.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceDirectory.appendingPathComponent("假期照片.png")
        let destination = outputDirectory.appendingPathComponent("假期照片.png")
        let sourceBitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 400,
            pixelsHigh: 200,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        try XCTUnwrap(sourceBitmap.representation(using: .png, properties: [:])).write(to: source)
        try Data("old-result".utf8).write(to: destination)

        var options = ResizeOptions()
        options.dimensionMode = .longEdge
        options.longEdge = 100
        options.doNotEnlarge = false
        options.format = .png
        let replaced = try ImageProcessor.processReplacing(
            sourceURL: source,
            destinationURL: destination,
            options: options
        )

        XCTAssertTrue(replaced)
        XCTAssertEqual(destination.lastPathComponent, source.lastPathComponent)
        let output = try XCTUnwrap(NSImage(contentsOf: destination))
        var rect = NSRect(origin: .zero, size: output.size)
        let cgImage = try XCTUnwrap(output.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        XCTAssertEqual(cgImage.width, 100)
        XCTAssertEqual(cgImage.height, 50)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil).count, 1)
    }

    func testOutputNamingPreservesExactOriginalName() {
        let entry = ImageEntry(
            url: URL(fileURLWithPath: "/tmp/旅行照片 01.JPEG"),
            pixelWidth: 1,
            pixelHeight: 1,
            fileSize: 1
        )
        let directory = URL(fileURLWithPath: "/tmp/output")

        XCTAssertEqual(
            ImageOutputNaming.destinationURL(for: entry, in: directory, format: .original).lastPathComponent,
            "旅行照片 01.JPEG"
        )
        XCTAssertEqual(
            ImageOutputNaming.destinationURL(for: entry, in: directory, format: .png).lastPathComponent,
            "旅行照片 01.png"
        )
    }

    func testLegacyResizePresetMigratesWithoutSuffix() throws {
        let json = """
        {
          "usePercent": false,
          "width": 1600,
          "height": 900,
          "percent": 50,
          "strategy": "适应边界",
          "doNotEnlarge": true,
          "format": "JPEG",
          "quality": 0.8,
          "suffix": "_已调整"
        }
        """
        let options = try JSONDecoder().decode(ResizeOptions.self, from: Data(json.utf8))

        XCTAssertEqual(options.dimensionMode, .widthAndHeight)
        XCTAssertEqual(options.width, 1600)
        XCTAssertEqual(options.height, 900)
        XCTAssertEqual(options.suffix, "")
    }

    @MainActor
    func testCommandEndpointRangesCanCreateDiscontiguousProcessingSelection() {
        let store = WorkspaceStore(defaults: UserDefaults(suiteName: "ImageWorkshopSelectionTests.\(UUID().uuidString)")!)
        store.entries = (1...10).map { number in
            ImageEntry(
                url: URL(fileURLWithPath: "/tmp/image-\(number).jpg"),
                pixelWidth: 100,
                pixelHeight: 100,
                fileSize: 1
            )
        }
        let ids = store.entries.map(\.id)

        store.updateTableSelection([ids[3]], commandPressed: true)
        store.updateTableSelection(store.selection.union([ids[4]]), commandPressed: true)
        store.updateTableSelection(store.selection.union([ids[6]]), commandPressed: true)
        store.updateTableSelection(store.selection.union([ids[7]]), commandPressed: true)
        store.includeOnlySelection()

        XCTAssertEqual(store.selection, Set([ids[3], ids[4], ids[6], ids[7]]))
        XCTAssertEqual(store.entries.enumerated().compactMap { $0.element.isIncluded ? $0.offset + 1 : nil }, [4, 5, 7, 8])
    }

    @MainActor
    func testResizePresetPersistsAndReloads() throws {
        let suiteName = "ImageWorkshopTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WorkspaceStore(defaults: defaults)
        store.resizeOptions.width = 1280
        store.resizeOptions.height = 720
        store.resizeOptions.format = .jpeg
        store.resizeOptions.quality = 0.76
        store.saveResizePreset(named: "网页输出")

        let restored = WorkspaceStore(defaults: defaults)
        let preset = try XCTUnwrap(restored.resizePresets.first)
        XCTAssertEqual(preset.name, "网页输出")
        XCTAssertEqual(preset.options.width, 1280)
        XCTAssertEqual(preset.options.height, 720)
        XCTAssertEqual(preset.options.format, .jpeg)
        XCTAssertEqual(preset.options.quality, 0.76)
    }

    @MainActor
    func testInspectorPanelsRenderForVisualQA() throws {
        let store = WorkspaceStore(defaults: UserDefaults(suiteName: "ImageWorkshopRenderTests.\(UUID().uuidString)")!)
        store.entries = [
            ImageEntry(
                url: URL(fileURLWithPath: "/Users/li/Desktop/截屏2026-09-03 15.39.32.png"),
                pixelWidth: 607,
                pixelHeight: 250,
                fileSize: 10_000
            )
        ]
        store.renameOptions.insertEnabled = true
        store.renameOptions.insertText = "_新_"
        store.renameOptions.insertAfterPosition = 2
        store.renameOptions.changeExtension = true

        try render(
            RenameInspector().environmentObject(store),
            size: NSSize(width: 390, height: 1_420),
            to: URL(fileURLWithPath: "/tmp/ImageWorkshop-RenameInspector.png")
        )
        try render(
            ResizeInspector().environmentObject(store),
            size: NSSize(width: 390, height: 1_050),
            to: URL(fileURLWithPath: "/tmp/ImageWorkshop-ResizeInspector.png")
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: "/tmp/ImageWorkshop-RenameInspector.png"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/tmp/ImageWorkshop-ResizeInspector.png"))
    }

    @MainActor
    private func render<Content: View>(_ content: Content, size: NSSize, to url: URL) throws {
        let host = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url, options: .atomic)
    }
}
