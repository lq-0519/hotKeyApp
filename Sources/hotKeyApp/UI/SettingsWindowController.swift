import AppKit

/// 设置窗口:管理 bindings、全局开关。
/// 变更保存后通过 onConfigChanged 通知外部(AppDelegate)重注册热键。
final class SettingsWindowController: NSWindowController {

    /// 配置变更回调。
    var onConfigChanged: (() -> Void)?

    private var tableController: BindingTableController!
    private var tableView: NSTableView!
    private var toggleCheckbox: NSButton!
    private var loginCheckbox: NSButton!

    private var editSheet: BindingEditSheet?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "hotKeyApp 设置"
        window.center()
        self.init(window: window)
        buildUI()
        reloadFromConfig()
    }

    // MARK: - 构建 UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // 表格
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 24

        let c1 = NSTableColumn(identifier: BindingTableController.colName)
        c1.title = "名称"; c1.width = 180
        let c2 = NSTableColumn(identifier: BindingTableController.colShortcut)
        c2.title = "快捷键"; c2.width = 140
        let c3 = NSTableColumn(identifier: BindingTableController.colTarget)
        c3.title = "目标 App"; c3.width = 260
        table.addTableColumn(c1)
        table.addTableColumn(c2)
        table.addTableColumn(c3)
        table.doubleAction = #selector(editSelected)
        table.target = self

        scroll.documentView = table
        content.addSubview(scroll)
        self.tableView = table
        self.tableController = BindingTableController(bindings: [], tableView: table)

        // 底部按钮栏
        let addBtn = makeButton("添加", #selector(addBinding))
        let editBtn = makeButton("编辑", #selector(editSelected))
        let delBtn = makeButton("删除", #selector(deleteSelected))

        let btnStack = NSStackView(views: [addBtn, editBtn, delBtn])
        btnStack.orientation = .horizontal
        btnStack.spacing = 8
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(btnStack)

        // 开关
        toggleCheckbox = NSButton(checkboxWithTitle: "再按一次快捷键切回上一个 App",
                                  target: self, action: #selector(toggleChanged))
        toggleCheckbox.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(toggleCheckbox)

        loginCheckbox = NSButton(checkboxWithTitle: "开机自启动",
                                 target: self, action: #selector(loginChanged))
        loginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(loginCheckbox)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: btnStack.topAnchor, constant: -12),

            btnStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            btnStack.bottomAnchor.constraint(equalTo: toggleCheckbox.topAnchor, constant: -14),

            toggleCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            toggleCheckbox.bottomAnchor.constraint(equalTo: loginCheckbox.topAnchor, constant: -8),

            loginCheckbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            loginCheckbox.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
    }

    private func makeButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }

    // MARK: - 载入 / 刷新

    private func reloadFromConfig() {
        let cfg = ConfigStore.shared.config
        tableController.setBindings(cfg.bindings)
        toggleCheckbox.state = cfg.toggleEnabled ? .on : .off
        // 登录项以系统真实状态为准
        loginCheckbox.state = LoginItemManager.isEnabled ? .on : .off
    }

    // MARK: - 操作

    @objc private func addBinding() {
        presentEdit(for: nil)
    }

    @objc private func editSelected() {
        guard let idx = tableController.selectedIndex else { return }
        presentEdit(for: tableController.bindings[idx])
    }

    @objc private func deleteSelected() {
        guard let idx = tableController.selectedIndex else { return }
        let target = tableController.bindings[idx]
        ConfigStore.shared.update { cfg in
            cfg.bindings.removeAll { $0.id == target.id }
        }
        reloadFromConfig()
        onConfigChanged?()
    }

    @objc private func toggleChanged() {
        let on = (toggleCheckbox.state == .on)
        ConfigStore.shared.update { $0.toggleEnabled = on }
        onConfigChanged?()
    }

    @objc private func loginChanged() {
        let on = (loginCheckbox.state == .on)
        let ok = LoginItemManager.setEnabled(on)
        if ok {
            ConfigStore.shared.update { $0.launchAtLogin = on }
        } else {
            // 失败则回退勾选状态
            loginCheckbox.state = LoginItemManager.isEnabled ? .on : .off
        }
    }

    // MARK: - 编辑 sheet

    private func presentEdit(for binding: Binding?) {
        guard let window = window else { return }
        let sheet = BindingEditSheet(binding: binding)
        sheet.onSave = { [weak self] result in
            guard let self = self else { return }
            self.applyEdit(original: binding, edited: result)
        }
        editSheet = sheet
        window.beginSheet(sheet.window!) { [weak self] _ in
            self?.editSheet = nil
        }
    }

    /// 校验并保存单条编辑结果。
    private func applyEdit(original: Binding?, edited: Binding) {
        // 快捷键冲突检查(排除自身)
        let conflict = ConfigStore.shared.config.bindings.contains { existing in
            existing.id != edited.id
                && existing.keyCombo == edited.keyCombo
        }
        if conflict {
            alert("该快捷键已被其他条目占用,请换一个。")
            return
        }

        ConfigStore.shared.update { cfg in
            if let idx = cfg.bindings.firstIndex(where: { $0.id == edited.id }) {
                cfg.bindings[idx] = edited
            } else {
                cfg.bindings.append(edited)
            }
        }
        reloadFromConfig()
        onConfigChanged?()
    }

    private func alert(_ message: String) {
        let a = NSAlert()
        a.messageText = message
        a.alertStyle = .warning
        a.addButton(withTitle: "好")
        if let window = window {
            a.beginSheetModal(for: window, completionHandler: nil)
        } else {
            a.runModal()
        }
    }

    // MARK: - 展示

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
