# 交付说明（v2.2.0，当前最新）

## 已发布

- 仓库：https://github.com/googlemr/WheelVolume
- Release：https://github.com/googlemr/WheelVolume/releases/tag/v2.2.0
- 资产：`WheelVolume-v2.2.0-arm64.dmg`、`WheelVolume-v2.2.0-arm64.zip`、`SHA256SUMS.txt`

## 本轮需求实现

| 需求 | 实现 |
| --- | --- |
| 音量保留弹窗 | `StatusHUD`：右上角 246×74 通知风格面板，图标 + 标题 + 百分比 + 进度条 |
| 右上角、类似系统提示 | `NSVisualEffectView`（hudWindow）+ 蓝色 SF Symbol 圆角图标 + 菜单栏下方 10pt 定位 |
| 滚轮调亮度（替代 F1/F2） | VESA DDC/CI：`IOAVService` 读写 VCP 0x10；内置屏回退 `DisplayServices` |
| 弹窗自动消失 | 每次调节重置 1.2 秒计时，到点淡出，无常驻窗口 |

## 验证记录（macOS 26.7.3 / Mac mini M4 + HDMI 外接屏）

- DDC 读：应用内读到亮度 62（与 `m1ddc` 一致）；写：62 → 63，回读确认 63。
- `--selftest` 11 项 PASS（方向、边界、热区、互斥）。
- 设置页渲染：显示"当前显示器支持系统亮度控制"，六分区完整无裁切。
- 弹窗离屏渲染：图标/文字/进度条清晰无重叠。
- `codesign --verify --deep --strict` 通过；`launch to checkin time: 0.350058 seconds`。

## 已知限制

- DDC 依赖显示器支持；不支持时设置页会显示，Ctrl+滚轮无效。
- 亮度百分比在启动时读取一次并缓存；外部程序改动亮度后本软件不会同步。
- 辅助功能权限需用户手动授予。
