# 常见问题（FAQ）

## 滚轮调节完全没反应

按顺序排查：

1. **是否授予辅助功能权限**：系统设置 → 隐私与安全性 → 辅助功能 → WheelVolume 已勾选。
2. **程序是否在运行**：`pgrep -fl WheelVolume` 应有输出。
3. **是否按住修饰键**：必须按住 `Option` 或 `Fn` 再滚动。
4. **日志报错**：`cat /tmp/wheelvolume/err.log`，常见为“无法创建事件监听（缺少辅助功能权限）”。
5. **改过权限后没重启**：取消勾选再重新勾选，并重启程序。

## 方向反了（上滑反而增大音量）

在配置里把 `invert` 改为 `true`，重启程序：

```bash
# 编辑配置
nano ~/Library/Application\ Support/WheelVolume/config.json
# 把 "invert": false 改成 true，保存后重启 launchctl 服务
```

## 想调得更细 / 更粗

改 `step`：`0.01` = 1%/格（更细），`0.05` = 5%/格更粗。默认 `0.02`。

## 惯性滚动一下音量跳太多

触控板或高速滚轮会产生大量连续事件。把 `minInterval` 从 `0.025` 调大到 `0.05` 秒，降低响应密度。

## 提示“无法打开，因为来自身份不明的开发者”

项目未做 Apple 开发者签名/公证（见下方说明）。处理方式：

- 右键 `WheelVolume.app` →「打开」→ 弹窗中再点「打开」；或
- 系统设置 → 隐私与安全性 → 找到 WheelVolume 的拦截提示 →「仍要打开」。

## 为什么没有签名/公证？

Apple Developer Program 年费 99 美元且需实名主体。本项目作为开源工具默认以未签名形式分发，避免绑定特定开发者账号。签名与公证的构建路径已在 [发布流程](RELEASE.md) 中标注，持有开发者证书的维护者可启用。

## Intel Mac 能用吗

不能。项目仅支持 Apple Silicon（arm64）。官方渠道未提供 x86_64 版本，也不建议用 Rosetta 运行（启动时会检测并提示）。

## 调节时页面也在滚动

正常不会——被修饰键触发的滚轮事件会被吞掉。若你使用的是某些特殊驱动（如 Logitech Options、BetterTouchTool）自定义了滚轮映射，可能导致事件绕过本机监听；尝试关闭这些工具的滚轮重映射。

## 静音状态下调节会怎样

向上滚动（减小）保持静音；向下滚动（增大）会自动解除静音并开始增大音量。

## 多个输出设备时作用于哪个

始终作用于当前系统默认输出设备。切换设备后下一次调节自动生效，无需重启。

## 如何彻底卸载

见 [安装说明 - 卸载](INSTALL.md#卸载)。

## 没有我想要的答案

到 [Issues](https://github.com/googlemr/WheelVolume/issues) 提问，或在 [Discussions](https://github.com/googlemr/WheelVolume/discussions) 发起讨论。提交前请先搜索是否已有相同问题。
