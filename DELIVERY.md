# 交付说明（v2.0.0）

## 已发布

- 仓库：https://github.com/googlemr/WheelVolume
- **最新版本**：https://github.com/googlemr/WheelVolume/releases/tag/v2.0.0
  - `WheelVolume-v2.0.0-arm64.dmg`（982 KB，拖拽安装 + 一键安装脚本）
  - `WheelVolume-v2.0.0-arm64.zip`（958 KB）
  - `SHA256SUMS.txt`

## 本版解决的问题

| 问题 | 根因 | 处理 |
| --- | --- | --- |
| 双击后弹"应用程序没有响应" | 1.x 的 `.app` 内是命令行程序，`CFRunLoopRun()` 直接挂起，从未初始化 `NSApplication`，LaunchServices 收不到启动回执 | 改为标准 AppKit 应用；实测 launch→check-in 0.49 s |
| 无图标、无设置界面 | 未实现 | 代码绘制 AppIcon.icns + SwiftUI 设置窗口 + 菜单栏菜单 |

## 验证记录（本机 macOS 26.7.3 / arm64）

- `codesign --verify --deep --strict`：valid on disk / satisfies its Designated Requirement
- 从挂载的 DMG 执行 `安装.command`：安装、清隔离、校验签名、启动全部成功
- 从 Release 真实下载 DMG：`shasum -a 256 -c SHA256SUMS.txt` → OK
- 启动验证：`lsappinfo` 显示 `launch to checkin time: 0.489455 seconds`，进程常驻
- UI 验收：`--render-settings` 离屏渲染，六个分区完整无裁切（见 `docs/images/settings.png`）
- 旧版清理：`/Applications`、`~/Applications` 副本移入废纸篓，`com.dushanlin.WheelVolume` 开机项与 `config.json` 已删除

## 已知限制

- 无 Apple 开发者证书，未公证：首次打开需在 **系统设置 → 隐私与安全性 → 仍要打开** 一次。
- 辅助功能权限无法由脚本代授，需用户在系统设置里勾选（授权后 1 秒内自动生效）。
- CI（GitHub Actions）在本仓库首次运行可能需在网页端批准一次；发布走 API 手工上传。
