import AppKit
import Carbon.HIToolbox

/// 一个快捷键组合:虚拟键码 + 修饰键集合。
/// 负责:Codable 持久化、Carbon 掩码转换、可读显示串、从 NSEvent 录制。
struct KeyCombo: Codable, Equatable {

    /// 修饰键。rawValue 用于 JSON 持久化(稳定字符串)。
    enum Modifier: String, Codable, CaseIterable {
        case command
        case option
        case control
        case shift

        /// Carbon RegisterEventHotKey 所需的掩码位。
        var carbonMask: Int {
            switch self {
            case .command: return cmdKey
            case .option:  return optionKey
            case .control: return controlKey
            case .shift:   return shiftKey
            }
        }

        /// 菜单/显示用符号。
        var symbol: String {
            switch self {
            case .command: return "⌘"
            case .option:  return "⌥"
            case .control: return "⌃"
            case .shift:   return "⇧"
            }
        }

        /// 从 AppKit 的 NSEvent.ModifierFlags 提取。
        static func from(_ flags: NSEvent.ModifierFlags) -> Set<Modifier> {
            var result: Set<Modifier> = []
            if flags.contains(.command) { result.insert(.command) }
            if flags.contains(.option)  { result.insert(.option) }
            if flags.contains(.control) { result.insert(.control) }
            if flags.contains(.shift)   { result.insert(.shift) }
            return result
        }
    }

    /// 虚拟键码(Carbon kVK_* / NSEvent.keyCode)。
    var keyCode: UInt32
    /// 修饰键集合。
    var modifiers: Set<Modifier>

    // MARK: - Carbon

    /// 合并成 Carbon RegisterEventHotKey 需要的修饰掩码。
    var carbonModifierMask: UInt32 {
        var mask = 0
        for m in modifiers { mask |= m.carbonMask }
        return UInt32(mask)
    }

    // MARK: - 显示

    /// 稳定顺序的修饰符号串,例如 "⌃⌥⇧⌘"。
    private var modifierSymbols: String {
        // 按 ⌃⌥⇧⌘ 的惯用顺序排列
        let order: [Modifier] = [.control, .option, .shift, .command]
        return order.filter { modifiers.contains($0) }.map { $0.symbol }.joined()
    }

    /// 人类可读串,例如 "⌘⌥S"。
    var displayString: String {
        modifierSymbols + KeyCombo.keyName(for: keyCode)
    }

    /// 是否至少包含一个修饰键(纯字母键做全局热键容易误触,建议要求修饰键)。
    var hasModifier: Bool { !modifiers.isEmpty }

    // MARK: - 录制

    /// 从一次按键事件构造。返回 nil 表示该事件不适合作为快捷键(例如只有修饰键)。
    static func from(event: NSEvent) -> KeyCombo? {
        let mods = Modifier.from(event.modifierFlags)
        let code = UInt32(event.keyCode)
        // 忽略单独的修饰键 keyCode
        return KeyCombo(keyCode: code, modifiers: mods)
    }

    // MARK: - 键名映射

    /// 把虚拟键码转成可读名字。覆盖常用键,未知键回退为 "Key(码)"。
    static func keyName(for keyCode: UInt32) -> String {
        if let name = specialKeyNames[Int(keyCode)] {
            return name
        }
        if let name = characterKeyNames[Int(keyCode)] {
            return name
        }
        return "Key(\(keyCode))"
    }

    private static let characterKeyNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`"
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]
}
