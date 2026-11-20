# WheelVolume 开源交付清单

本项目已按可直接开源发布的标准准备完毕。仓库根目录：
`/Users/d/WorkBuddy/2026-11-19-17-14-07/WheelVolume`

## 交付内容

### 代码与资源

| 文件 | 说明 |
| --- | --- |
| `src/WheelVolume.swift` | 全部源码，单文件、无第三方依赖，已编译验证 |
| `Resources/Info.plist` | App 元数据（版本 1.0.0、LSUIElement、arm64） |
| `Resources/config.json` | 默认配置模板 |
| `Scripts/build.sh` | 一键构建（校验 arm64 → 编译 → app → DMG/ZIP → 校验值） |
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

## 唯一待你操作：推送到 GitHub（约 2 分钟）

我检测到的 GitHub 账号是 `googlemr`，文档链接已按此写好。我尝试用当前集成的 GitHub token 自动创建仓库，但被拒绝（HTTP 403：Resource not accessible by integration）——该 token 无建仓权限，这是授权范围限制，无法通过代码绕过。所以最后一步需要你在终端亲自执行。

**第一步（一次性，网页操作）**：打开 https://github.com/new ，仓库名填 `WheelVolume`，保持**空仓库**（不要勾 README / license / .gitignore），点 Create repository。

**第二步**：在终端只粘贴下面这一行（不要复制带中文注释的多行命令——注释里的括号会导致 `zsh: parse error`）：

```bash
bash "/Users/d/WorkBuddy/2026-11-19-17-14-07/WheelVolume/publish.sh"
```

`publish.sh` 已包含 init、commit、绑定 remote、push、打 tag、push tag 全部步骤，且预设了 git 身份。 push 时会弹 GitHub 登录窗口，用浏览器或 Personal Access Token 完成认证即可（本机当前没有任何 git 凭据，这是唯一必须由你完成的人工认证）。

**Release 会自动生成**：push 了 `v*` tag 后，`.github/workflows/build.yml` 会在 macos-14 (arm64) runner 上编译、生成 DMG/ZIP、校验 SHA-256，并自动创建 Release 把 `.dmg`/`.zip`/`SHA256SUMS.txt` 上传为可下载资产（`body` 取自 CHANGELOG）。你无需手动上传二进制。

手动上传仅在你想不用 CI 时才有必要：仓库 Releases 页 → Draft a new release → Tag `v1.0.0` → 上传 `dist/` 三个资产。

> 若你的 GitHub 用户名不是 `googlemr`，全局替换文档链接：
> `grep -rl "googlemr/WheelVolume" . | xargs sed -i '' 's|googlemr/WheelVolume|<你的用户名>/WheelVolume|g'`
> 并相应修改上面 `git remote add origin` 的地址。

## 发布后需回补的两点

1. **签名/公证**：当前为未签名产物，用户首次打开需右键「打开」。持有 Apple Developer 证书时按 `docs/RELEASE.md` 第 7 步启用签名与公证。
2. **Issue/Discussion 板块**：在仓库 Settings → Features 里勾选 Issues 和 Discussions，模板才会生效。

## 版本与迭代

版本号规则、构建/打 tag/上传 Release 的完整流程、根据反馈迭代的步骤与检查清单，均在 `docs/RELEASE.md`。
