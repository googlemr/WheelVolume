#!/usr/bin/env bash
# WheelVolume 构建脚本：编译 arm64 二进制，组装 .app，生成 DMG/ZIP
# 用法：./Scripts/build.sh [版本号]   默认读取源码中的 APP_VERSION
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_VERSION="${1:-$(grep -m1 'let APP_VERSION' src/WheelVolume.swift | sed -E 's/.*"([^"]+)".*/\1/')}"
DIST="$ROOT/dist"
APP="$DIST/WheelVolume.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
DMG="$DIST/WheelVolume-v${APP_VERSION}-arm64.dmg"
ZIP="$DIST/WheelVolume-v${APP_VERSION}-arm64.zip"

echo "==> WheelVolume build v${APP_VERSION}"

# 1) 架构校验
ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ]; then
    echo "错误：本工具仅支持 Apple Silicon (arm64)，当前架构为 $ARCH。" >&2
    exit 1
fi

# 2) 编译器校验
if ! command -v swiftc >/dev/null 2>&1; then
    echo "错误：未找到 swiftc，请先执行 xcode-select --install。" >&2
    exit 1
fi

# 3) 清理并建目录
rm -rf "$DIST"
mkdir -p "$MACOS" "$CONTENTS/Resources"

# 4) 编译 arm64 二进制
echo "==> 编译 arm64-apple-macos11.0 ..."
swiftc -O -target arm64-apple-macos11.0 -o "$MACOS/WheelVolume" src/WheelVolume.swift

BUILT_ARCH="$(lipo -archs "$MACOS/WheelVolume" 2>/dev/null || echo unknown)"
echo "    产物架构: $BUILT_ARCH"
if [ "$BUILT_ARCH" != "arm64" ]; then
    echo "错误：编译产物架构不是 arm64（$BUILT_ARCH）。" >&2
    exit 1
fi

# 5) 组装 app bundle
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/config.json "$MACOS/config.json"
chmod +x "$MACOS/WheelVolume"

# 写入版本（若 Info.plist 与参数不一致则同步）
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true

# 6) 生成 ZIP（不含 __MACOSX 资源分叉，保持包干净）
echo "==> 生成 ZIP ..."
(cd "$DIST" && /usr/bin/zip -q -r -y "$ZIP" WheelVolume.app)

# 7) 生成 DMG
echo "==> 生成 DMG ..."
hdiutil create -volname "WheelVolume" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

# 8) 校验与输出
echo "==> 完成。产物："
ls -lh "$APP" "$DMG" "$ZIP"
echo
echo "SHA-256:"
shasum -a 256 "$DMG" "$ZIP"

# 写出校验清单（供 Release 附带）
(cd "$DIST" && shasum -a 256 \
  "WheelVolume-v${APP_VERSION}-arm64.dmg" \
  "WheelVolume-v${APP_VERSION}-arm64.zip" > SHA256SUMS.txt)

echo
echo "==> --version 自检:"
"$MACOS/WheelVolume" --version
