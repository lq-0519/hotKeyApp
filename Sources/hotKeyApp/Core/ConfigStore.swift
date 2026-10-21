import Foundation

/// 配置读写:JSON 持久化到
/// ~/Library/Application Support/hotKeyApp/config.json
final class ConfigStore {

    static let shared = ConfigStore()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// 内存中的当前配置。修改后调用 save() 落盘。
    private(set) var config: AppConfig

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        config = AppConfig.default
        config = load()
    }

    // MARK: - 路径

    var configDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory,
                                    in: .userDomainMask).first!
        return base.appendingPathComponent("hotKeyApp", isDirectory: true)
    }

    var configFile: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    // MARK: - 读

    /// 读取配置。文件不存在或损坏时返回默认配置(不崩溃,T14)。
    func load() -> AppConfig {
        guard fileManager.fileExists(atPath: configFile.path) else {
            return AppConfig.default
        }
        do {
            let data = try Data(contentsOf: configFile)
            let loaded = try decoder.decode(AppConfig.self, from: data)
            return loaded
        } catch {
            NSLog("[hotKeyApp] 配置读取失败,降级为默认配置: \(error)")
            return AppConfig.default
        }
    }

    // MARK: - 写

    @discardableResult
    func save() -> Bool {
        do {
            try fileManager.createDirectory(at: configDirectory,
                                            withIntermediateDirectories: true)
            let data = try encoder.encode(config)
            try data.write(to: configFile, options: [.atomic])
            return true
        } catch {
            NSLog("[hotKeyApp] 配置保存失败: \(error)")
            return false
        }
    }

    // MARK: - 变更

    func update(_ mutate: (inout AppConfig) -> Void) {
        mutate(&config)
        save()
    }

    func replace(with newConfig: AppConfig) {
        config = newConfig
        save()
    }
}
