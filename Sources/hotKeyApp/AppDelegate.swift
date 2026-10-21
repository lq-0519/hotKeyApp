import AppKit

/// 装配各模块并处理生命周期。
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController!
    private var settingsController: SettingsWindowController!

    /// 全局启用开关(菜单栏可切换)。
    private var hotkeysEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1) 前台变化监听(toggle 依赖)
        AppLauncher.shared.startObserving()

        // 2) 设置窗口
        settingsController = SettingsWindowController()
        settingsController.onConfigChanged = { [weak self] in
            self?.reloadHotKeys()
        }

        // 3) 菜单栏
        menuBarController = MenuBarController(settingsController: settingsController)
        menuBarController.onToggleEnabled = { [weak self] enabled in
            self?.hotkeysEnabled = enabled
            self?.reloadHotKeys()
        }

        // 4) 热键命中处理
        HotKeyManager.shared.onHotKey = { [weak self] bindingID in
            self?.handleHotKey(bindingID: bindingID)
        }

        // 5) 首次加载热键
        reloadHotKeys()

        // 6) 若无任何绑定,首启直接打开设置窗口,便于上手
        if ConfigStore.shared.config.bindings.isEmpty {
            settingsController.show()
        }
    }

    // MARK: - 热键

    /// 根据当前配置与启用状态重注册全部热键。
    private func reloadHotKeys() {
        guard hotkeysEnabled else {
            HotKeyManager.shared.unregisterAll()
            return
        }
        let bindings = ConfigStore.shared.config.bindings
        let failed = HotKeyManager.shared.reload(bindings: bindings)
        if !failed.isEmpty {
            NSLog("[hotKeyApp] 以下绑定注册失败(可能键位被占用): \(failed)")
        }
    }

    private func handleHotKey(bindingID: String) {
        let cfg = ConfigStore.shared.config
        guard let binding = cfg.bindings.first(where: { $0.id == bindingID }) else {
            return
        }
        AppLauncher.shared.handle(binding: binding, toggleEnabled: cfg.toggleEnabled)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregisterAll()
    }
}
