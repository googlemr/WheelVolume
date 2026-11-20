#!/bin/bash
#
# WheelVolume 一键安装脚本
#
# 作用：把 WheelVolume.app 安装到 /Applications，清除 macOS 的隔离标记，
#       重新做本地 ad-hoc 签名，然后启动程序。
#
# 为什么需要这个脚本：
#   本工具没有 Apple 付费开发者证书，无法做公证（notarization）。从网络
#   下载的应用会被打上 com.apple.quarantine 标记，macOS 的 Gatekeeper 会
#   拦截并提示"已损坏，应移到废纸篓"。本脚本用 cp 复制（不继承隔离标记）
#   并显式清除 quarantine，从而绕开这个拦截。

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/WheelVolume.app"
DEST="/Applications/WheelVolume.app"

echo "================================================"
echo "  WheelVolume 一键安装"
echo "================================================"
echo

if [ ! -d "$APP" ]; then
    echo "错误：在当前目录找不到 WheelVolume.app"
    echo "请确认你是从 WheelVolume 的 DMG 或解压后的文件夹里运行本脚本。"
    echo
    read -n 1 -s -r -p "按任意键关闭窗口..."
    exit 1
fi

echo "[1/5] 停止正在运行的旧版本 ..."
osascript -e 'tell application "WheelVolume" to quit' >/dev/null 2>&1
pkill -f "WheelVolume.app/Contents/MacOS/WheelVolume" >/dev/null 2>&1
sleep 1

echo "[2/5] 复制到 /Applications ..."
if [ -w /Applications ]; then
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
else
    echo "     需要管理员权限，请输入开机密码："
    osascript -e "do shell script \"rm -rf '$DEST'; cp -R '$APP' '$DEST'\" with administrator privileges" || {
        echo "错误：复制失败。"
        read -n 1 -s -r -p "按任意键关闭窗口..."
        exit 1
    }
fi

if [ ! -d "$DEST" ]; then
    echo "错误：安装后未在 /Applications 找到 WheelVolume.app"
    read -n 1 -s -r -p "按任意键关闭窗口..."
    exit 1
fi

echo "[3/5] 清除隔离标记 ..."
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
xattr -cr "$DEST" 2>/dev/null

echo "[4/5] 本地重新签名 ..."
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1
if codesign --verify "$DEST" >/dev/null 2>&1; then
    echo "     签名校验通过"
else
    echo "     警告：签名校验未通过，程序可能无法启动"
fi

echo "[5/5] 启动 WheelVolume ..."
open "$DEST"
sleep 1

if pgrep -f "WheelVolume.app/Contents/MacOS/WheelVolume" >/dev/null 2>&1; then
    echo
    echo "安装成功，程序已在后台运行。"
else
    echo
    echo "程序已安装，但可能还没启动成功。"
    echo "请到 系统设置 > 隐私与安全性 > 辅助功能 中勾选 WheelVolume，然后重新打开。"
fi

echo
echo "------------------------------------------------"
echo "最后一步（只需做一次）："
echo "  打开 系统设置 > 隐私与安全性 > 辅助功能"
echo "  把列表里的 WheelVolume 勾选上"
echo
echo "不授权的话程序收不到滚轮事件，调不了音量。"
echo "------------------------------------------------"
echo
read -n 1 -s -r -p "按任意键关闭此窗口..."
