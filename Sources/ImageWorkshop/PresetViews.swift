import SwiftUI

enum PresetKind {
    case rename
    case resize
}

struct PresetSaveRequest: Identifiable {
    let id = UUID()
    let kind: PresetKind
    let suggestedName: String
}

struct PresetNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkspaceStore
    let request: PresetSaveRequest
    @State private var name: String

    init(request: PresetSaveRequest) {
        self.request = request
        _name = State(initialValue: request.suggestedName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("保存快捷方案")
                    .font(.title2.weight(.semibold))
                Text("保存当前全部参数；使用相同名称保存会更新原方案。")
                    .foregroundStyle(.secondary)
            }

            TextField("方案名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func save() {
        switch request.kind {
        case .rename: store.saveRenamePreset(named: name)
        case .resize: store.saveResizePreset(named: name)
        }
        dismiss()
    }
}

struct RenamePresetControls: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Binding var saveRequest: PresetSaveRequest?

    var body: some View {
        HStack {
            Menu {
                if store.renamePresets.isEmpty {
                    Text("暂无已保存方案")
                } else {
                    ForEach(store.renamePresets) { preset in
                        Button(preset.name) { store.apply(renamePreset: preset) }
                    }
                }
            } label: {
                Label("载入方案", systemImage: "bolt.fill")
            }
            Button {
                saveRequest = PresetSaveRequest(
                    kind: .rename,
                    suggestedName: "更名方案 \(store.renamePresets.count + 1)"
                )
            } label: {
                Label("保存当前", systemImage: "plus")
            }
            .labelStyle(.titleAndIcon)
        }
        if !store.renamePresets.isEmpty {
            Menu("删除已存方案…") {
                ForEach(store.renamePresets) { preset in
                    Button(preset.name, role: .destructive) { store.delete(renamePreset: preset) }
                }
            }
            .font(.caption)
        }
    }
}

struct ResizePresetControls: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Binding var saveRequest: PresetSaveRequest?

    var body: some View {
        HStack {
            Menu {
                if store.resizePresets.isEmpty {
                    Text("暂无已保存方案")
                } else {
                    ForEach(store.resizePresets) { preset in
                        Button(preset.name) { store.apply(resizePreset: preset) }
                    }
                }
            } label: {
                Label("载入方案", systemImage: "bolt.fill")
            }
            Button {
                saveRequest = PresetSaveRequest(
                    kind: .resize,
                    suggestedName: suggestedResizeName
                )
            } label: {
                Label("保存当前", systemImage: "plus")
            }
            .labelStyle(.titleAndIcon)
        }
        Text("保存尺寸方式、比例、格式、质量与输出位置。")
            .font(.caption)
            .foregroundStyle(.secondary)
        if !store.resizePresets.isEmpty {
            Menu("删除已存方案…") {
                ForEach(store.resizePresets) { preset in
                    Button(preset.name, role: .destructive) { store.delete(resizePreset: preset) }
                }
            }
            .font(.caption)
        }
    }

    private var suggestedResizeName: String {
        let options = store.resizeOptions
        let size: String
        switch options.dimensionMode {
        case .longEdge: size = "长边 \(options.longEdge)"
        case .widthAndHeight: size = "\(options.width)×\(options.height)"
        case .percentage: size = "\(options.percent)%"
        }
        return "\(size) \(options.format.rawValue)"
    }
}
