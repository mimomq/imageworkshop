import SwiftUI

struct ResizeInspector: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var saveRequest: PresetSaveRequest?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("实时预览") {
                    if let entry = store.previewEntry {
                        ResizeLivePreview(entry: entry, options: store.resizeOptions)
                    } else {
                        Label("选择或添加图片后显示预览", systemImage: "photo")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("快捷编辑") {
                    ResizePresetControls(saveRequest: $saveRequest)
                }

                Section("目标尺寸") {
                    Picker("尺寸方式", selection: $store.resizeOptions.dimensionMode) {
                        ForEach(ResizeDimensionMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)

                    switch store.resizeOptions.dimensionMode {
                    case .longEdge:
                        CompactIntegerStepper(
                            title: "长边像素",
                            value: $store.resizeOptions.longEdge,
                            range: 1...50_000
                        )
                        Label("宽高比例已锁定，短边会自动按原图比例计算", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case .widthAndHeight:
                        CompactIntegerStepper(
                            title: "宽度",
                            value: $store.resizeOptions.width,
                            range: 1...50_000
                        )
                        CompactIntegerStepper(
                            title: "高度",
                            value: $store.resizeOptions.height,
                            range: 1...50_000
                        )
                        Picker("宽高处理", selection: $store.resizeOptions.strategy) {
                            Text("锁定比例并适应范围").tag(ResizeStrategy.fit)
                            Text("锁定比例并填充裁剪").tag(ResizeStrategy.fill)
                            Text("不锁定比例，精确宽高").tag(ResizeStrategy.stretch)
                        }
                        Text(store.resizeOptions.strategy.help)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case .percentage:
                        HStack {
                            Slider(value: percentBinding, in: 1...400, step: 1)
                            Text("\(store.resizeOptions.percent)%")
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                        Label("宽高比例已锁定", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("小图不放大", isOn: $store.resizeOptions.doNotEnlarge)
                }

                Section("输出") {
                    Picker("图片格式", selection: $store.resizeOptions.format) {
                        ForEach(OutputFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if store.resizeOptions.format == .jpeg || store.resizeOptions.format == .heic {
                        HStack {
                            Text("质量")
                            Slider(value: $store.resizeOptions.quality, in: 0.1...1)
                            Text("\(Int(store.resizeOptions.quality * 100))")
                                .monospacedDigit()
                                .frame(width: 30)
                        }
                    }
                    LabeledContent("保存到") {
                        Button(outputTitle, action: store.chooseOutputDirectory)
                            .lineLimit(1)
                    }
                    Text("输出始终保持原文件名；同名图片自动用最新结果覆盖。未选择目录时保存到“图匠输出”。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("注意：如果选择原图所在文件夹，同名原图将被替换。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("恢复默认") { store.resizeOptions = ResizeOptions() }
                Spacer()
                Button("开始处理", action: store.processImages)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.entries.isEmpty || store.isWorking)
            }
            .padding(14)
        }
        .sheet(item: $saveRequest) { request in
            PresetNameSheet(request: request)
        }
    }

    private var percentBinding: Binding<Double> {
        Binding(
            get: { Double(store.resizeOptions.percent) },
            set: { store.resizeOptions.percent = Int($0) }
        )
    }

    private var outputTitle: String {
        store.resizeOptions.outputDirectory?.lastPathComponent ?? "自动"
    }
}
