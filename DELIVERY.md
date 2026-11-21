# 交付说明（v2.1.0，当前最新）

## 已发布

- 仓库：https://github.com/googlemr/WheelVolume
- **Release**：https://github.com/googlemr/WheelVolume/releases/tag/v2.1.0
  - `WheelVolume-v2.1.0-arm64.dmg`（1,376,634 字节）
  - `WheelVolume-v2.1.0-arm64.zip`（978,619 字节）
  - `SHA256SUMS.txt`
- v2.0.0 保留为历史版本，v2.1.0 已设为 latest。

## 实现对照用户需求

| 需求 | 实现 |
| --- | --- |
| 仅顶部边缘热区生效 | `HotZone.contains(event.location)`，按鼠标所在显示的 `CGDisplayBounds` 上边缘 + `hotZoneHeight` 判定；不在热区直接放行事件 |
| 未按 Ctrl 调音量 | `WheelLogic.mode(false) = .volume`，CoreAudio scalar ±1% |
| 按住 Ctrl 调亮度 | `WheelLogic.mode(true) = .brightness`，DisplayServices ±1% |
| 上滑 +1% / 下滑 −1% | `deltaAxis1 > 0` 为向上；整数百分比运算 |
| 0%–100% 边界 | `WheelLogic.nextPercent` 用 `min(100, max(0, …))` |
| 模式互斥 | 单一 `ScrollMode` 枚举决定唯一写入目标 |
| 热区范围沿用现有配置 | 现有代码没有热区字段，故新增 `hotZoneHeight`（默认 8pt）并放进设置页 |
| 系统自带反馈、无自定义提示 | 调用 `com.apple.OSDUIHelper` XPC，`showImage(image, filled=percent, total=100)`；删除原 `VolumeHUD` |

## 验证记录（macOS 26.7.3 / arm64）

- `--selftest` 11 项全部 PASS：方向 2 项、边界 4 项、模式互斥 2 项、热区内外 3 项。
- `codesign --verify --deep --strict`：通过。
- `lsappinfo`：Version 2.1.0，`launch to checkin time: 0.315673 seconds`。
- Release 真实下载：`shasum -a 256 -c SHA256SUMS.txt` → DMG OK。
- 设置界面离屏渲染检查：六个分区完整、无裁切（docs/images/settings.png）。

## 已知限制

- macOS 26 起系统不为程序化修改显示原生 OSD；软件不绘制替代界面。
- `DisplayServices` 对 Mac mini 的 HDMI 外接显示器返回 `canChange=false`，
  设置页显示"当前显示器不支持系统亮度控制"，此时 Ctrl+滚轮不改亮度。
- 辅助功能权限必须用户手动授予，脚本无法代劳。
