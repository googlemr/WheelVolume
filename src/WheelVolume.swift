// WheelVolume — 用 Option/Fn + 滚轮无级调节 macOS 系统音量
// 仅支持 Apple Silicon (arm64)
// SPDX-License-Identifier: MIT

import Foundation
import CoreAudio
import CoreGraphics
import ApplicationServices
import AppKit

// MARK: - 元信息

let APP_VERSION = "1.0.0"
let APP_NAME = "WheelVolume"

// MARK: - 配置

struct Config {
    var step: Float32 = 0.02              // 每格步进，0.02 = 2%
    var minInterval: TimeInterval = 0.025 // 两次调节最小间隔（秒）
    var useOption = true                  // Option 键触发
    var useFn = true                      // Fn 键触发
    var invert = false                    // true = 反转滚轮方向
    var showOSD = true                    // 显示音量浮层
}
var config = Config()

/// 用户配置文件路径：~/Library/Application Support/WheelVolume/config.json
/// 首次运行会把 app 内的默认配置复制过去，之后以用户配置为准。
func configURL() -> URL {
    let fm = FileManager.default
    let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(APP_NAME, isDirectory: true)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let userCfg = dir.appendingPathComponent("config.json")

    if !fm.fileExists(atPath: userCfg.path) {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0])
        let bundled = exe.deletingLastPathComponent().appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: bundled) {
            try? data.write(to: userCfg)
        } else {
            let fallback = """
            {
              "step": 0.02,
              "minInterval": 0.025,
              "useOption": true,
              "useFn": true,
              "invert": false,
              "showOSD": true
            }
            """
            try? fallback.write(to: userCfg, atomically: true, encoding: .utf8)
        }
    }
    return userCfg
}

func loadConfig() {
    guard let data = try? Data(contentsOf: configURL()),
          let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        return
    }
    if let v = json["step"] as? NSNumber { config.step = Float32(v.floatValue) }
    if let v = json["minInterval"] as? NSNumber { config.minInterval = v.doubleValue }
    if let v = json["useOption"] as? Bool { config.useOption = v }
    if let v = json["useFn"] as? Bool { config.useFn = v }
    if let v = json["invert"] as? Bool { config.invert = v }
    if let v = json["showOSD"] as? Bool { config.showOSD = v }
}

// MARK: - Apple Silicon 校验

/// 通过 sysctl 检测是否运行在 Rosetta 转译环境（Intel 二进制）。
/// 本程序的发布产物是 arm64 Mach-O，Intel Mac 无法直接运行；
/// 此检查用于在源码自行编译为 x86_64 时给出明确提示。
func runningUnderRosetta() -> Bool {
    var translated: Int32 = 0
    var size = MemoryLayout<Int32>.size
    let result = withUnsafeMutablePointer(to: &translated) { ptr in
        sysctlbyname("sysctl.proc_translated", ptr, &size, nil, 0)
    }
    return result == 0 && translated == 1
}

// MARK: - CoreAudio

func defaultOutputDevice() -> AudioDeviceID {
    var device = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device)
    return device
}

func getVolume(_ device: AudioDeviceID) -> Float32 {
    var volume: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    let err = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &volume)
    return err == noErr ? volume : 0
}

func setVolume(_ device: AudioDeviceID, _ value: Float32) {
    var v = max(0, min(1, value))
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    AudioObjectSetPropertyData(device, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
}

func isMuted(_ device: AudioDeviceID) -> Bool {
    var m: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    let err = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &m)
    return err == noErr && m != 0
}

func setMuted(_ device: AudioDeviceID, _ muted: Bool) {
    var m: UInt32 = muted ? 1 : 0
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    AudioObjectSetPropertyData(device, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
}

// MARK: - 音量浮层

class VolumeOSD {
    private var window: NSWindow?
    private var label: NSTextField?
    private var fill: NSView?
    private var hideWork: DispatchWorkItem?

    init() {
        guard config.showOSD else { return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 230, height: 72),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 0.86)
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        w.hasShadow = true

        let title = NSTextField(labelWithString: "音量")
        title.textColor = .white
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 16, y: 42, width: 198, height: 17)
        w.contentView?.addSubview(title)

        let track = NSView(frame: NSRect(x: 16, y: 18, width: 198, height: 9))
        track.wantsLayer = true
        track.layer?.cornerRadius = 4.5
        track.layer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.20).cgColor
        w.contentView?.addSubview(track)

        let f = NSView(frame: NSRect(x: 16, y: 18, width: 0, height: 9))
        f.wantsLayer = true
        f.layer?.cornerRadius = 4.5
        f.layer?.backgroundColor = NSColor(calibratedRed: 0.30, green: 0.72, blue: 1.0, alpha: 1).cgColor
        w.contentView?.addSubview(f)

        self.window = w
        self.label = title
        self.fill = f
    }

    func show(_ volume: Float32, muted: Bool) {
        guard let window = window, let label = label, let fill = fill else { return }
        let pct = Int((volume * 100).rounded())
        label.stringValue = muted ? "音量 \(pct)%  （静音）" : "音量 \(pct)%"
        fill.frame.size.width = CGFloat(volume) * 198
        fill.layer?.backgroundColor = muted
            ? NSColor(calibratedWhite: 0.55, alpha: 1).cgColor
            : NSColor(calibratedRed: 0.30, green: 0.72, blue: 1.0, alpha: 1).cgColor
        window.center()
        window.orderFrontRegardless()
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.window?.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}

// MARK: - 滚轮事件回调

var lastAdjust: TimeInterval = 0
let osd = VolumeOSD()

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

    let flags = event.flags
    let optionDown = config.useOption && flags.contains(.maskAlternate)
    let fnDown = config.useFn && flags.contains(.maskSecondaryFn)
    guard optionDown || fnDown else { return Unmanaged.passUnretained(event) }

    let delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    guard delta != 0 else { return nil }

    let now = CFAbsoluteTimeGetCurrent()
    guard now - lastAdjust >= config.minInterval else { return nil }
    lastAdjust = now

    // 规格：上滑（delta < 0）减小音量，下滑（delta > 0）增加音量
    var direction: Float32 = delta < 0 ? -1 : 1
    if config.invert { direction = -direction }

    let device = defaultOutputDevice()
    var volume = getVolume(device)
    if isMuted(device) && direction > 0 { setMuted(device, false) }
    volume += direction * config.step
    setVolume(device, volume)
    osd.show(getVolume(device), muted: isMuted(device))

    return nil // 吞掉事件，页面不跟着滚动
}

// MARK: - 启动

let args = Array(CommandLine.arguments.dropFirst())
if args.contains("--version") || args.contains("-v") {
    print("\(APP_NAME) \(APP_VERSION) (arm64-apple-macos11.0)")
    exit(0)
}
if args.contains("--help") || args.contains("-h") {
    print("""
    \(APP_NAME) \(APP_VERSION) — Option/Fn + 滚轮调音量（仅 Apple Silicon）

    用法:
      WheelVolume [--version|-v] [--help|-h]

    配置文件: ~/Library/Application Support/WheelVolume/config.json
    分发说明: 解压后把 WheelVolume.app 移到「应用程序」，并在
              系统设置 → 隐私与安全性 → 辅助功能 中勾选它。
    """)
    exit(0)
}

#if !arch(arm64)
fputs("\(APP_NAME) 仅支持 Apple Silicon (arm64) 芯片的 Mac。\n", stderr)
exit(2)
#endif

if runningUnderRosetta() {
    fputs("\(APP_NAME) 不支持在 Rosetta 转译环境运行，请使用 arm64 原生版本。\n", stderr)
    exit(2)
}

loadConfig()

let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
let options = [promptKey: true] as CFDictionary
let trusted = AXIsProcessTrustedWithOptions(options)
if !trusted {
    fputs("\(APP_NAME): 缺少辅助功能权限，请在 系统设置 > 隐私与安全性 > 辅助功能 中勾选。\n", stderr)
}

let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                  options: .defaultTap, eventsOfInterest: mask,
                                  callback: tapCallback, userInfo: nil) else {
    fputs("\(APP_NAME): 无法创建事件监听（缺少辅助功能权限）。\n", stderr)
    exit(1)
}
let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
fputs("\(APP_NAME) \(APP_VERSION): 已启动（上滑减小 / 下滑增加音量）。\n", stderr)
CFRunLoopRun()
