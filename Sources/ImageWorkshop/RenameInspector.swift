import SwiftUI

struct RenameInspector: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var saveRequest: PresetSaveRequest?
    private let commonExtensions = ["jpg", "png", "heic", "webp", "tiff"]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("快捷方案") {
                    RenamePresetControls(saveRequest: $saveRequest)
                }

                Section("命名模板") {
                    InspectorTextField(
                        title: "命名模板",
                        prompt: "例如 {name}_{index}",
                        text: $store.renameOptions.template
                    )
                    Text("可用变量：{name} {ext} {parent} {index} {date} {width} {height}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section("添加") {
                    InspectorTextField(title: "前缀", prompt: "文件名前添加", text: $store.renameOptions.prefix)
                    InspectorTextField(title: "后缀", prompt: "文件名后添加", text: $store.renameOptions.suffix)
                }

                Section("插入字符") {
                    Toggle("启用插入", isOn: $store.renameOptions.insertEnabled)
                    if store.renameOptions.insertEnabled {
                        InspectorTextField(title: "插入字符", prompt: "要插入的内容", text: $store.renameOptions.insertText)
                        CompactIntegerStepper(
                            title: "在第几位后插入",
                            value: $store.renameOptions.insertAfterPosition,
                            range: 0...10_000
                        )
                        Text("位置 0 表示插入到文件名最前面，超出长度时插到末尾。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("替换") {
                    InspectorTextField(title: "查找内容", prompt: "查找内容", text: $store.renameOptions.find)
                    InspectorTextField(title: "替换为", prompt: "替换为", text: $store.renameOptions.replacement)
                    Toggle("使用正则表达式", isOn: $store.renameOptions.useRegex)
                }

                Section("整体") {
                    Picker("文件名大小写", selection: $store.renameOptions.caseRule) {
                        ForEach(NameCaseRule.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("更改扩展名", isOn: $store.renameOptions.changeExtension)
                    if store.renameOptions.changeExtension {
                        HStack(spacing: 6) {
                            ForEach(commonExtensions, id: \.self) { ext in
                                Button(ext.uppercased()) { store.renameOptions.newExtension = ext }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(store.renameOptions.newExtension == ext ? .accentColor : .secondary)
                                    .accessibilityLabel("扩展名 \(ext)")
                            }
                        }
                        Text("已选择：.\(store.renameOptions.newExtension)；这里只修改扩展名，不转换图片编码。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("序号 {index}") {
                    CompactIntegerStepper(
                        title: "起始",
                        value: $store.renameOptions.sequenceStart,
                        range: 0...999_999
                    )
                    CompactIntegerStepper(
                        title: "增量",
                        value: $store.renameOptions.sequenceStep,
                        range: 1...10_000
                    )
                    CompactIntegerStepper(
                        title: "位数",
                        value: $store.renameOptions.sequenceDigits,
                        range: 1...12
                    )
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("恢复默认") { store.renameOptions = RenameOptions() }
                Spacer()
                Button("撤销", action: store.undoLastRename)
                    .disabled(!store.canUndoRename)
                Button("应用更名", action: store.applyRename)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.entries.isEmpty || store.isWorking)
            }
            .padding(14)
        }
        .sheet(item: $saveRequest) { request in
            PresetNameSheet(request: request)
        }
    }
}

struct InspectorTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text, prompt: Text(prompt))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(title)
    }
}

struct CompactIntegerStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 12)
            TextField(title, value: $value, format: .number)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 84)
                .accessibilityLabel(title)
            Stepper(title, value: $value, in: range)
                .labelsHidden()
        }
    }
}
