# 安装说明

## 系统要求

- **芯片**：Apple Silicon（M1 / M1 Pro / M1 Max / M1 Ultra / M2 / M2 Pro / M2 Max / M2 Ultra / M3 系列 / M4 系列等 arm64）
- **系统**：macOS 11.0（Big Sur）或更高
- **不适用**：Intel 芯片 Mac、Rosetta 转译环境、虚拟机

> 本项目的发布包是 arm64 单架构二进制。Intel Mac 上 macOS 会直接拒绝打开；请勿尝试用 Rosetta 运行。

## 方式一：DMG 安装（推荐）

1. 打开 [Releases 页面](https://github.com/googlemr/WheelVolume/releases)，下载最新版本资产：
   `WheelVolume-v<版本号>-arm64.dmg`。
2. 双击 DMG 挂载，将 `WheelVolume.app` 拖到「应用程序」文件夹。
3. 推出 DMG。从「启动台」或「应用程序」打开 WheelVolume。
4. 首次启动会弹出辅助功能授权请求 → 点「允许」；若未弹窗，见 [权限说明](PERMISSIONS.md)。
5. 按住 `Option` 滚动滚轮验证：上滑音量减小、下滑音量增加。

> 若 macOS 提示「无法打开，因为来自身份不明的开发者」，右键 App →「打开」→「打开」；或到
> **系统设置 → 隐私与安全性** 找到对应提示点「仍要打开」。详见 [FAQ](FAQ.md)。

## 方式二：ZIP 安装

1. 下载 `WheelVolume-v<版本号>-arm64.zip`。
2. 解压后把 `WheelVolume.app` 移到「应用程序」。
3. 后续步骤同 DMG 方式的第 3–5 步。

ZIP 适合自动部署脚本；DMG 更适合普通用户。

## 方式三：从源码构建

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
