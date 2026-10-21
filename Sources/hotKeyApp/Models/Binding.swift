import Foundation

/// 快捷键触发的目标 App。
struct AppTarget: Codable, Equatable {
    /// 优先用 bundle id 定位(最稳)。
    var bundleIdentifier: String?
    /// 兜底:App 路径。
    var path: String?

    var isValid: Bool {
        (bundleIdentifier?.isEmpty == false) || (path?.isEmpty == false)
    }
}

/// 单条绑定:一个快捷键 → 一个目标 App。
struct Binding: Codable, Equatable, Identifiable {
    var id: String
    /// 展示名称(默认用 App 名)。
    var name: String
    var keyCombo: KeyCombo
    var target: AppTarget

    init(id: String = UUID().uuidString,
         name: String,
         keyCombo: KeyCombo,
         target: AppTarget) {
        self.id = id
        self.name = name
        self.keyCombo = keyCombo
        self.target = target
    }
}

/// 顶层配置(对应 config.json)。
struct AppConfig: Codable, Equatable {
    var version: Int
    var toggleEnabled: Bool
    var launchAtLogin: Bool
    var bindings: [Binding]

    static let currentVersion = 1

    /// 默认空配置。
    static var `default`: AppConfig {
        AppConfig(version: currentVersion,
                  toggleEnabled: true,
                  launchAtLogin: false,
                  bindings: [])
    }
}
