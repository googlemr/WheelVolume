# WheelVolume

> **鼠标移到屏幕顶部边缘**，滚动即可调音量；按住 `Ctrl` 滚动改为调亮度。
> 仅支持 Apple Silicon（M 系列）Mac，macOS 13+。

[![Release](https://img.shields.io/github/v/release/googlemr/WheelVolume?label=version)](https://github.com/googlemr/WheelVolume/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B%20%7C%20Apple%20Silicon-lightgrey)](docs/INSTALL.md)

<img src="docs/images/app-icon.png" width="104" align="right" alt="WheelVolume 图标">

## 行为（v2.1.0 起）

| 条件 | 上滑 | 下滑 |
| --- | --- | --- |
| 鼠标在顶部边缘热区，**未按 Ctrl** | 音量 +1% | 音量 −1% |
| 鼠标在顶部边缘热区，**按住 Ctrl** | 亮度 +1% | 亮度 −1% |
| 鼠标不在顶部边缘热区 | 无动作，滚轮照常滚动页面 | 同左 |

- 两种模式互斥：按住 Ctrl 只调亮度，绝不会同时改动音量。
- 0% 和 100% 处停止，不会越界。
- 热区高度默认 8pt，可在设置里调（4 / 8 / 16 / 32pt 预设，或 2–48pt 滑块）。
- 反馈调用系统自带的音量 / 亮度 OSD 接口，**不绘制任何自定义提示界面**。

<img src="docs/images/settings.png" width="500" alt="设置界面">

## 安装

到 [Releases](https://github.com/googlemr/WheelVolume/releases) 下载
`WheelVolume-v<版本>-arm64.dmg`，双击挂载，把 app 拖进「应用程序」，然后打开。
首次打开若提示"Apple 无法验证"，到 **系统设置 → 隐私与安全性 → 仍要打开**。
程序会弹出设置页，点 **去授权**，在 **辅助功能** 里勾选 WheelVolume。

也可双击 DMG 内的 `安装.command` 一键安装。详见 [安装说明](docs/INSTALL.md)。

## 从源码构建

```bash
./Scripts/build.sh     # 编译 → 图标 → 签名 → DMG/ZIP + SHA256SUMS.txt
./Scripts/install.sh   # 安装到 /Applications 并启动
/tmp/... --selftest    # 无权限环境下自检方向、边界、热区、模式互斥
```

图标由 `Scripts/make-icon.swift` 用 Core Graphics 在构建时生成，无外部素材。

## 已知限制（如实说明）

1. **macOS 26 起系统不再为程序化音量/亮度变更弹出原生浮层。** 本软件调用
   `com.apple.OSDUIHelper` 的原生 OSD 接口；若系统不显示，软件也不会自己画一个。
   菜单栏图标可选显示音量百分比作为替代读数。
2. **亮度依赖 `DisplayServices`，只覆盖支持系统亮度控制的显示器（内置屏）。**
   Mac mini 接 HDMI 外接显示器时 `DisplayServicesCanChangeBrightness` 返回 false，
   设置页会明确显示"当前显示器不支持系统亮度控制"，此时 Ctrl+滚轮不会改动亮度。
3. 需要辅助功能权限才能读取全局滚轮事件并判断鼠标位置；这是 macOS 强制要求。

## 文档

| 文档 | 内容 |
| --- | --- |
| [安装说明](docs/INSTALL.md) | 安装、Gatekeeper、卸载、从旧版升级 |
| [使用说明](docs/USAGE.md) | 触发规则、设置项、边界与互斥 |
| [权限说明](docs/PERMISSIONS.md) | 辅助功能权限与隐私边界 |
| [常见问题](docs/FAQ.md) | 不生效、亮度无效、无 OSD 等 |
| [更新日志](CHANGELOG.md) | 各版本变更 |
| [发布流程](docs/RELEASE.md) | 版本规则与 Release 流程 |
| [反馈渠道](docs/FEEDBACK.md) | Issue 与安全上报 |

## 技术要点

- 标准 AppKit 应用（`NSApplication` + `AppDelegate`），`LSUIElement=1` 菜单栏常驻。
- `CGEventTap`（`kCGHIDEventTap`）只订阅 `scrollWheel`；用 `event.location` 与
  `CGGetDisplaysWithPoint` / `CGDisplayBounds` 判断鼠标是否落在顶部热区。
- `deltaAxis1 > 0` 代表向上滚动；以整数百分比运算，严格夹在 0–100。
- 音量走 CoreAudio `kAudioDevicePropertyVolumeScalar`；亮度走 `DisplayServices`。
- OSD 走系统 `OSDUIHelper` XPC；整包 ad-hoc 签名 + SHA256 校验。

## 许可证

[MIT](LICENSE) © 2026 Shanlin Du
