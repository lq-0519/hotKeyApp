import AppKit

/// 一个可选目标 App 的信息。
struct InstalledApp {
    let name: String
    let bundleIdentifier: String?
    let path: String
    let icon: NSImage
}

/// 枚举已安装 App,供设置窗口选择。
enum AppScanner {

    /// 常见 App 存放目录。
    private static var searchDirectories: [URL] {
        var dirs: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]
        if let home = FileManager.default.homeDirectoryForCurrentUser as URL? {
            dirs.append(home.appendingPathComponent("Applications", isDirectory: true))
        }
        return dirs
    }

    /// 合并安装目录、Dock 和正在运行的前台应用,按实际路径去重后排序。
    /// 通过后两种来源发现飞书会议等内置子应用,避免遍历所有安装包并列出后台 Helper。
    static func scan() -> [InstalledApp] {
        let fm = FileManager.default
        var seen = Set<String>()
        var apps: [InstalledApp] = []

        /// 各来源统一校验应用包并按解析符号链接后的路径去重。
        func appendApp(at url: URL, name: String? = nil) {
            guard let app = application(at: url, name: name),
                  seen.insert(app.path).inserted else { return }
            apps.append(app)
        }

        for dir in searchDirectories {
            // 递归普通文件夹(例如 Utilities),遇到应用包或其他包时停止下钻。
            guard let entries = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }

            for case let url as URL in entries where url.pathExtension.lowercased() == "app" {
                appendApp(at: url)
            }
        }

        // Dock 中固定或最近使用过的子应用在退出后仍可被选择。
        let dock = UserDefaults(suiteName: "com.apple.dock")
        for key in ["persistent-apps", "recent-apps"] {
            for tile in dock?.array(forKey: key) as? [[String: Any]] ?? [] {
                guard let data = tile["tile-data"] as? [String: Any] else { continue }
                let fileData = data["file-data"] as? [String: Any]
                let fileURL = (fileData?["_CFURLString"] as? String).flatMap { URL(string: $0) }
                let target = AppTarget(bundleIdentifier: data["bundle-identifier"] as? String,
                                       path: fileURL?.isFileURL == true ? fileURL?.path : nil)
                // 优先使用 Dock 上用户看到的名称,避免工具自身语言使“飞书会议”显示为英文。
                if let app = application(for: target, name: data["file-label"] as? String) {
                    if let index = apps.firstIndex(where: { $0.path == app.path }) {
                        apps[index] = app
                    } else if seen.insert(app.path).inserted {
                        apps.append(app)
                    }
                }
            }
        }

        for running in NSWorkspace.shared.runningApplications
            where running.activationPolicy == .regular && !running.isTerminated {
            if let url = running.bundleURL {
                appendApp(at: url, name: running.localizedName)
            }
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// 从本地 .app 读取真实标识、显示名称和图标,供自动发现与手动选择共用。
    /// 解析符号链接以合并同一应用的不同入口;拒绝普通文件夹和缺少可执行文件的包。
    static func application(at url: URL, name: String? = nil) -> InstalledApp? {
        guard url.isFileURL else { return nil }
        let url = url.resolvingSymlinksInPath().standardizedFileURL
        let fm = FileManager.default
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              let executable = bundle.executableURL,
              fm.isExecutableFile(atPath: executable.path) else { return nil }

        var displayName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if displayName.isEmpty {
            displayName = fm.displayName(atPath: url.path)
        }
        if displayName.lowercased().hasSuffix(".app") {
            displayName.removeLast(4)
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 18, height: 18)
        return InstalledApp(name: displayName,
                            bundleIdentifier: bundle.bundleIdentifier,
                            path: url.path,
                            icon: icon)
    }

    /// 恢复已有绑定或 Dock 记录指向的应用,包括未运行、未列入常规扫描的子应用。
    /// 优先保留仍有效且标识一致的原路径;应用升级使路径失效时,再按独立标识重新定位。
    /// name 可传入 Dock 的可见名称;未指定时沿用文件系统提供的显示名称。
    static func application(for target: AppTarget, name: String? = nil) -> InstalledApp? {
        let bundleID = target.bundleIdentifier.flatMap { $0.isEmpty ? nil : $0 }
        if let path = target.path, !path.isEmpty,
           let app = application(at: URL(fileURLWithPath: path), name: name),
           bundleID == nil || app.bundleIdentifier == bundleID {
            return app
        }
        if let bundleID = bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let app = application(at: url, name: name), app.bundleIdentifier == bundleID {
            return app
        }
        return nil
    }
}
