import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            List(WorkspaceSection.allCases, selection: $store.section) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
                    .padding(.vertical, 5)
            }
            .navigationTitle("图匠")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            HSplitView {
                fileArea
                    .frame(minWidth: 560)
                Group {
                    switch store.section {
                    case .rename: RenameInspector()
                    case .resize: ResizeInspector()
                    }
                }
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 390)
            }
            .navigationTitle(store.section.rawValue)
        }
        .toolbar { toolbar }
        .alert("图匠", isPresented: $store.showMessage) {
            Button("好") { }
        } message: {
            Text(store.message ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: store.openFiles) { Label("添加图片", systemImage: "photo.badge.plus") }
            Button(action: store.openFolder) { Label("添加文件夹", systemImage: "folder.badge.plus") }
            Button(action: store.removeSelected) { Label("移除所选", systemImage: "minus") }
                .disabled(store.selection.isEmpty)
            Button(action: store.clear) { Label("清空", systemImage: "trash") }
                .disabled(store.entries.isEmpty)
        }
    }

    private var fileArea: some View {
        VStack(spacing: 0) {
            if store.entries.isEmpty {
                dropZone
            } else {
                fileTable
                Divider()
                statusBar
            }
        }
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else { url = item as? URL }
                    if let url { Task { @MainActor in store.add(urls: [url]) } }
                }
            }
            return true
        }
    }

    private var dropZone: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.stack")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("把图片或文件夹拖到这里")
                    .font(.title3.weight(.semibold))
                Text("支持 JPG、PNG、HEIC、TIFF、GIF、BMP 与 WebP")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("选择图片…", action: store.openFiles)
                    .buttonStyle(.borderedProminent)
                Button("选择文件夹…", action: store.openFolder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var fileTable: some View {
        Table(store.entries, selection: tableSelection) {
            TableColumn("") { entry in
                Toggle("", isOn: includedBinding(for: entry.id))
                    .labelsHidden()
            }
            .width(28)
            TableColumn("原文件名") { entry in
                HStack(spacing: 8) {
                    AsyncThumbnail(url: entry.url)
                    Text(entry.fileName).lineLimit(1)
                }
            }
            .width(min: 180, ideal: 240)
            TableColumn(store.section == .rename ? "预览名称" : "输出尺寸") { entry in
                if store.section == .rename {
                    let result = store.preview(for: entry)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.fileName).lineLimit(1)
                        if let warning = result.warning {
                            Text(warning).font(.caption).foregroundStyle(.red)
                        }
                    }
                } else {
                    Text(store.targetDimensions(for: entry))
                }
            }
            .width(min: 150, ideal: 210)
            TableColumn("原尺寸") { entry in Text(entry.dimensionsText).monospacedDigit() }
                .width(105)
            TableColumn("大小") { entry in Text(entry.sizeText) }
                .width(75)
            TableColumn("状态") { entry in Text(entry.status).lineLimit(1).foregroundStyle(.secondary) }
                .width(min: 90, ideal: 150)
        }
    }

    private var statusBar: some View {
        VStack(spacing: 3) {
            HStack {
                Menu {
                    Button("全部勾选") { store.setAllIncluded(true) }
                    Button("全部取消") { store.setAllIncluded(false) }
                } label: {
                    Text("已勾选 \(store.includedEntries.count) / \(store.entries.count) 张")
                }
                if !store.selection.isEmpty {
                    Button("仅处理所选（⌘↩︎）") { store.includeOnlySelection() }
                        .buttonStyle(.borderless)
                    Button("切换所选勾选（Space）") { store.toggleIncludedForSelection() }
                        .buttonStyle(.borderless)
                }
                if store.isWorking {
                    ProgressView(value: store.progress)
                        .frame(width: 140)
                }
                Spacer()
            }
            HStack {
                Text("多选：按住 ⌘ 依次点击每段起止行；Shift 点击连续范围。处理前按 ⌘↩︎。")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(minHeight: 48)
    }

    private var tableSelection: Binding<Set<UUID>> {
        Binding(
            get: { store.selection },
            set: { proposed in
                store.updateTableSelection(
                    proposed,
                    commandPressed: NSEvent.modifierFlags.contains(.command)
                )
            }
        )
    }

    private func includedBinding(for id: UUID) -> Binding<Bool> {
        Binding {
            store.entries.first(where: { $0.id == id })?.isIncluded ?? false
        } set: { value in
            if let index = store.entries.firstIndex(where: { $0.id == id }) {
                store.entries[index].isIncluded = value
            }
        }
    }
}

private struct AsyncThumbnail: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
