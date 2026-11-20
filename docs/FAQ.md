# 常见问题

## 装了但滚轮没反应

1. 打开设置窗口，看第一栏是不是"缺少「辅助功能」权限"；
2. 若是，点 **去授权**，在 系统设置 → 隐私与安全性 → 辅助功能 中勾选 WheelVolume；
3. 授权后 1 秒内程序会自动开始监听，不需要重启。

如果列表里已有 WheelVolume 且是勾选状态但依然无效（常见于从 1.x 升级），
请取消勾选再重新勾选一次。

## 打开时提示"应用程序没有响应"

这是 **1.0.x 的已知缺陷**，2.0.0 已修复。

原因：1.x 只是在 `.app` 里放了一个命令行程序，用 `CFRunLoopRun()` 挂起进程，
从未初始化 `NSApplication`，LaunchServices 等不到"应用已就绪"的回执，于是判定为
无响应。2.0.0 改成了标准 AppKit 应用（`NSApplication` + `AppDelegate`），
启动到 check-in 约 0.5 秒。

遇到这个提示说明装的是旧版，请卸载后安装 2.0.0：

```bash
pkill -x WheelVolume
rm -f ~/Library/LaunchAgents/com.dushanlin.WheelVolume.plist
rm -rf /Applications/WheelVolume.app "$HOME/Applications/WheelVolume.app"
```

## 提示"已损坏，应移到废纸篓"

1.0.0 的发布包只对可执行文件做了 linker 级签名，包里的 `Info.plist` 与资源没有
被签名覆盖，Gatekeeper 校验失败就会报"已损坏"。1.0.1 起改为整包 ad-hoc 签名，
2.0.0 同样。若仍遇到，说明下载的是旧包或包在传输中损坏：

```bash
codesign --verify --deep --strict --verbose=2 /Applications/WheelVolume.app
shasum -a 256 ~/Downloads/WheelVolume-v2.0.0-arm64.dmg   # 与 Release 页的 SHA256SUMS.txt 比对
```

签名无效就重新下载；有效则双击 DMG 里的 `安装.command`。

## 提示"Apple 无法验证" / "无法打开，因为无法验证开发者"

未公证应用的正常提示，不是损坏。去 **系统设置 → 隐私与安全性**，
在页面下方点 **仍要打开**。

## 方向反了

设置 → 勾选 **反转方向（下滑减小、上滑增大）**。

## 调一次跳太多 / 太迟钝

调 **调节精细度**：想更细腻就调小（0.5%–1%），想更灵敏就调大（5%）。
如果感觉"滚一下跳好几档"，把 **调节间隔** 调大一些。

## 音量调了但系统音量条没变

外接显示器、部分 USB 声卡没有"主音量"通道。程序会自动回退到声道级音量控制；
如果设备完全不支持音量调节（例如某些 HDMI 输出），滚轮不会有反应，此时请用
显示器自带的音量控制。

## 会读取我的键盘输入吗

不会。程序只订阅 `scrollWheel` 类型的滚轮事件，且必须按住 Option/Fn 才处理；
不监听键盘、不记录内容、不联网、不写日志文件。

## 开机自启在哪里关

菜单栏图标 → 取消勾选 **登录时自动启动**，或在设置窗口里关闭该开关。
对应文件：`~/Library/LaunchAgents/com.shanlin.WheelVolume.plist`。

## 怎么彻底卸载

见 [安装说明](INSTALL.md#卸载)。
