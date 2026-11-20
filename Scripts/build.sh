#!/usr/bin/env bash
# WheelVolume 构建脚本：编译 arm64 二进制 → 组装 .app → 签名 → DMG / ZIP
# 用法：./Scripts/build.sh [版本号]   默认读取源码中的 APP_VERSION
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_VERSION="${1:-$(grep -m1 'let APP_VERSION' src/WheelVolume.swift | sed -E 's/.*"([^"]+)".*/\1/')}"
DIST="$ROOT/dist"
APP="$DIST/WheelVolume.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
DMG="$DIST/WheelVolume-v${APP_VERSION}-arm64.dmg"
ZIP="$DIST/WheelVolume-v${APP_VERSION}-arm64.zip"

echo "==> WheelVolume build v${APP_VERSION}"

# 1) 环境校验
if [ "$(uname -m)" != "arm64" ]; then
    echo "错误：本工具仅支持 Apple Silicon (arm64)，当前架构为 $(uname -m)。" >&2
    exit 1
fi
if ! command -v swiftc >/dev/null 2>&1; then
    echo "错误：未找到 swiftc，请先执行 xcode-select --install。" >&2
    exit 1
fi

# 2) 清理并建立标准 bundle 结构
rm -rf "$DIST"
mkdir -p "$MACOS" "$RES"

# 3) 生成图标（无外部素材，纯代码绘制，可复现）
echo "==> 生成应用图标 ..."
swiftc -O -swift-version 5 Scripts/make-icon.swift -o "$DIST/.mkicon"
"$DIST/.mkicon" "$RES"
rm -f "$DIST/.mkicon"
rm -rf "$RES/AppIcon.iconset" "$RES/AppIcon-1024.png"

# 4) 编译 arm64 二进制
#    -swift-version 5：避免 Swift 6 严格并发检查把 UI 代码判为错误
echo "==> 编译 arm64-apple-macos13.0 ..."
swiftc -O -swift-version 5 \
    -target arm64-apple-macos13.0 \
    -o "$MACOS/WheelVolume" src/WheelVolume.swift

BUILT_ARCH="$(lipo -archs "$MACOS/WheelVolume" 2>/dev/null || echo unknown)"
echo "    产物架构: $BUILT_ARCH"
if [ "$BUILT_ARCH" != "arm64" ]; then
    echo "错误：编译产物架构不是 arm64（$BUILT_ARCH）。" >&2
    exit 1
fi

# 5) 组装 bundle
cp Resources/Info.plist "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"
chmod +x "$MACOS/WheelVolume"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$CONTENTS/Info.plist"

# 6) 整包 ad-hoc 签名
#    swiftc 产物只有链接器签名、未绑定 Info.plist 与资源，直接分发会被判定
#    "已损坏"；必须对整个 bundle 重新签名，让签名覆盖全部内容。
echo "==> 对 app bundle 签名（ad-hoc）..."
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "    签名信息："
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E "Identifier=|Format=|Signature=|Info.plist entries=|Sealed Resources" | sed 's/^/      /'

# 7) ZIP（ditto 保留符号链接与权限）
echo "==> 生成 ZIP ..."
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# 8) DMG：拖拽安装 + 一键安装脚本
echo "==> 生成 DMG ..."
STAGE="$DIST/.stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/WheelVolume.app"
ln -s /Applications "$STAGE/应用程序"
cp Resources/安装.command "$STAGE/安装.command"
chmod +x "$STAGE/安装.command"
cp Resources/安装说明.txt "$STAGE/安装说明.txt"
hdiutil create -volname "WheelVolume" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

# 9) 校验输出
echo "==> 完成。产物："
ls -lh "$APP" "$DMG" "$ZIP" | sed 's/^/    /'
echo
echo "SHA-256:"
(cd "$DIST" && shasum -a 256 \
    "WheelVolume-v${APP_VERSION}-arm64.dmg" \
    "WheelVolume-v${APP_VERSION}-arm64.zip" | tee SHA256SUMS.txt | sed 's/^/    /')

echo
echo "==> 自检 --version:"
"$MACOS/WheelVolume" --version
