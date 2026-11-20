# WheelVolume 开源交付清单

## ✅ 已发布（2026-11-20，最新 v1.0.1）

- 仓库：https://github.com/googlemr/WheelVolume （main + tag v1.0.1 均已推送）
- **当前推荐版本**：https://github.com/googlemr/WheelVolume/releases/tag/v1.0.1
  - `WheelVolume-v1.0.1-arm64.dmg`（50 KB，含一键安装脚本）
  - `WheelVolume-v1.0.1-arm64.zip`（28 KB）
  - `SHA256SUMS.txt`
- v1.0.0 的安装包因签名缺陷会被 macOS 判为"已损坏"，其二进制资产**已从下载区移除**，
  Release 说明已加警告并指向 v1.0.1。

### v1.0.1 修的是什么

v1.0.0 只对可执行文件做了 linker 级 ad-hoc 签名，`.app` 包内 `Info.plist` 未绑定，
`codesign` 校验报：

```
code has no resources but signature indicates they must be present
```

Gatekeeper 因此判定包被篡改，弹出"已损坏，无法打开，你应该将它移到废纸篓"。
v1.0.1 在构建时对整个 bundle 执行 `codesign --force --deep --sign -`，并让 DMG
内置「安装.command」，自动完成复制、清除隔离标记、重新签名与启动。

验证结果：从 GitHub 真实下载 DMG → 复制 app → 打 `com.apple.quarantine` →
`codesign --verify` 返回 `valid on disk` / `satisfies its Designated Requirement`。

本地仓库根目录：`/Users/d/WorkBuddy/2026-11-19-17-14-07/WheelVolume`

## 交付内容

### 代码与资源

| 文件 | 说明 |
| --- | --- |
| `src/WheelVolume.swift` | 全部源码，单文件、无第三方依赖，已编译验证 |
| `Resources/Info.plist` | App 元数据（版本 1.0.1、LSUIElement、arm64） |
| `Resources/安装.command` | DMG 内一键安装脚本（复制、清隔离、签名、启动） |
| `Resources/安装说明.txt` | DMG 内安装/授权/卸载/已损坏排查说明 |
| `Resources/config.json` | 默认配置模板 |
| `Scripts/build.sh` | 一键构建（校验 arm64 → 编译 → **bundle 签名** → DMG/ZIP → 校验值） |
| `Scripts/install.sh` | 安装到「应用程序」+ 配置 LaunchAgent 自启 |

### 文档（中文）

README、安装说明、使用说明、权限说明、常见问题、更新日志、贡献指南、行为准则、许可证（MIT）、反馈渠道、发布流程与版本规则——共 11 份，见 `README.md` 文档索引。

### GitHub 配置

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/build.yml`（macos-14 arm64 runner 编译校验 + 上传产物）

### 发布物（已构建并校验）

| 文件 | 大小 |
| --- | --- |
| `dist/WheelVolume-v1.0.0-arm64.dmg` | 46 KB |
| `dist/WheelVolume-v1.0.0-arm64.zip` | 29 KB |
| `dist/WheelVolume.app/` | 应用包 |
| `dist/SHA256SUMS.txt` | 校验值（`shasum -a 256 -c` 自检通过） |

## 已验证项

- 架构：`Mach-O 64-bit executable arm64`，`--target arm64-apple-macos11.0`
- 方向：实测上滑减小（33%→27%）、下滑增加（27%→33%），符合规格
- 无级粒度：2%/格，CoreAudio scalar
- 命令行：`--version` / `--help` 正常
- DMG：`hdiutil verify` 校验和 VALID
- ZIP：结构干净，无 `__MACOSX`
- 校验和：DMG/ZIP 均 OK

## 推送故障排查与修复记录（2026-11-20）

### 症状
终端执行 push 后长时间无响应，最终报：
`fatal: unable to access 'https://github.com/googlemr/WheelVolume.git/': Recv failure: Operation timed out`

### 根因（两个独立问题）
1. **网络超时**：本机 git 没有配置代理，而你通过 v2rayN（xray，监听 `127.0.0.1:10808`）联网。git 直连 GitHub 被墙导致超时。`curl` 能通是因为环境变量里有 `https_proxy=http://127.0.0.1:56674`，但 git 不读该变量。
2. **提交历史分叉**：网页建仓库时生成了 `Initial commit`（`4d60163`，仅一行 README），本地 `release: v1.0.0`（`f0fc7a9`）与之无共同祖先，直接 push 会 `non-fast-forward` 被拒。

### 已修复（我已完成，无需你操作）
- ✅ 探测到可用代理 `127.0.0.1:10808`，`git ls-remote` 验证通过（HTTP 200）。
- ✅ 用 `--allow-unrelated-histories` 合并了远端与本地历史，保留完整本地 README，生成合并提交 `6d154e6`。
- ✅ 本地 tag `v1.0.0` 已建好，工作区干净。
- ✅ 重写 `publish.sh`：自动探测代理端口（10808/10809/7890/7897/56674）、幂等处理 init/commit、支持 `GH_TOKEN` 环境变量注入凭据。语法校验通过，`push --dry-run` 确认网络层打通（到达认证提示，不再超时）。

### 唯一剩余阻塞：认证
本机没有任何 GitHub 凭据（无 gh CLI、无 SSH key、钥匙串无条目、无环境变量 Token），GitHub 集成 token 只读（写操作 403）。**push 必须提供你的 GitHub 凭据**——这是 GitHub 的安全机制，无法绕过。

### 你需要做的（二选一）

**方式 A（推荐，最快）**：生成一个 Personal Access Token 后，在终端执行一行命令：

```bash
GH_TOKEN='你的token' bash "/Users/d/WorkBuddy/2026-11-19-17-14-07/WheelVolume/publish.sh"
```

生成 Token：打开 https://github.com/settings/tokens → Generate new token → **Classic** → 勾选 `repo` 权限 → 生成并复制。（Fine-grained token 需给该仓库 Contents 读写权限。）

**方式 B（不用 Token）**：直接在终端执行 `bash "/Users/d/WorkBuddy/2026-11-19-17-14-07/WheelVolume/publish.sh"`，push 时 git 会提示输入用户名（`googlemr`）和密码——密码处填 PAT。

脚本会自动配代理、推送代码、推送 tag。**tag 一推，CI 会自动构建并发布带 DMG/ZIP 的 Release**，无需手动上传二进制。

> 若你的 GitHub 用户名不是 `googlemr`，需全局替换文档链接并改 `publish.sh` 中的 remote 地址：
> `grep -rl "googlemr/WheelVolume" . | xargs sed -i '' 's|googlemr/WheelVolume|<你的用户名>/WheelVolume|g'`

## 发布后需回补的两点

1. **签名/公证**：当前为未签名产物，用户首次打开需右键「打开」。持有 Apple Developer 证书时按 `docs/RELEASE.md` 第 7 步启用签名与公证。
2. **Issue/Discussion 板块**：在仓库 Settings → Features 里勾选 Issues 和 Discussions，模板才会生效。

## 版本与迭代

版本号规则、构建/打 tag/上传 Release 的完整流程、根据反馈迭代的步骤与检查清单，均在 `docs/RELEASE.md`。
