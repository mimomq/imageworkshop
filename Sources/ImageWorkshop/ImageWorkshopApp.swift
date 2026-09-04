import SwiftUI

@main
struct ImageWorkshopApp: App {
    @StateObject private var store = WorkspaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1_080, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加图片…") { store.openFiles() }
                    .keyboardShortcut("o")
                Button("添加文件夹…") { store.openFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .undoRedo) {
                Button("撤销上次更名") { store.undoLastRename() }
                    .keyboardShortcut("z")
                    .disabled(!store.canUndoRename)
            }
            CommandMenu("处理范围") {
                Button("仅处理表格所选行") { store.includeOnlySelection() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(store.selection.isEmpty)
                Button("切换所选行勾选") { store.toggleIncludedForSelection() }
                    .keyboardShortcut(" ", modifiers: [])
                    .disabled(store.selection.isEmpty)
                Divider()
                Button("全部勾选") { store.setAllIncluded(true) }
                Button("全部取消") { store.setAllIncluded(false) }
            }
        }
    }
}
