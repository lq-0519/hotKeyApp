import AppKit

/// 快捷键录制按钮:点击进入录制态,捕获下一个组合键。
final class ShortcutRecorderView: NSButton {

    /// 录制完成回调。
    var onCapture: ((KeyCombo) -> Void)?

    private(set) var keyCombo: KeyCombo? {
        didSet { updateTitle() }
    }

    private var isRecording = false {
        didSet { updateTitle() }
    }

    private var monitor: Any?

    init(keyCombo: KeyCombo?) {
        self.keyCombo = keyCombo
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        updateTitle()
    }

    private func updateTitle() {
        if isRecording {
            title = "按下快捷键…(Esc 取消)"
        } else if let combo = keyCombo {
            title = combo.displayString
        } else {
            title = "点击录制快捷键"
        }
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        // 局部监听:仅当本 App 在前台时捕获,避免影响全局。
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }
            return self.handle(event: event)
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func handle(event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }

        // 只处理 keyDown(flagsChanged 用来实时反馈可后续扩展)
        if event.type == .keyDown {
            // Esc 取消
            if event.keyCode == 53 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                stopRecording()
                return nil
            }
            guard let combo = KeyCombo.from(event: event) else { return nil }
            // 要求至少一个修饰键,避免误触全局
            guard combo.hasModifier else {
                NSSound.beep()
                return nil
            }
            keyCombo = combo
            stopRecording()
            onCapture?(combo)
            return nil // 吞掉事件
        }
        return nil
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}
