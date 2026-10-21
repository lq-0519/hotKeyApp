import AppKit

/// 负责:打开未运行的 App、激活已运行的 App、toggle 切回上一个 App。
/// 同时监听前台 App 变化以维护「上一个前台 App」。
final class AppLauncher {

    static let shared = AppLauncher()

    /// 当前前台 App(除本 App 外)。
    private var currentFrontApp: NSRunningApplication?
    /// 上一个前台 App(用于 toggle 切回)。
    private var previousFrontApp: NSRunningApplication?

    private init() {}

    // MARK: - 前台变化监听

    func startObserving() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self,
                       selector: #selector(activeAppChanged(_:)),
                       name: NSWorkspace.didActivateApplicationNotification,
                       object: nil)
        // 初始化当前前台
        currentFrontApp = NSWorkspace.shared.frontmostApplication
    }

    @objc private func activeAppChanged(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        // 忽略本 App(accessory,一般不会成为 frontmost,但保险起见)
        if app.processIdentifier == NSRunningApplication.current.processIdentifier {
            return
        }
        // 前台变化:旧的 current 变成 previous
        if app != currentFrontApp {
            previousFrontApp = currentFrontApp
            currentFrontApp = app
        }
    }

    // MARK: - 处理一次快捷键命中

    /// 根据 binding 执行:打开 / 激活 / toggle。
    func handle(binding: Binding, toggleEnabled: Bool) {
        let target = binding.target

        // 先尝试找到正在运行的目标实例。
        if let running = runningApp(for: target) {
            let isFront = running.isActive

            if isFront {
                // 已在最前台
                if toggleEnabled, let prev = previousFrontApp,
                   prev.processIdentifier != running.processIdentifier,
                   !prev.isTerminated {
                    prev.activate(options: [.activateAllWindows])
                }
                // toggle 关闭时:什么都不做
            } else {
                running.activate(options: [.activateAllWindows])
            }
            return
        }

        // 未运行 → 打开
        launch(target: target)
    }

    // MARK: - 定位运行中的 App

    private func runningApp(for target: AppTarget) -> NSRunningApplication? {
        // 1) 优先用 bundle id
        if let bid = target.bundleIdentifier, !bid.isEmpty {
            let matches = NSRunningApplication
                .runningApplications(withBundleIdentifier: bid)
            if let first = matches.first { return first }
        }
        // 2) 回退:按可执行 bundleURL 路径匹配
        if let path = target.path, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            for app in NSWorkspace.shared.runningApplications {
                if app.bundleURL == url { return app }
            }
        }
        return nil
    }

    // MARK: - 打开未运行的 App

    private func launch(target: AppTarget) {
        let url = resolveAppURL(for: target)
        guard let appURL = url else {
            NSLog("[hotKeyApp] 找不到目标 App: \(target)")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error = error {
                NSLog("[hotKeyApp] 打开 App 失败: \(error)")
            }
        }
    }

    /// 解析目标 App 的磁盘 URL:优先 bundle id,回退 path。
    private func resolveAppURL(for target: AppTarget) -> URL? {
        if let bid = target.bundleIdentifier, !bid.isEmpty,
           let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bid) {
            return url
        }
        if let path = target.path, !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                return url
            }
        }
        return nil
    }
}
