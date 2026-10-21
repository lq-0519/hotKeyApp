import AppKit
import Carbon.HIToolbox

/// 全局快捷键管理:基于 Carbon RegisterEventHotKey。
/// - 不需要辅助功能权限。
/// - 进程内安装一次 EventHandler,按 hotKeyID 路由到对应回调。
final class HotKeyManager {

    static let shared = HotKeyManager()

    /// 命中回调:参数为该热键对应的 binding id。
    var onHotKey: ((String) -> Void)?

    /// 已注册的热键引用,便于注销。
    private struct Registered {
        let ref: EventHotKeyRef
        let bindingID: String
    }

    /// hotKeyID.id -> 注册信息
    private var registered: [UInt32: Registered] = [:]
    /// 递增的 hotKeyID,避免冲突。
    private var nextID: UInt32 = 1

    private var handlerInstalled = false
    /// 四字符签名 'HTKY'
    private let signature: OSType = 0x48544B59

    private init() {}

    // MARK: - 安装 EventHandler

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        // C 回调:通过 userData 拿到 self,再取出 hotKeyID 路由。
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let eventRef = eventRef, let userData = userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let manager = Unmanaged<HotKeyManager>
                    .fromOpaque(userData).takeUnretainedValue()

                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return status }
                manager.dispatch(hotKeyRawID: hkID.id)
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            nil
        )
        handlerInstalled = true
    }

    /// 主线程分发到业务回调。
    private func dispatch(hotKeyRawID: UInt32) {
        guard let reg = registered[hotKeyRawID] else { return }
        let bindingID = reg.bindingID
        DispatchQueue.main.async { [weak self] in
            self?.onHotKey?(bindingID)
        }
    }

    // MARK: - 注册 / 注销

    /// 用一组 binding 全量重注册(先清空再注册)。
    /// 返回注册失败的 binding id 列表(例如键位被系统占用)。
    @discardableResult
    func reload(bindings: [Binding]) -> [String] {
        installHandlerIfNeeded()
        unregisterAll()

        var failed: [String] = []
        for binding in bindings {
            if !register(binding) {
                failed.append(binding.id)
            }
        }
        return failed
    }

    /// 注册单条 binding。成功返回 true。
    private func register(_ binding: Binding) -> Bool {
        let combo = binding.keyCombo
        let myID = nextID
        nextID &+= 1

        let hotKeyID = EventHotKeyID(signature: signature, id: myID)
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifierMask,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref = ref else {
            NSLog("[hotKeyApp] 注册热键失败 (\(combo.displayString)) status=\(status)")
            return false
        }
        registered[myID] = Registered(ref: ref, bindingID: binding.id)
        return true
    }

    func unregisterAll() {
        for (_, reg) in registered {
            UnregisterEventHotKey(reg.ref)
        }
        registered.removeAll()
    }
}
