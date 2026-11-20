# 安装说明

## 系统要求

- **芯片**：Apple Silicon（M1 / M1 Pro / M1 Max / M1 Ultra / M2 / M2 Pro / M2 Max / M2 Ultra / M3 系列 / M4 系列等 arm64）
- **系统**：macOS 11.0（Big Sur）或更高
- **不适用**：Intel 芯片 Mac、Rosetta 转译环境、虚拟机

> 本项目的发布包是 arm64 单架构二进制。Intel Mac 上 macOS 会直接拒绝打开；请勿尝试用 Rosetta 运行。

## 方式一：一键安装脚本（最省事，推荐）

1. 打开 [Releases 页面](https://github.com/googlemr/WheelVolume/releases)，下载最新的
   `WheelVolume-v<版本号>-arm64.dmg`。
2. 双击 DMG 挂载。
3. **双击里面的「安装.command」**，按提示操作即可。

  脚本会自动完成：复制到「应用程序」→ 清除 macOS 隔离标记 → 本地重新签名 → 启动程序。

4. 弹出辅助功能授权时点「允许」；若未弹窗，见 [权限说明](PERMISSIONS.md)。
5. 按住 `Option` 滚动滚轮验证：上滑音量减小、下滑音量增加。

> 如果双击「安装.command」提示「无法打开，因为无法验证开发者」：
> 右键点击它 → 选择「打开」→ 再点「打开」。
> 若右键也无法打开，打开「终端」执行：`bash "/Volumes/WheelVolume/安装.command"`

## 为什么会出现「已损坏，应移到废纸篓」

这是本项目最常见的问题，先说清原因：

**本工具没有 Apple 付费开发者证书（每年 99 美元），无法做公证（notarization）。**
macOS 会给从网络下载的文件打上 `com.apple.quarantine` 隔离标记，Gatekeeper 一旦
发现应用未公证，就可能直接报「已损坏，应移到废纸篓」——**文件其实没坏**。

从 v1.0.1 起，发布包已对完整 `.app` 包做了 ad-hoc 签名（此前只有二进制级的
linker 签名，包结构一变就校验失败，那才是真正触发「已损坏」的原因），并附带
一键安装脚本自动清除隔离标记。

如果你仍在旧版本遇到此提示，用下面任一方式解决：

```bash
# 方式 A：清除隔离标记 + 本地重新签名（推荐）
xattr -dr com.apple.quarantine /Applications/WheelVolume.app
codesign --force --deep --sign - /Applications/WheelVolume.app
open /Applications/WheelVolume.app
```

```bash
# 方式 B：仅清除隔离标记
sudo xattr -rd com.apple.quarantine /Applications/WheelVolume.app
```

放到「应用程序」文件夹后如果双击仍提示，去
**系统设置 → 隐私与安全性**，在页面下方找到关于 WheelVolume 的提示，点「仍要打开」。

## 方式二：DMG 手动安装

1. 下载 `WheelVolume-v<版本号>-arm64.dmg` 并双击挂载。
2. 将 `WheelVolume.app` 拖到「应用程序」文件夹。
3. 推出 DMG，从「启动台」或「应用程序」打开 WheelVolume。
4. 若提示「无法打开，因为来自身份不明的开发者」或「已损坏」，按上一节的方式 A 处理。
5. 首次启动会弹出辅助功能授权请求 → 点「允许」。
6. 按住 `Option` 滚动滚轮验证：上滑音量减小、下滑音量增加。

## 方式三：ZIP 安装

1. 下载 `WheelVolume-v<版本号>-arm64.zip`。
2. 解压后把 `WheelVolume.app` 移到「应用程序」。
3. 若被 Gatekeeper 拦截，执行：

```bash
xattr -dr com.apple.quarantine /Applications/WheelVolume.app
codesign --force --deep --sign - /Applications/WheelVolume.app
```

4. 后续步骤同 DMG 方式的第 3–6 步。

ZIP 适合自动部署脚本；DMG 更适合普通用户。

## 方式四：从源码构建

前置条件：

```bash
xcode-select --install     # 若尚未安装 Command Line Tools
```

构建与安装：

```bash
git clone https://github.com/googlemr/WheelVolume.git
cd WheelVolume
./Scripts/build.sh         # 输出 dist/WheelVolume.app、DMG、ZIP
./Scripts/install.sh       # 复制到「应用程序」并写入 LaunchAgent 自启
```

`build.sh` 会编译 `arm64-apple-macos11.0` 目标并校验产物架构；在非 arm64 环境会直接报错退出。

## 配置开机自启

`install.sh` 会自动写入 `~/Library/LaunchAgents/com.shanlin.WheelVolume.plist` 并加载。
如需手动管理：

```bash
# 立即启动 + 登录自启
launchctl load -w ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist

# 停止自启
launchctl unload -w ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist

# 确认是否在运行
pgrep -fl WheelVolume
```

## 卸载

```bash
# 1) 停止并移除自启
launchctl unload -w ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist

# 2) 删除 App
rm -rf /Applications/WheelVolume.app

# 3) 可选：删除用户配置与日志
rm -rf ~/Library/Application\ Support/WheelVolume
```

最后到 **系统设置 → 隐私与安全性 → 辅助功能** 取消 WheelVolume 的勾选（清理授权记录）。

## 验证安装

```bash
~/Applications/WheelVolume.app/Contents/MacOS/WheelVolume --version
# 预期输出：WheelVolume 1.0.0 (arm64-apple-macos11.0)
```
