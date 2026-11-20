#!/usr/bin/env bash
# WheelVolume 安装脚本：复制 App 到「应用程序」并配置 LaunchAgent 登录自启
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_APP="${1:-$ROOT/dist/WheelVolume.app}"
DEST_APP="/Applications/WheelVolume.app"
AGENT="$HOME/Library/LaunchAgents/com.shanlin.WheelVolume.plist"
LABEL="com.shanlin.WheelVolume"

echo "==> WheelVolume 安装"

if [ "$(uname -m)" != "arm64" ]; then
    echo "错误：仅支持 Apple Silicon (arm64)。" >&2
    exit 1
fi

if [ ! -d "$SRC_APP" ]; then
    echo "错误：找不到源 App：$SRC_APP" >&2
    echo "请先执行 ./Scripts/build.sh 或从 Release 下载 DMG。" >&2
    exit 1
fi

# 1) 停止旧服务
launchctl unload "$AGENT" 2>/dev/null || true

# 2) 复制 App
echo "==> 安装到 $DEST_APP"
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"

# 3) 写入 LaunchAgent
mkdir -p "$(dirname "$AGENT")"
cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DEST_APP/Contents/MacOS/WheelVolume</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/wheelvolume/out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/wheelvolume/err.log</string>
</dict>
</plist>
EOF

# 4) 加载自启
echo "==> 配置开机自启"
launchctl load -w "$AGENT" 2>/dev/null || echo "提示：launchctl 未能立即加载，将在下次登录后自动生效。"

echo
echo "==> 安装完成。"
echo "接下来请授予辅助功能权限："
echo "  系统设置 → 隐私与安全性 → 辅助功能 → 勾选 WheelVolume"
echo "（如未自动弹出授权窗口，手动打开一次 $DEST_APP）"
echo
echo "验证：按住 Option + 滚轮，上滑减小音量、下滑增加音量。"
