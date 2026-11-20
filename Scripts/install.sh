#!/usr/bin/env bash
# 开发机本地安装：复制构建产物到「应用程序」并清理隔离标记
# 开机自启改由 App 内的「设置 → 登录时自动启动」控制，不再写死 LaunchAgent
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_APP="${1:-$ROOT/dist/WheelVolume.app}"
DEST_APP="/Applications/WheelVolume.app"

echo "==> 本地安装 WheelVolume"

if [ "$(uname -m)" != "arm64" ]; then
    echo "错误：仅支持 Apple Silicon (arm64)。" >&2
    exit 1
fi
if [ ! -d "$SRC_APP" ]; then
    echo "错误：找不到源 App：$SRC_APP。请先执行 ./Scripts/build.sh。" >&2
    exit 1
fi

# 1) 停止已运行实例
pkill -x WheelVolume >/dev/null 2>&1 || true
sleep 1

# 2) 清理 1.x 的脚本安装残留
launchctl bootout "gui/$(id -u)/com.dushanlin.WheelVolume" >/dev/null 2>&1 || true
rm -f "$HOME/Library/LaunchAgents/com.dushanlin.WheelVolume.plist"
rm -rf "$HOME/Applications/WheelVolume.app"

# 3) 复制并清除隔离标记
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

# 4) 校验签名（构建时已签好，正常情况下无需重签）
if codesign --verify --deep --strict "$DEST_APP" >/dev/null 2>&1; then
    echo "    签名校验通过"
else
    echo "    签名异常，重新 ad-hoc 签名"
    codesign --force --deep --sign - "$DEST_APP"
    codesign --verify --deep --strict "$DEST_APP"
fi

open "$DEST_APP"
echo
echo "==> 完成。请到 系统设置 → 隐私与安全性 → 辅助功能 勾选 WheelVolume。"
