# hotKeyApp

给常用 Mac 应用分配全局快捷键，随时打开或切换到目标应用，减少在 Dock、启动台和多个窗口之间寻找应用的时间。

例如，把 `⌘⌥S` 绑定到 Safari：Safari 没有运行时启动它；已经运行时直接切到前台；开启“再次按下切回”后，再按同一个快捷键即可返回上一个应用。

## 主要功能

- 自定义多组全局快捷键，使用图形界面录制按键和选择应用。
- 自动启动未运行的应用，或激活已经运行的应用。
- 可选的再次按下切回功能，方便在两个应用之间往返。
- 从已安装应用、Dock 和正在运行的应用中选择目标，也支持手动选择 `.app`。
- 支持“飞书会议”等拥有独立应用标识的子应用。
- 菜单栏一键暂停或恢复所有快捷键，配置会保留。
- 可设置登录后自动启动；日常运行只显示菜单栏图标。

## 使用方法

1. 启动 `hotKeyApp.app`，点击菜单栏的键盘图标，打开“设置…”。
2. 点击“添加”，录制含修饰键的快捷键，例如 `⌘⌥S`。
3. 选择目标应用并保存。
4. 在任意应用中按下快捷键，打开或激活对应应用。
5. 按需开启再次按下切回和开机自启动。

首次启动且没有绑定时，设置窗口会自动打开。可以为浏览器、编辑器、聊天软件等分别设置快捷键。

## 环境与构建

- macOS 13 或更新版本。
- Swift 5.9 或更新版本及 Xcode Command Line Tools。
- 使用系统框架，无第三方包依赖；通过 Carbon 注册热键，无需辅助功能权限。

在项目目录执行：

```bash
./build_app.sh
```

构建结果位于 `build/hotKeyApp.app`。构建并启动可使用：

```bash
./build_app.sh --run
```

当前脚本保留作者本机的固定安装路径和代码签名身份。签名证书为 `InputHoldSwitcher Local Code Signing`，应用标识为 `com.hotkeyapp.launcher`；缺少原证书时脚本会停止。其他 Mac 需要先适配 [构建脚本](build_app.sh) 中的签名身份及 `INSTALL_PATH`，并长期保持所选身份和安装位置一致。

SwiftPM 缓存位于 `~/Library/Caches/hotKeyApp/SwiftPM`，用于后续增量构建。

## 配置与常见问题

配置保存在 `~/Library/Application Support/hotKeyApp/config.json`。暂停快捷键或退出软件不会删除绑定。

**快捷键没有反应？** 检查是否启用了全部快捷键，以及该组合是否与 macOS 或其他软件冲突；换一个组合后再试。

**列表中找不到应用？** 使用“选择其他…”选择 `.app`。子应用也可以先启动或放入 Dock，再回到设置中选择。子应用未运行时能否单独启动，取决于它自身是否支持独立启动。

**再次按下没有切回？** 确认已开启切回功能，并且之前的前台应用仍在运行。

## 源码导航

- [应用启动与切换](Sources/hotKeyApp/Core/AppLauncher.swift)
- [全局快捷键管理](Sources/hotKeyApp/Core/HotKeyManager.swift)
- [应用选择与绑定界面](Sources/hotKeyApp/UI/BindingEditSheet.swift)
- [配置保存](Sources/hotKeyApp/Core/ConfigStore.swift)
