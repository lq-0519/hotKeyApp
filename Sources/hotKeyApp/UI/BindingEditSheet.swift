import AppKit
import UniformTypeIdentifiers

/// 编辑/新增单条 binding 的 sheet 窗口。
final class BindingEditSheet: NSWindowController {

    /// 保存回调,回传编辑后的 binding。
    var onSave: ((Binding) -> Void)?

    private let originalID: String
    private var capturedCombo: KeyCombo?
    private var installedApps: [InstalledApp] = []

    private var nameField: NSTextField!
    private var recorder: ShortcutRecorderView!
    private var appPopup: NSPopUpButton!

    init(binding: Binding?) {
        self.originalID = binding?.id ?? UUID().uuidString
        self.capturedCombo = binding?.keyCombo

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 220),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        super.init(window: window)
        window.title = binding == nil ? "添加快捷键" : "编辑快捷键"
        buildUI(binding: binding)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(binding: Binding?) {
        guard let content = window?.contentView else { return }

        let nameLabel = NSTextField(labelWithString: "名称:")
        nameField = NSTextField(string: binding?.name ?? "")
        nameField.placeholderString = "例如:打开 Safari"

        let keyLabel = NSTextField(labelWithString: "快捷键:")
        recorder = ShortcutRecorderView(keyCombo: binding?.keyCombo)
        recorder.onCapture = { [weak self] combo in
            self?.capturedCombo = combo
        }

        let appLabel = NSTextField(labelWithString: "目标 App:")
        appPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        loadApps(selecting: binding?.target)

        // 选择 App 时自动填充名称(若名称为空)
        appPopup.target = self
        appPopup.action = #selector(appSelected)

        let browseBtn = NSButton(title: "选择其他…", target: self, action: #selector(chooseApplication))
        browseBtn.bezelStyle = .rounded
        let appSelection = NSStackView(views: [appPopup, browseBtn])
        appSelection.orientation = .horizontal
        appSelection.spacing = 8
        appPopup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        browseBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(save))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        let cancelBtn = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"

        let btnStack = NSStackView(views: [cancelBtn, saveBtn])
        btnStack.orientation = .horizontal
        btnStack.spacing = 10

        // 用 grid 布局对齐
        let grid = NSGridView(views: [
            [nameLabel, nameField],
            [keyLabel, recorder],
            [appLabel, appSelection]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 14
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        content.addSubview(grid)

        btnStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(btnStack)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            btnStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            btnStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),

            nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            appPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
    }

    /// 首次加载应用列表,并补回当前绑定的目标,防止未运行的手动选择应用在编辑时丢失。
    private func loadApps(selecting target: AppTarget?) {
        installedApps = AppScanner.scan()
        if let target = target, let app = AppScanner.application(for: target),
           !installedApps.contains(where: { $0.path == app.path }) {
            installedApps.append(app)
        }
        reloadAppPopup(selecting: target)
    }

    /// 重建列表时先按原路径、再按独立标识恢复选择;失效目标保持未选中,避免误存为其他应用。
    private func reloadAppPopup(selecting target: AppTarget?) {
        installedApps.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        appPopup.removeAllItems()
        for app in installedApps {
            let item = NSMenuItem(title: app.name, action: nil, keyEquivalent: "")
            item.image = app.icon
            item.toolTip = app.path
            appPopup.menu?.addItem(item)
        }
        if let target = target {
            let resolvedPath = AppScanner.application(for: target)?.path
            let pathIndex = installedApps.firstIndex { $0.path == resolvedPath }
            let bundleIndex = installedApps.firstIndex {
                target.bundleIdentifier?.isEmpty == false && $0.bundleIdentifier == target.bundleIdentifier
            }
            if let idx = pathIndex ?? bundleIndex {
                appPopup.selectItem(at: idx)
            } else {
                appPopup.select(nil)
            }
        }
    }

    /// 允许选择常规列表外的 .app,包括通过“前往文件夹”进入安装包内部后选择子应用。
    /// 取消不改变当前目标;确认后复用同一校验与去重逻辑,仍保存子应用自身的标识和路径。
    @objc private func chooseApplication() {
        guard let window = window else { return }
        let panel = NSOpenPanel()
        panel.title = "选择应用"
        panel.prompt = "选择"
        panel.message = "可以按 ⇧⌘G 输入文件夹路径，选择安装包内部的子应用。"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            guard let app = AppScanner.application(at: url) else {
                let alert = NSAlert()
                alert.messageText = "无法使用这个应用"
                alert.informativeText = "请选择包含可执行文件的有效 .app 应用。"
                alert.beginSheetModal(for: window, completionHandler: nil)
                return
            }
            if !self.installedApps.contains(where: { $0.path == app.path }) {
                self.installedApps.append(app)
            }
            self.reloadAppPopup(selecting: AppTarget(bundleIdentifier: app.bundleIdentifier, path: app.path))
            self.appSelected()
        }
    }

    @objc private func appSelected() {
        let idx = appPopup.indexOfSelectedItem
        guard idx >= 0, idx < installedApps.count else { return }
        if nameField.stringValue.trimmingCharacters(in: .whitespaces).isEmpty {
            nameField.stringValue = installedApps[idx].name
        }
    }

    @objc private func save() {
        guard let combo = capturedCombo else {
            beep("请先录制快捷键")
            return
        }
        let idx = appPopup.indexOfSelectedItem
        guard idx >= 0, idx < installedApps.count else {
            beep("请选择目标 App")
            return
        }
        let app = installedApps[idx]
        var name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { name = app.name }

        let binding = Binding(
            id: originalID,
            name: name,
            keyCombo: combo,
            target: AppTarget(bundleIdentifier: app.bundleIdentifier, path: app.path))

        endSheet()
        onSave?(binding)
    }

    @objc private func cancel() {
        endSheet()
    }

    private func endSheet() {
        guard let window = window, let sheetParent = window.sheetParent else { return }
        sheetParent.endSheet(window)
    }

    private func beep(_ msg: String) {
        NSSound.beep()
        NSLog("[hotKeyApp] \(msg)")
    }
}
