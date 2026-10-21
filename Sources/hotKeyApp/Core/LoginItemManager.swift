import Foundation
import ServiceManagement

/// 开机自启管理,基于 SMAppService.mainApp(macOS 13+)。
enum LoginItemManager {

    /// 当前是否已启用自启。
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 设置自启开关。返回是否成功。
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("[hotKeyApp] 设置开机自启失败: \(error)")
            return false
        }
    }
}
