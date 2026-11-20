# 使用说明

## 基本操作

按住修饰键再滚动滚轮，即可调节系统输出音量：

| 输入 | 默认效果 |
| --- | --- |
| `Option` + 滚轮上滑 | 音量 **减小** 2% |
| `Option` + 滚轮下滑 | 音量 **增加** 2% |
| `Fn` + 滚轮上滑 / 下滑 | 同上 |
| 单独滚动滚轮 | 正常滚动页面，**不会**调音量 |

调节时屏幕中央出现音量浮层，0.8 秒后自动消失。若处于静音状态，向下滚动（增大音量）会自动解除静音。

## 为什么需要按住修饰键

全局拦截所有滚轮事件会让网页、文档无法滚动，所以 WheelVolume 只在检测到 `Option` 或 `Fn` 时才接管滚轮；被接管的事件不会继续传递给当前应用，因此页面不会同时滚动。

## 配置文件

首次运行自动生成：`~/Library/Application Support/WheelVolume/config.json`

```json
{
  "step": 0.02,
  "minInterval": 0.025,
  "useOption": true,
  "useFn": true,
  "invert": false,
  "showOSD": true
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `step` | 数字 | `0.02` | 每格音量变化量。0.02 = 2%；改 `0.01` 更细腻，`0.05` 更激进。有效范围 0–1 |
| `minInterval` | 数字 | `0.025` | 两次调节最小间隔（秒）。越小越跟手；惯性滚动过猛可调大到 0.05 |
| `useOption` | 布尔 | `true` | 是否允许 Option 键触发 |
| `useFn` | 布尔 | `true` | 是否允许 Fn 键触发。若 Fn 与系统功能冲突可关掉 |
| `invert` | 布尔 | `false` | 反转方向。改成 `true` 后变为上滑增大、下滑减小 |
| `showOSD` | 布尔 | `true` | 是否显示音量浮层 |

修改配置后需重启程序生效：

```bash
launchctl unload ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist
launchctl load   ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist
```

## 命令行参数

```bash
WheelVolume --version   # 或 -v：打印版本与架构
WheelVolume --help      # 或 -h：打印简要用法
```

无参数启动即进入常驻监听模式（无窗口、无 Dock 图标）。

## 自启管理

```bash
# 查看运行状态
pgrep -fl WheelVolume

# 停止 / 启动
launchctl unload ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist
launchctl load   ~/Library/LaunchAgents/com.shanlin.WheelVolume.plist

# 查看日志
cat /tmp/wheelvolume/err.log
```

## 输出设备切换

WheelVolume 始终作用于**当前系统默认输出设备**。切换到蓝牙耳机、显示器扬声器后无需重启，下一次调节会自动作用于新设备。
