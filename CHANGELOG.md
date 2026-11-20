# 更新日志

本项目所有重要变更都会记录在此文件中。
格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

（暂无）

## [1.0.0] - 2026-11-19

首个公开版本。

### 新增

- Option / Fn + 滚轮无级调节系统音量，默认 2%/格，走 CoreAudio 底层。
- 方向：默认上滑减小音量、下滑增加音量，可通过 `invert` 反转。
- 轻量音量浮层，0.8 秒自动消失，可关闭。
- 静音状态下向下滚动自动解除静音。
- 用户配置：`~/Library/Application Support/WheelVolume/config.json`，支持步进、响应间隔、触发键、方向、浮层开关。
- `install.sh` 一键安装并配置 LaunchAgent 开机自启。
- `build.sh` 一键构建 `arm64` 的 `.app` / `.dmg` / `.zip` 发布物。
- 命令行参数 `--version` / `--help`。
- Apple Silicon 运行时校验，拒绝 Rosetta 环境。
- 完整开源项目文档、Issue/PR 模板、CI 构建工作流。

[Unreleased]: https://github.com/googlemr/WheelVolume/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/googlemr/WheelVolume/releases/tag/v1.0.0
