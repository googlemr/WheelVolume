// 生成 AppIcon.iconset 与 AppIcon.icns（macOS 26 圆角方形规范）
// 用法: swiftc -O Scripts/make-icon.swift -o /tmp/mkicon && /tmp/mkicon <输出目录>

import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Resources"
let iconset = URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus(); return img
    }
    ctx.setShouldAntialias(true)

    // macOS 图标留白规范：主体约占画布 81%，四周留透明边距
    let inset = size * 0.094
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.2237

    let body = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    body.close()

    // 阴影（系统图标自带柔和落影）
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
                  blur: size * 0.03,
                  color: NSColor.black.withAlphaComponent(0.28).cgColor)
    NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.86, alpha: 1).setFill()
    body.fill()
    ctx.restoreGState()

    // 主体渐变：上浅下深
    ctx.saveGState()
    body.addClip()
    let colors = [
        NSColor(calibratedRed: 0.36, green: 0.66, blue: 1.00, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.93, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.09, green: 0.26, blue: 0.72, alpha: 1).cgColor
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors as CFArray,
                              locations: [0.0, 0.55, 1.0])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY),
                           options: [])

    // 顶部柔光：径向渐变，边界自然过渡（用椭圆填充会留下可见接缝）
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor.white.withAlphaComponent(0.24).cgColor,
                                   NSColor.white.withAlphaComponent(0.0).cgColor] as CFArray,
                          locations: [0.0, 1.0])!
    ctx.drawRadialGradient(glow,
                           startCenter: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.06),
                           startRadius: 0,
                           endCenter: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.06),
                           endRadius: rect.width * 0.78,
                           options: [])
    ctx.restoreGState()

    // 内描边，让边缘更立体
    ctx.saveGState()
    let inner = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.002, dy: size * 0.002),
                             xRadius: radius, yRadius: radius)
    inner.lineWidth = max(1, size * 0.004)
    NSColor.white.withAlphaComponent(0.22).setStroke()
    inner.stroke()
    ctx.restoreGState()

    // 白色扬声器符号（模板图需手动着色，否则以黑色绘制）
    let symSize = rect.width * 0.44
    let config = NSImage.SymbolConfiguration(pointSize: symSize, weight: .medium)
    if let base = NSImage(systemSymbolName: "speaker.wave.3.fill",
                          accessibilityDescription: "音量")?
        .withSymbolConfiguration(config) {
        let s = base.size
        let scale = min(symSize / max(s.width, 1), symSize / max(s.height, 1))
        let w = s.width * scale
        let h = s.height * scale
        let target = NSRect(x: rect.midX - w / 2 + rect.width * 0.02,
                            y: rect.midY - h / 2,
                            width: w, height: h)

        let white = NSImage(size: NSSize(width: w, height: h))
        white.lockFocus()
        base.draw(in: NSRect(x: 0, y: 0, width: w, height: h),
                  from: .zero, operation: .sourceOver, fraction: 1.0)
        NSColor.white.set()
        NSRect(x: 0, y: 0, width: w, height: h).fill(using: .sourceAtop)
        white.unlockFocus()

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.006),
                      blur: size * 0.014,
                      color: NSColor.black.withAlphaComponent(0.22).cgColor)
        white.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.restoreGState()
    }

    img.unlockFocus()
    return img
}

func writePNG(_ image: NSImage, pixels: Int, url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let master = drawIcon(size: 1024)
let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]
for (px, name) in specs {
    writePNG(master, pixels: px, url: iconset.appendingPathComponent(name))
}
writePNG(master, pixels: 1024, url: URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon-1024.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path,
               "-o", URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon.icns").path]
try! p.run()
p.waitUntilExit()
print("iconutil exit: \(p.terminationStatus)")
