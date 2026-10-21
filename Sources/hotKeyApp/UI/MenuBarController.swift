import AppKit

/// 菜单栏图标与菜单。
final class MenuBarController {

    private let statusItem: NSStatusItem
    private let settingsController: SettingsWindowController

    /// 启用/禁用全部快捷键的回调。
    var onToggleEnabled: ((Bool) -> Void)?

    /// 全局启用状态。
    private var hotkeysEnabled = true

    init(settingsController: SettingsWindowController) {
        self.settingsController = settingsController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        buildMenu()
    }

    private func configureButton() {
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "keyboard",
                              accessibilityDescription: "hotKeyApp")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "hotKeyApp"
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "设置…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "启用全部快捷键",
                                    action: #selector(toggleEnabled),
                                    keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = hotkeysEnabled ? .on : .off
        toggleItem.tag = 100
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 hotKeyApp",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        hotkeysEnabled.toggle()
        sender.state = hotkeysEnabled ? .on : .off
        onToggleEnabled?(hotkeysEnabled)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
