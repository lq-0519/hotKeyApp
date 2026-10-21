import AppKit

// 入口:手动创建 NSApplication 并装配 AppDelegate。
// 使用 .accessory 激活策略 —— 无 Dock 图标,仅菜单栏常驻。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
