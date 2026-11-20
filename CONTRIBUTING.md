# 贡献指南

感谢你考虑为 WheelVolume 做贡献。项目很小、单文件源码，欢迎任何规模的改进。

## 开发环境

- Apple Silicon Mac（arm64）
- macOS 11.0+
- Xcode Command Line Tools：`xcode-select --install`
- 基本熟悉 Swift 与 macOS 系统 API（CGEventTap / CoreAudio）

## 本地开发

```bash
git clone https://github.com/googlemr/WheelVolume.git
cd WheelVolume
git checkout -b feature/your-topic

# 快速编译调试（原生架构）
swiftc -O -o /tmp/WheelVolume src/WheelVolume.swift
/tmp/WheelVolume --version

# 完整构建（arm64 app + 发布物）
./Scripts/build.sh
```

调试运行需要辅助功能权限；可用合成滚轮事件做自动化验证（参考项目内的测试方式）。

## 代码约定

- 源码集中在 `src/WheelVolume.swift`，保持单文件、无第三方依赖。
- 注释用中文或英文均可，保持简洁。
- 新配置项需同时更新：`Config` 结构体、`loadConfig()`、`Resources/config.json`、`docs/USAGE.md`。
- 修改触发/音量逻辑后，务必实测方向（上滑减小 / 下滑增加）与无级粒度。

## 提交规范

采用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)：

```
feat: 新增 xxx
fix: 修复 xxx
docs: 更新文档
chore: 构建/依赖等杂项
refactor: 重构（不改变行为）
test: 测试相关
```

例：`fix: 修正静音状态下首次下滑未解除静音`

## Pull Request 流程

1. 从 `main` 开分支：`feature/xxx` 或 `fix/xxx`。
2. 一个 PR 只做一件事；关联对应 Issue（在描述里写 `Closes #123`）。
3. 填写 [PR 模板](../.github/PULL_REQUEST_TEMPLATE.md)，说明改动与测试情况。
4. 确保 `./Scripts/build.sh` 构建通过、`--version` 正常。
5. 提交 PR，等待 review；按反馈修改后合并。

## 报告问题

用 Issue 模板提交；安全漏洞走私有渠道，见 [反馈渠道](docs/FEEDBACK.md)。

## 行为准则

参与即表示同意 [行为准则](CODE_OF_CONDUCT.md)。
