#!/bin/bash
#
# WheelVolume 一键安装（可选，拖拽安装失败时使用）
#
# 作用：停止旧版本 → 清理 v1.x 脚本安装残留 → 复制到 /Applications
#       → 清除隔离标记 → 校验签名 → 启动。
#
# 说明：本工具没有 Apple 付费开发者证书，无法做公证（notarization）。
#       从网络下载的文件会被打上 com.apple.quarantine，Gatekeeper 可能拦截。
#       本脚本按 Apple 官方文档提供的方式（用户主动执行安装脚本）清除该标记。

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/WheelVolume.app"
DEST="/Applications/WheelVolume.app"
LEGACY_AGENT="$HOME/Library/LaunchAgents/com.dushanlin.WheelVolume.plist"

pause() { read -n 1 -s -r -p "按任意键关闭此窗口..." || true; }

echo "================================================"
echo "  WheelVolume 安装程序"
echo "================================================"
echo

if [ ! -d "$APP" ]; then
    echo "错误：当前目录找不到 WheelVolume.app"
    echo "请从 WheelVolume 的 DMG 里运行本脚本。"
    pause; exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
    echo "错误：WheelVolume 仅支持 Apple Silicon（M 系列）Mac。"
    pause; exit 1
fi

echo "[1/6] 停止正在运行的旧版本 ..."
pkill -x WheelVolume >/dev/null 2>&1
sleep 1

echo "[2/6] 清理 v1.x 脚本安装残留 ..."
if [ -f "$LEGACY_AGENT" ]; then
    launchctl bootout "gui/$(id -u)/com.dushanlin.WheelVolume" >/dev/null 2>&1
    rm -f "$LEGACY_AGENT"
    echo "     已移除旧版开机项"
fi
if [ -d "$HOME/Applications/WheelVolume.app" ]; then
    rm -rf "$HOME/Applications/WheelVolume.app"
    echo "     已移除 ~/Applications 下的旧副本"
fi
rm -rf "$HOME/Library/Application Support/WheelVolume"
echo "     已清理旧版配置（会在首次启动时重建）"

echo "[3/6] 安装到 /Applications ..."
if [ -w /Applications ]; then
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
else
    echo "     需要管理员权限，请在弹窗中输入开机密码："
    osascript -e "do shell script \"rm -rf '$DEST'; cp -R '$APP' '$DEST'\" with administrator privileges" || {
        echo "错误：复制失败。"
        pause; exit 1
    }
fi

if [ ! -d "$DEST" ]; then
    echo "错误：安装后未找到 /Applications/WheelVolume.app"
    pause; exit 1
fi

echo "[4/6] 清除隔离标记 ..."
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
xattr -d com.apple.quarantine "$DEST" 2>/dev/null
echo "     完成"

echo "[5/6] 校验代码签名 ..."
if codesign --verify --deep --strict "$DEST" >/dev/null 2>&1; then
    echo "     签名有效"
else
    echo "     签名校验未通过，尝试本机重新签名 ..."
    codesign --force --deep --sign - "$DEST" >/dev/null 2>&1
    if codesign --verify --deep --strict "$DEST" >/dev/null 2>&1; then
        echo "     已重新签名"
    else
        echo "     警告：签名仍然异常，程序可能无法启动"
    fi
fi

echo "[6/6] 启动 WheelVolume ..."
open "$DEST"
sleep 2

if pgrep -f "WheelVolume.app/Contents/MacOS/WheelVolume" >/dev/null 2>&1; then
    echo
    echo "安装完成，程序已在菜单栏运行（扬声器图标）。"
else
    echo
    echo "已安装，但进程未启动。请打开「启动台」点击 WheelVolume 再试一次。"
fi

echo
echo "------------------------------------------------"
echo "最后一步（只需做一次）："
echo "  系统设置 > 隐私与安全性 > 辅助功能"
echo "  勾选 WheelVolume"
echo
echo "首次打开如提示「无法验证开发者」，请到"
echo "  系统设置 > 隐私与安全性 > 仍要打开"
echo "------------------------------------------------"
echo
pause
