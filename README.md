# WheelVolume

> 按住 `Option`（或 `Fn`）滚动鼠标滚轮，无级、丝滑地调节 macOS 系统音量。
> **仅支持 Apple Silicon（M 系列芯片）Mac**。

[![Release](https://img.shields.io/github/v/release/googlemr/WheelVolume?label=version)](https://github.com/googlemr/WheelVolume/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2011%2B%20%7C%20Apple%20Silicon-lightgrey)](docs/INSTALL.md)

## 它解决什么问题

macOS 系统音量只有 16 格，按音量键一跳就是 6%+，想精细调一点很麻烦。WheelVolume 让你用滚轮以 **2% 一档**无级调节，手不离鼠标即可精确控制，并带一个轻量音量浮层即时反馈。

## 功能

- **无级调节**：默认每格 2%（可配到 1%），走 CoreAudio 底层，不受系统 16 格限制。
- **方向符合直觉**：默认 **上滑减小音量、下滑增加音量**；方向可在配置里一行反转。
- **修饰键触发**：按住 `Option` 或 `Fn` 再滚动，正常滚动页面完全不受影响（事件被吞掉，不会一边调音量一边滚网页）。
- **轻量浮层**：调节时屏幕中央显示音量百分比，0.8 秒后自动消失；可关闭。
- **开机自启**：安装脚本写入 LaunchAgent，登录即生效。
- **纯原生**：Swift 编写，单个小二进制，无第三方依赖、无联网、无数据收集。

## 快速开始

### 下载安装（普通用户）

1. 到 [Releases](https://github.com/googlemr/WheelVolume/releases) 下载 `WheelVolume-v<版本>-arm64.dmg`（或 `.zip`）。
2. 打开 DMG，把 `WheelVolume.app` 拖进「应用程序」。
3. 首次运行会请求**辅助功能**权限，请在弹窗中允许，或前往
   **系统设置 → 隐私与安全性 → 辅助功能** 勾选 WheelVolume。
4. 按住 `Option` + 滚轮即可调节。

完整步骤见 [安装说明](docs/INSTALL.md)。

### 从源码构建

```bash
git clone https://github.com/googlemr/WheelVolume.git
cd WheelVolume
./Scripts/build.sh          # 生成 dist/WheelVolume.app + DMG/ZIP
./Scripts/install.sh        # 安装到「应用程序」并配置自启
```

需要 Xcode Command Line Tools（`xcode-select --install`）与 macOS 11+。

## 使用方法

| 操作 | 效果 |
| --- | --- |
| `Option` + 滚轮上滑 | 音量减小（默认 -2%/格） |
| `Option` + 滚轮下滑 | 音量增加（默认 +2%/格） |
| `Fn` + 滚轮 | 同上（可在配置关闭） |
| 滚轮（不按修饰键） | 正常滚动，不受影响 |

配置位于 `~/Library/Application Support/WheelVolume/config.json`，常用项：

```json
{
  "step": 0.02,          // 每格步进，改 0.01 更细腻
  "minInterval": 0.025,  // 响应间隔，越小越跟手
  "invert": false,       // 方向反了改成 true
  "showOSD": true        // 关掉浮层改成 false
}
```

详见 [使用说明](docs/USAGE.md) 与 [权限说明](docs/PERMISSIONS.md)。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [安装说明](docs/INSTALL.md) | DMG/ZIP 安装、源码构建、卸载 |
| [使用说明](docs/USAGE.md) | 操作、全部配置项、自启管理 |
| [权限说明](docs/PERMISSIONS.md) | 为什么需要辅助功能权限、如何授予、隐私边界 |
| [常见问题](docs/FAQ.md) | 不生效、方向反了、被系统拦截等排查 |
| [更新日志](CHANGELOG.md) | 各版本变更 |
| [贡献指南](CONTRIBUTING.md) | 开发环境、提交规范、PR 流程 |
| [发布流程与版本规则](docs/RELEASE.md) | 版本号、构建、打 tag、上传 Release |
| [反馈渠道](docs/FEEDBACK.md) | Issue、讨论区、安全问题上报 |
| [行为准则](CODE_OF_CONDUCT.md) | 社区参与准则 |

## 目录结构

```
WheelVolume/
├── README.md               # 项目概览（本文件）
├── LICENSE                 # MIT 许可证
├── CHANGELOG.md            # 更新日志
├── CONTRIBUTING.md         # 贡献指南
├── CODE_OF_CONDUCT.md      # 行为准则
├── .gitignore
├── src/
│   └── WheelVolume.swift   # 全部源码（单文件，易审阅）
├── Resources/
│   ├── Info.plist          # App bundle 元数据
│   └── config.json         # 默认配置模板
├── Scripts/
│   ├── build.sh            # 一键构建 .app / .dmg / .zip
│   └── install.sh          # 安装 + 配置 LaunchAgent 自启
├── docs/                   # 分主题文档
│   ├── INSTALL.md
│   ├── USAGE.md
│   ├── PERMISSIONS.md
│   ├── FAQ.md
│   ├── RELEASE.md
│   └── FEEDBACK.md
├── .github/
│   ├── ISSUE_TEMPLATE/     # Bug 报告 / 功能建议 / 配置
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/
│       └── build.yml       # CI：多版本 macOS 编译校验
└── dist/                   # 构建产物（发布时上传）
```

## 技术说明

- **事件监听**：`CGEventTap`（`kCGEventScrollWheel`），仅在修饰键按下时接管事件。
- **音量控制**：CoreAudio `kAudioDevicePropertyVolumeScalar`，取值 0.0–1.0 浮点，因此能无级调节。
- **架构**：发布产物为 `arm64-apple-macos11.0` 单架构；启动时校验 Rosetta 环境并给出提示。
- **依赖**：仅系统框架（Foundation / CoreAudio / CoreGraphics / ApplicationServices / AppKit），无 SwiftPM 依赖。

## 许可证

[MIT](LICENSE) © 2026 Shanlin Du

## 反馈

遇到 bug 或想要新功能，请到 [Issues](https://github.com/googlemr/WheelVolume/issues) 提交；安全问题不要公开 Issue，按 [反馈渠道](docs/FEEDBACK.md) 中的私有方式上报。
