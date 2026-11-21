# 使用说明

## 触发规则

只有**鼠标指针位于屏幕顶部边缘热区**时，滚轮事件才被接管。

| 位置与按键 | 上滑 | 下滑 |
| --- | --- | --- |
| 顶部热区，未按 Ctrl | 音量 +1% | 音量 −1% |
| 顶部热区，按住 Ctrl | 亮度 +1% | 亮度 −1% |
| 非顶部热区 | 不处理，正常滚动页面 | 不处理 |

热区按鼠标所在显示器的上边缘计算；多显示器且某台位于主屏上方时也同样适用。
默认高度 8pt，可在设置里改成 4 / 8 / 16 / 32pt，或拖动滑块取 2–48pt。

## 边界与互斥

- 调节以整数百分比进行，0% 和 100% 为硬边界：到边界后继续滚动不会再变化。
- 两种模式由一个枚举值决定：未按 Ctrl = 音量，按住 Ctrl = 亮度。
  亮度分支不会写音量，音量分支不会写亮度，不存在同时触发的路径。
- 若音量处于静音状态，向上滚动会先取消静音再调到目标百分比。

## 反馈

调节时调用系统 `OSDUIHelper` 的原生音量/亮度 OSD 接口（image 3 / image 1，
filled=当前百分比，total=100）。本软件**不实现也不显示任何自定义提示界面**。

注意：macOS 26 起系统不再为程序化变更弹出该浮层；此时不会有可见 OSD，
这是系统行为，不是本软件的提示界面。可在设置里开启"在菜单栏显示音量百分比"。

## 设置项

| 设置 | 默认 | 说明 |
| --- | --- | --- |
| 热区高度 | 8 pt | 2–48pt，含四档预设 |
| 调节间隔 | 0（每次滚动都响应） | 触控板可改 25/60/120ms 降频 |
| 菜单栏显示音量百分比 | 关 | 图标旁显示数字 |
| 登录时自动启动 | 关 | 写 `~/Library/LaunchAgents/com.shanlin.WheelVolume.plist` |

设置存于 `UserDefaults`（bundle id `com.shanlin.WheelVolume`），改动即时生效。

## 亮度支持范围

亮度通过 `DisplayServices` 私有框架读写，覆盖支持系统亮度控制的显示器
（典型为 MacBook 内置屏）。Mac mini 等无内置屏机型接 HDMI / DP 外接显示器时，
`DisplayServicesCanChangeBrightness` 返回 false，设置页会显示不支持，
Ctrl+滚轮不改变亮度。本软件不提供 DDC/CI 显示器控制。

## 命令行

```bash
WheelVolume --version     # WheelVolume 2.1.0 (arm64-apple-macos13.0)
WheelVolume --help
WheelVolume --selftest    # 校验方向、0–100 边界、热区判定、模式互斥
WheelVolume --render-settings out.png   # 开发用：离屏渲染设置界面
```
