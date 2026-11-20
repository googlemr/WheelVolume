# 发布流程与版本命名规则

## 版本命名规则

采用 [语义化版本 2.0.0](https://semver.org/lang/zh-CN/)：`MAJOR.MINOR.PATCH`

- **MAJOR**：不兼容的变更（如触发方式彻底改变）
- **MINOR**：新增向后兼容的功能（如新增配置项、浮层样式）
- **PATCH**：向后兼容的 bug 修复

当前版本：`2.0.0`

### 资产文件命名

```
WheelVolume-v<VERSION>-arm64.dmg
WheelVolume-v<VERSION>-arm64.zip
```

示例：`WheelVolume-v2.0.0-arm64.dmg`

- `v` 前缀与 GitHub Release tag 一致（tag 为 `v2.0.0`）
- `arm64` 明确架构，避免用户误下载
- DMG 供普通用户，ZIP 供脚本化部署

### 预发布版本

- 候选发布：`v1.1.0-rc.1`
- 测试版：`v1.1.0-beta.1`

预发布版在 GitHub 创建 Release 时勾选「Set as a pre-release」。

## 一次完整发布

### 1. 准备

```bash
# 确认在 arm64 Mac 上
uname -m                    # 应为 arm64

# 安装 Command Line Tools（如需要）
xcode-select --install
```

### 2. 更新版本字符串

同步修改三处版本号：

- `src/WheelVolume.swift` 中的 `APP_VERSION`
- `Resources/Info.plist` 中的 `CFBundleVersion` 与 `CFBundleShortVersionString`
- `CHANGELOG.md` 顶部新增版本段落

### 3. 构建

```bash
./Scripts/build.sh
```

脚本会：

1. 校验架构为 arm64，否则退出
2. 编译 `arm64-apple-macos13.0` 二进制
3. 组装 `WheelVolume.app`（写入 Info.plist、绘制并嵌入 AppIcon.icns）
4. 生成 DMG 与 ZIP 到 `dist/`
5. 打印 SHA-256 校验值

### 4. 本地验收

```bash
# 版本与架构
./dist/WheelVolume.app/Contents/MacOS/WheelVolume --version

# 方向验证（见 USAGE.md）：上滑减小、下滑增加
# 权限验证：首次运行能弹出辅助功能授权
# 自启验证：install.sh 后重启登录生效
```

### 5. 提交与打 tag

```bash
git add -A
git commit -m "release: v2.0.0"
git tag -a v2.0.0 -m "WheelVolume v2.0.0"
git push origin main --tags
```

### 6. 创建 GitHub Release

在 GitHub 仓库页面 → Releases → Draft a new release：

- Tag：`v2.0.0`
- Title：`WheelVolume v2.0.0`
- 描述：粘贴 `CHANGELOG.md` 中该版本的内容
- 上传资产：`dist/WheelVolume-v2.0.0-arm64.dmg`、`dist/WheelVolume-v2.0.0-arm64.zip`
- 发布（预发布版勾选 pre-release）

### 7. 签名（可选，持有开发者证书时）

当前发布物未签名/公证。若维护者有 Apple Developer 账号，可在构建脚本中启用：

```bash
codesign --force --deep --sign "Developer ID Application: <Name> (<TEAMID>)" \
  --options runtime --timestamp dist/WheelVolume.app

# 公证（需 xcrun notarytool 配置凭据）
xcrun notarytool submit dist/WheelVolume-v2.0.0-arm64.zip \
  --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple dist/WheelVolume.app
```

签名后重新打包 DMG/ZIP 再上传。

## 根据反馈迭代

1. **收集**：用户通过 Issue 模板提交 bug 或功能建议；维护者定期查看 [Issues](https://github.com/googlemr/WheelVolume/issues)。
2. **分类打标**：使用 label（bug / enhancement / question / wontfix / duplicate）。
3. **复现与定位**：要求提供系统版本、芯片、WheelVolume 版本、`/tmp/wheelvolume/err.log`。
4. **开发**：从 `main` 切分支（`fix/xxx`、`feature/xxx`），按 [贡献指南](../CONTRIBUTING.md) 提交 PR。
5. **合并与沉淀**：合并后在 `CHANGELOG.md` 的 `Unreleased` 段落记录变更。
6. **发版**：累积到一定变更后，按上文流程发新版本，在相关 Issue 中回复"已在 vX.Y.Z 修复"并关闭。

## 发布检查清单

- [ ] 版本号三处同步（源码 / Info.plist / CHANGELOG）
- [ ] `CHANGELOG.md` 已更新
- [ ] `./Scripts/build.sh` 构建成功，架构 arm64
- [ ] `--version` 输出正确
- [ ] 方向、权限、自启三项实测通过
- [ ] DMG / ZIP 命名规范、SHA-256 已记录
- [ ] git tag 已推送
- [ ] GitHub Release 已创建并上传资产
- [ ] 相关 Issue 已回复
