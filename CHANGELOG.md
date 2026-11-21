# 更新日志

本项目所有重要变更都会记录在此文件中。
格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

（暂无）

## [2.1.0] - 2026-11-21

滚轮逻辑改为「屏幕顶部边缘热区 + Ctrl 模式切换」。

### 变更（破坏性）

- 移除 Option / Fn 修饰键触发，改为**仅鼠标位于屏幕顶部边缘热区时**才接管滚轮；
  其他位置事件原样放行，不改动音量或亮度。
- 移除可调步进、方向反转与自定义音量浮层。固定为**上滑 +1%、下滑 −1%**，
  0%–100% 边界停止。
- 新增 Ctrl 模式：未按 Ctrl 调音量，按住 Ctrl 调亮度；两种模式由一个枚举决定，
  严格互斥。
- 反馈改为调用系统 `OSDUIHelper` 原生 OSD，不再绘制自定义 HUD。
- 设置项精简为：热区高度（新增，默认 8pt）、调节间隔、菜单栏百分比、开机自启。

### 新增

- `HotZone`：按鼠标所在显示的 `CGDisplayBounds` 上边缘判断，兼容多显示器。
- `ScreenBrightness`：通过 `DisplayServices` 读写系统亮度；不支持的显示器在
  设置页明确提示，不做 DDC/CI。
- `--selftest`：无辅助功能权限即可校验方向、边界、热区与模式互斥。

### 说明

- 现有配置中没有热区字段，因此热区范围是本版新增配置，并非沿用旧值。
- macOS 26 起系统不为程序化变更显示原生 OSD；本软件不会绘制替代界面。

## [2.0.0] - 2026-11-20

一次结构性重写：修掉"打开时没有响应"，并补齐图标与图形化设置。

### 修复

- **打开报"应用程序没有响应"（核心）**：1.x 的 `.app` 内只是命令行程序，
  直接用 `CFRunLoopRun()` 挂起进程，从不初始化 `NSApplication`。
  LaunchServices 收不到应用启动回执，Finder 等超时后判定为无响应。
  2.0.0 改为标准 AppKit 应用（`NSApplication` + `AppDelegate` + 菜单栏常驻），
  启动到 check-in 约 0.5 秒。
- 事件监听回调内不再做视图操作，并处理 `tapDisabledByTimeout` 自动重启监听，
  避免长时间使用后被系统静音事件。
- 外接显示器 / USB 声卡没有"主音量"通道时，自动回退到声道级音量控制。

### 新增

- **应用图标**：`Scripts/make-icon.swift` 用 Core Graphics 绘制 1024px 源图并生成
  `AppIcon.icns`，构建时自动重绘，仓库不含外部素材。
- **设置窗口**（SwiftUI）：调节精细度（0.2%–10% + 四档预设）、触发键分别开关、
  响应间隔、方向反转、音量浮层、菜单栏百分比、登录时自动启动、恢复默认。
- **菜单栏控制**：显示当前音量、直达设置、直达辅助功能授权页、关于、退出。
- 权限状态实时检测：在系统设置里勾选后 1 秒内自动开始监听，无需重启。
- `--render-settings <png>`：离屏渲染设置界面，供 CI 做界面冒烟测试。

### 变更

- 设置改用 `UserDefaults`（bundle id 不变），首次启动自动迁移 1.x 的
  `config.json` 后删除。
- 最低系统版本提升到 macOS 13.0，编译目标 `arm64-apple-macos13.0`。
- DMG 改为「拖拽到应用程序」布局（含 `应用程序` 快捷方式），`安装.command`
  保留为一键安装备选方案，并会清理 1.x 的脚本安装残留。
- ZIP 改用 `ditto` 打包，保留符号链接与权限。

### 移除

- 不再随包分发 `config.json`，也不再由安装脚本写死 LaunchAgent 的
  `KeepAlive`；开机自启改由应用内开关管理。

## [1.0.1] - 2026-11-20

修复安装包被 macOS 判定为"已损坏，无法打开"的问题。

### 修复

- **打包签名缺陷（核心）**：v1.0.0 只对可执行文件做了 linker 级 ad-hoc 签名，
  `.app` 包内 `Info.plist` 未绑定，`codesign --verify` 报
  `code has no resources but signature indicates they must be present`，
  Gatekeeper 因此判定应用已损坏。现在构建脚本对整个 bundle 执行
  `codesign --force --deep --sign -`，签名覆盖 `Info.plist` 与资源清单。
- DMG 内新增「安装.command」一键安装脚本：自动复制到「应用程序」、清除
  `com.apple.quarantine` 隔离标记、本地重新签名并启动，普通用户无需打开终端。
- DMG 内新增「安装说明.txt」，包含安装、授权、卸载与"已损坏"排查说明。

### 文档

- `docs/INSTALL.md` 重写安装流程，新增"为什么会出现已损坏"专门章节。
- `docs/FAQ.md` 新增"已损坏，无法打开"条目，区分"已损坏"与"无法验证开发者"
  两种不同拦截。

## [1.0.0] - 2026-11-19

首个公开版本。

### 新增

- Option / Fn + 滚轮无级调节系统音量，默认 2%/格，走 CoreAudio 底层。
- 方向：默认上滑减小音量、下滑增加音量，可通过 `invert` 反转。
- 轻量音量浮层，0.8 秒自动消失，可关闭。
- 静音状态下向下滚动自动解除静音。
- 用户配置：`~/Library/Application Support/WheelVolume/config.json`，支持步进、响应间隔、触发键、方向、浮层开关。
- `install.sh` 一键安装并配置 LaunchAgent 开机自启。
- `build.sh` 一键构建 `arm64` 的 `.app` / `.dmg` / `.zip` 发布物。
- 命令行参数 `--version` / `--help`。
- Apple Silicon 运行时校验，拒绝 Rosetta 环境。
- 完整开源项目文档、Issue/PR 模板、CI 构建工作流。

[Unreleased]: https://github.com/googlemr/WheelVolume/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/googlemr/WheelVolume/releases/tag/v2.1.0
[2.0.0]: https://github.com/googlemr/WheelVolume/releases/tag/v2.0.0
[1.0.0]: https://github.com/googlemr/WheelVolume/releases/tag/v1.0.0
