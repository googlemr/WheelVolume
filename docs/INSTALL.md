# 安装说明

## 系统要求

- **芯片**：Apple Silicon（M1 / M2 / M3 / M4 及后续型号）。Intel Mac 不支持。
- **系统**：macOS 13.0（Ventura）或更高。
- **权限**：辅助功能（用于接收滚轮事件）。

## 方式一：拖拽安装（推荐）

1. 从 [Releases](https://github.com/googlemr/WheelVolume/releases) 下载
   `WheelVolume-v<版本>-arm64.dmg`。
2. 双击 DMG 挂载。
3. 把 **WheelVolume.app** 拖到窗口里的「应用程序」文件夹。
4. 打开「应用程序」，双击 WheelVolume。

### 首次打开提示"Apple 无法验证"

本项目没有 Apple 付费开发者证书，因此安装包无法公证。应用本身有有效的 ad-hoc
签名，**文件没有损坏**，按 Apple 官方提供的用户覆盖流程操作一次即可：

1. 打开 **系统设置 → 隐私与安全性**；
2. 页面下方会出现"已阻止 WheelVolume 以保护 Mac"，点 **仍要打开**；
3. 再次双击 WheelVolume，弹窗里点 **打开**。

macOS 15（Sequoia）起 Apple 移除了"右键 → 打开"的快捷绕过方式，必须走上面的设置页。

## 方式二：一键安装脚本

DMG 里带有 `安装.command`。双击它（若被拦截，同样去"隐私与安全性 → 仍要打开"），
脚本会依次执行：

1. 结束正在运行的旧版本；
2. 清理 1.x 版本用脚本安装留下的 `/Applications`、`~/Applications` 副本与
   LaunchAgent 开机项；
3. 复制到 `/Applications`；
4. 清除 `com.apple.quarantine` 隔离标记；
5. 校验代码签名（仅在异常时于本机重新签名）；
6. 启动程序。

## 授予辅助功能权限（必做）

滚轮监听依赖辅助功能权限，没有它程序能运行但没有任何反应。

1. 程序首次启动会自动弹出设置窗口，点 **去授权**；
2. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中勾选 **WheelVolume**；
3. 回到程序，状态会在一秒内从"缺少权限"变为"已获得权限"，无需重启。

若列表里没有 WheelVolume，点列表下方的 **+**，选择
`/Applications/WheelVolume.app` 添加。

> 从 1.x 升级到 2.0.0 后，如果辅助功能列表里已有旧的 WheelVolume 条目，
> 请先取消勾选、再重新勾选一次（或点 **−** 移除后重新添加）——旧授权绑定的是
> 旧版本的签名，不会自动继承。

## 从源码构建

```bash
git clone https://github.com/googlemr/WheelVolume.git
cd WheelVolume
./Scripts/build.sh            # 生成 dist/WheelVolume.app、DMG、ZIP、SHA256SUMS.txt
./Scripts/install.sh          # 安装到 /Applications 并启动
```

- 需要 Xcode Command Line Tools：`xcode-select --install`
- 构建目标：`arm64-apple-macos13.0`，脚本会校验产物架构
- 图标在构建时由 `Scripts/make-icon.swift` 现场绘制，不需要外部素材

产物：

```
dist/WheelVolume.app                      # 应用本体
dist/WheelVolume-v<版本>-arm64.dmg        # 拖拽安装镜像
dist/WheelVolume-v<版本>-arm64.zip        # 便携压缩包
dist/SHA256SUMS.txt                       # 校验清单
```

## 验证安装

```bash
/Applications/WheelVolume.app/Contents/MacOS/WheelVolume --version
# 预期输出：WheelVolume 2.0.0 (arm64-apple-macos13.0)

codesign --verify --deep --strict /Applications/WheelVolume.app && echo "签名有效"
shasum -a 256 -c dist/SHA256SUMS.txt
```

## 卸载

1. 菜单栏扬声器图标 → **设置…** → 关闭「登录时自动启动」→ 点 **退出**；
2. 把「应用程序」里的 WheelVolume 拖到废纸篓；
3. 彻底清除偏好（可选）：

```bash
defaults delete com.shanlin.WheelVolume
rm -f ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist
```

## 从 1.x 升级

2.0.0 的 bundle id 未变，但应用结构与签名都换了新版本。直接覆盖安装即可；
如果辅助功能列表里出现过期条目，按上面的"授予辅助功能权限"重新勾选一次。
1.x 的 `~/Library/Application Support/WheelVolume/config.json` 会在首次启动时
自动迁移到新的设置存储，随后被删除。
