// WheelVolume — 用 Option / Fn(地球键) + 滚轮无级调节 macOS 系统音量
// 仅支持 Apple Silicon (arm64)
// SPDX-License-Identifier: MIT

import Foundation
import AppKit
import SwiftUI
import CoreAudio
import CoreGraphics
import ApplicationServices

// MARK: - 元信息

let APP_VERSION = "2.0.0"
let APP_NAME = "WheelVolume"
let BUNDLE_ID = "com.shanlin.WheelVolume"
let AX_PANE_URL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

// MARK: - 偏好设置

struct Prefs {
    var step: Float32 = 0.02          // 每格步进（0.02 = 2%）
    var minInterval: Double = 0.025   // 两次调节的最小间隔（秒）
    var useOption = true              // Option(⌥) 触发
    var useFn = true                  // Fn / 地球键 触发
    var invert = false                // 反转方向
    var showOSD = true                // 显示音量浮层
    var showPercentInMenuBar = false  // 菜单栏显示百分比
    var launchAtLogin = false         // 开机自动启动
}

/// 运行期快照：滚轮回调在主线程序列读取，界面改动时同步刷新。
var prefs = Prefs()

enum PrefKey {
    static let step = "step"
    static let minInterval = "minInterval"
    static let useOption = "useOption"
    static let useFn = "useFn"
    static let invert = "invert"
    static let showOSD = "showOSD"
    static let showPercentInMenuBar = "showPercentInMenuBar"
    static let launchAtLogin = "launchAtLogin"

    static let all = [step, minInterval, useOption, useFn, invert, showOSD,
                      showPercentInMenuBar, launchAtLogin]
}

/// 读取用户设置。首次运行会把 v1.x 的 config.json 迁移过来。
func loadPrefs() -> Prefs {
    let d = UserDefaults.standard
    var p = Prefs()
    if d.object(forKey: PrefKey.step) != nil {
        p.step = Float32(d.double(forKey: PrefKey.step))
        p.minInterval = d.double(forKey: PrefKey.minInterval)
        p.useOption = d.bool(forKey: PrefKey.useOption)
        p.useFn = d.bool(forKey: PrefKey.useFn)
        p.invert = d.bool(forKey: PrefKey.invert)
        p.showOSD = d.bool(forKey: PrefKey.showOSD)
        p.showPercentInMenuBar = d.bool(forKey: PrefKey.showPercentInMenuBar)
        p.launchAtLogin = d.bool(forKey: PrefKey.launchAtLogin)
        return p
    }

    // v1.x 迁移：~/Library/Application Support/WheelVolume/config.json
    let fm = FileManager.default
    if let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        let legacy = base.appendingPathComponent(APP_NAME, isDirectory: true)
            .appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: legacy),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let v = json["step"] as? NSNumber { p.step = Float32(v.doubleValue) }
            if let v = json["minInterval"] as? NSNumber { p.minInterval = v.doubleValue }
            if let v = json["useOption"] as? Bool { p.useOption = v }
            if let v = json["useFn"] as? Bool { p.useFn = v }
            if let v = json["invert"] as? Bool { p.invert = v }
            if let v = json["showOSD"] as? Bool { p.showOSD = v }
            try? fm.removeItem(at: legacy)
        }
    }
    return p
}

// MARK: - 开机启动（LaunchAgent）

enum LoginItem {
    static let label = BUNDLE_ID
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    static func set(_ on: Bool) {
        on ? write() : remove()
    }

    private static func write() {
        let fm = FileManager.default
        try? fm.createDirectory(at: plistURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        // 用 open -g 交给 LaunchServices，避免重复实例与激活抢占前台
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-g", "-a", Bundle.main.bundlePath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive"
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict,
                                                             format: .xml, options: 0) else { return }
        try? data.write(to: plistURL)
        _ = run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    private static func remove() {
        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardError = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}

// MARK: - 应用状态（设置界面 ↔ 运行时）

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var step: Double { didSet { persist() } }
    @Published var minInterval: Double { didSet { persist() } }
    @Published var useOption: Bool { didSet { persist() } }
    @Published var useFn: Bool { didSet { persist() } }
    @Published var invert: Bool { didSet { persist() } }
    @Published var showOSD: Bool { didSet { persist() } }
    @Published var showPercentInMenuBar: Bool { didSet { persist() } }
    @Published var launchAtLogin: Bool { didSet { persist(); LoginItem.set(launchAtLogin) } }
    @Published var trusted: Bool = false

    private var loading = false

    private init() {
        let p = loadPrefs()
        loading = true
        step = Double(p.step)
        minInterval = p.minInterval
        useOption = p.useOption
        useFn = p.useFn
        invert = p.invert
        showOSD = p.showOSD
        showPercentInMenuBar = p.showPercentInMenuBar
        launchAtLogin = LoginItem.isEnabled
        loading = false
        push()
    }

    /// 写回 UserDefaults
    private func persist() {
        guard !loading else { return }
        let d = UserDefaults.standard
        d.set(step, forKey: PrefKey.step)
        d.set(minInterval, forKey: PrefKey.minInterval)
        d.set(useOption, forKey: PrefKey.useOption)
        d.set(useFn, forKey: PrefKey.useFn)
        d.set(invert, forKey: PrefKey.invert)
        d.set(showOSD, forKey: PrefKey.showOSD)
        d.set(showPercentInMenuBar, forKey: PrefKey.showPercentInMenuBar)
        d.set(launchAtLogin, forKey: PrefKey.launchAtLogin)
        push()
        NotificationCenter.default.post(name: .wheelVolumePrefsChanged, object: nil)
    }

    /// 同步到运行期快照
    func push() {
        prefs.step = Float32(step)
        prefs.minInterval = minInterval
        prefs.useOption = useOption
        prefs.useFn = useFn
        prefs.invert = invert
        prefs.showOSD = showOSD
        prefs.showPercentInMenuBar = showPercentInMenuBar
        prefs.launchAtLogin = launchAtLogin
    }

    func reset() {
        loading = true
        let p = Prefs()
        step = Double(p.step)
        minInterval = p.minInterval
        useOption = p.useOption
        useFn = p.useFn
        invert = p.invert
        showOSD = p.showOSD
        showPercentInMenuBar = false
        loading = false
        persist()
    }
}

extension Notification.Name {
    static let wheelVolumePrefsChanged = Notification.Name("WheelVolumePrefsChanged")
}

// MARK: - CoreAudio 音量

enum Volume {
    static func defaultOutput() -> AudioDeviceID {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                             &addr, 0, nil, &size, &device)
        return err == noErr ? device : 0
    }

    /// 依次尝试主元素与声道元素，兼容不支持主音量的外置声卡 / 显示器
    private static let candidates: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]

    private static func address(_ selector: AudioObjectPropertySelector,
                                _ element: UInt32) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: element)
    }

    static func get(_ device: AudioDeviceID) -> Float32? {
        guard device != 0 else { return nil }
        for el in candidates {
            var addr = address(kAudioDevicePropertyVolumeScalar, el)
            guard AudioObjectHasProperty(device, &addr) else { continue }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr {
                return max(0, min(1, value))
            }
        }
        return nil
    }

    @discardableResult
    static func set(_ device: AudioDeviceID, _ value: Float32) -> Bool {
        guard device != 0 else { return false }
        var v = max(0, min(1, value))
        for el in candidates {
            var addr = address(kAudioDevicePropertyVolumeScalar, el)
            guard AudioObjectHasProperty(device, &addr) else { continue }
            if AudioObjectSetPropertyData(device, &addr, 0, nil,
                                          UInt32(MemoryLayout<Float32>.size), &v) == noErr {
                return true
            }
        }
        return false
    }

    static func isMuted(_ device: AudioDeviceID) -> Bool {
        guard device != 0 else { return false }
        for el in candidates {
            var addr = address(kAudioDevicePropertyMute, el)
            guard AudioObjectHasProperty(device, &addr) else { continue }
            var m: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &m) == noErr {
                return m != 0
            }
        }
        return false
    }

    static func setMuted(_ device: AudioDeviceID, _ muted: Bool) {
        guard device != 0 else { return }
        var m: UInt32 = muted ? 1 : 0
        for el in candidates {
            var addr = address(kAudioDevicePropertyMute, el)
            guard AudioObjectHasProperty(device, &addr) else { continue }
            if AudioObjectSetPropertyData(device, &addr, 0, nil,
                                          UInt32(MemoryLayout<UInt32>.size), &m) == noErr {
                return
            }
        }
    }
}

// MARK: - 音量浮层（HUD）

final class VolumeHUD {
    private var panel: NSPanel?
    private var barFill: NSView?
    private var barTrack: NSView?
    private var percentLabel: NSTextField?
    private var iconView: NSImageView?
    private var hideTask: DispatchWorkItem?

    private let width: CGFloat = 236
    private let height: CGFloat = 84
    private let barWidth: CGFloat = 150

    private func build() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 18
        blur.layer?.masksToBounds = true
        p.contentView = blur

        let icon = NSImageView(frame: NSRect(x: 18, y: 30, width: 26, height: 26))
        icon.image = NSImage(systemSymbolName: "speaker.wave.2.fill",
                             accessibilityDescription: "音量")
        icon.contentTintColor = .white
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        blur.addSubview(icon)
        iconView = icon

        let label = NSTextField(labelWithString: "0%")
        label.frame = NSRect(x: 52, y: 48, width: 70, height: 20)
        label.textColor = .white
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        blur.addSubview(label)
        percentLabel = label

        let track = NSView(frame: NSRect(x: 52, y: 28, width: barWidth, height: 8))
        track.wantsLayer = true
        track.layer?.cornerRadius = 4
        track.layer?.backgroundColor = NSColor(white: 1, alpha: 0.22).cgColor
        blur.addSubview(track)
        barTrack = track

        let fill = NSView(frame: NSRect(x: 52, y: 28, width: 0, height: 8))
        fill.wantsLayer = true
        fill.layer?.cornerRadius = 4
        fill.layer?.backgroundColor = NSColor(white: 1, alpha: 0.95).cgColor
        blur.addSubview(fill)
        barFill = fill

        return p
    }

    func show(volume: Float32, muted: Bool) {
        guard prefs.showOSD else { return }
        let p = panel ?? build()
        panel = p

        let pct = Int((volume * 100).rounded())
        percentLabel?.stringValue = muted ? "静音" : "\(pct)%"
        let symbol = muted ? "speaker.slash.fill"
            : (pct == 0 ? "speaker.fill" : (pct < 40 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"))
        iconView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "音量")
        barFill?.frame.size.width = muted ? 0 : CGFloat(volume) * barWidth
        barTrack?.layer?.backgroundColor = NSColor(white: 1, alpha: muted ? 0.14 : 0.22).cgColor

        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let origin = NSPoint(x: vf.midX - width / 2, y: vf.minY + 96)
            p.setFrameOrigin(origin)
        }
        if !p.isVisible {
            p.alphaValue = 0
            p.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.13
                p.animator().alphaValue = 1
            }
        } else {
            p.orderFrontRegardless()
        }

        hideTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.fadeOut() }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: task)
    }

    private func fadeOut() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            p.animator().alphaValue = 0
        }, completionHandler: {
            p.orderOut(nil)
        })
    }
}

// MARK: - 滚轮监听

final class ScrollTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var lastAdjust: CFAbsoluteTime = 0
    var onScroll: ((Bool) -> Void)?   // true = 增加音量

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        guard AXIsProcessTrusted() else { return false }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cghidEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: mask,
                                           callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<ScrollTap>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }, userInfo: refcon) else {
            return false
        }

        tap = port
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
    }

    /// 回调必须极快返回，否则系统会因超时禁用事件监听
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

        let flags = event.flags
        let optionDown = prefs.useOption && flags.contains(.maskAlternate)
        let fnDown = prefs.useFn && flags.contains(.maskSecondaryFn)
        guard optionDown || fnDown else { return Unmanaged.passUnretained(event) }

        let delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        guard delta != 0 else { return Unmanaged.passUnretained(event) }

        let now = CFAbsoluteTimeGetCurrent()
        if prefs.minInterval > 0, now - lastAdjust < prefs.minInterval {
            return nil
        }
        lastAdjust = now

        // 规格：上滑（delta < 0）减小音量，下滑增加音量
        var increase = delta > 0
        if prefs.invert { increase.toggle() }
        onScroll?(increase)

        return nil   // 吞掉事件，页面不跟随滚动
    }
}

// MARK: - 设置界面

struct StepPreset: Identifiable {
    let title: String
    let value: Double
    var id: Double { value }

    static let all: [StepPreset] = [
        StepPreset(title: "精细 1%", value: 0.01),
        StepPreset(title: "标准 2%", value: 0.02),
        StepPreset(title: "快速 5%", value: 0.05),
        StepPreset(title: "很粗 10%", value: 0.1)
    ]
}

struct SettingsView: View {
    @ObservedObject var s: AppState

    private var stepText: String {
        String(format: "%.1f%%", s.step * 100)
    }

    var body: some View {
        Form {
            Section("运行状态") {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: s.trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(s.trusted ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.trusted ? "已获得辅助功能权限" : "缺少「辅助功能」权限")
                            .fontWeight(.medium)
                        Text(s.trusted
                             ? "按住 Option(⌥) 或 Fn 滚动滚轮即可调节音量。"
                             : "在系统设置中勾选 WheelVolume 后才能监听滚轮。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                    if !s.trusted {
                        Button("去授权") { Actions.requestAccessibility() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }

            Section("触发键") {
                Toggle("按住 Option (⌥) 时响应滚轮", isOn: $s.useOption)
                Toggle("按住 Fn / 地球键时响应滚轮", isOn: $s.useFn)
                if !s.useOption && !s.useFn {
                    Text("两个触发键都已关闭，滚轮不会调节音量。")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Section("调节精细度") {
                HStack(spacing: 10) {
                    Text("每格")
                    Slider(value: $s.step, in: 0.002...0.1)
                        .frame(minWidth: 180)
                    Text(stepText)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
                HStack(spacing: 8) {
                    ForEach(StepPreset.all) { preset in
                        Button(preset.title) { s.step = preset.value }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Spacer()
                }
            }

            Section("手感与外观") {
                Picker("调节间隔", selection: $s.minInterval) {
                    Text("极顺滑（不限制）").tag(0.0)
                    Text("顺滑（25 毫秒）").tag(0.025)
                    Text("稳重（60 毫秒）").tag(0.06)
                    Text("省力（120 毫秒）").tag(0.12)
                }
                .pickerStyle(.menu)
                Toggle("反转方向（下滑减小、上滑增大）", isOn: $s.invert)
                Toggle("显示音量浮层", isOn: $s.showOSD)
                Toggle("在菜单栏显示音量百分比", isOn: $s.showPercentInMenuBar)
            }

            Section("启动") {
                Toggle("登录时自动启动", isOn: $s.launchAtLogin)
            }

            Section {
                HStack(spacing: 8) {
                    Text("v\(APP_VERSION) · Apple Silicon")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("恢复默认") { s.reset() }
                        .controlSize(.small)
                    Button("退出") { NSApp.terminate(nil) }
                        .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 730)
    }
}

// MARK: - 全局动作

enum Actions {
    /// 触发系统授权弹窗（会把 App 自动加入辅助功能列表），再打开设置面板
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        openAccessibilitySettings()
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: AX_PANE_URL) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let tap = ScrollTap()
    private let hud = VolumeHUD()
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private let state = AppState.shared
    private var menuVolumeItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        buildStatusItem()
        tap.onScroll = { [weak self] increase in self?.adjust(increase: increase) }
        refreshPermission(prompt: true)

        // 权限状态可能在系统设置里被改动，低频轮询即可
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermission(prompt: false)
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer

        NotificationCenter.default.addObserver(forName: .wheelVolumePrefsChanged,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.refreshStatusTitle()
        }

        // 首次安装：无权限时直接把设置页摆出来，避免用户对着菜单栏猜
        if !state.trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.openSettings()
            }
        } else {
            openSettingsOnFirstRunIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        tap.stop()
    }

    // MARK: 菜单栏

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2",
                                   accessibilityDescription: "WheelVolume")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.toolTip = "WheelVolume — 滚轮调音量"
        }

        let menu = NSMenu()
        menu.delegate = self

        menuVolumeItem = NSMenuItem(title: "音量 —", action: nil, keyEquivalent: "")
        menuVolumeItem.isEnabled = false
        menu.addItem(menuVolumeItem)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let auth = NSMenuItem(title: "打开辅助功能设置…",
                              action: #selector(openAX), keyEquivalent: "")
        auth.target = self
        menu.addItem(auth)

        let login = NSMenuItem(title: "登录时自动启动",
                               action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        menu.addItem(login)
        menu.addItem(.separator())

        let about = NSMenuItem(title: "关于 WheelVolume", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "退出 WheelVolume", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        refreshStatusTitle()
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let v = Volume.get(Volume.defaultOutput()) {
            let pct = Int((v * 100).rounded())
            menuVolumeItem.title = Volume.isMuted(Volume.defaultOutput())
                ? "音量 \(pct)%（静音）" : "音量 \(pct)%"
        } else {
            menuVolumeItem.title = "当前输出设备不支持音量控制"
        }
        menu.items.first { $0.action == #selector(toggleLogin) }?.state =
            LoginItem.isEnabled ? .on : .off
    }

    private func refreshStatusTitle() {
        guard let button = statusItem?.button else { return }
        if state.showPercentInMenuBar, let v = Volume.get(Volume.defaultOutput()) {
            button.title = " \(Int((v * 100).rounded()))%"
        } else {
            button.title = ""
        }
        button.contentTintColor = state.trusted ? nil : .secondaryLabelColor
    }

    @objc private func toggleLogin() {
        state.launchAtLogin.toggle()
        refreshStatusTitle()
    }

    @objc private func openAX() {
        Actions.openAccessibilitySettings()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: APP_NAME,
            .applicationVersion: APP_VERSION,
            .credits: NSAttributedString(
                string: "用 Option / Fn + 滚轮无级调节系统音量\n仅支持 Apple Silicon · MIT License",
                attributes: [.font: NSFont.systemFont(ofSize: 11),
                             .foregroundColor: NSColor.secondaryLabelColor])
        ])
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(s: state))
            let w = NSWindow(contentViewController: host)
            w.title = "WheelVolume 设置"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 460, height: 730))
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    // MARK: 权限与滚轮

    private func refreshPermission(prompt: Bool) {
        var trusted = AXIsProcessTrusted()
        if !trusted, prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        }
        if trusted != state.trusted {
            state.trusted = trusted
        }
        if trusted, !tap.isRunning {
            _ = tap.start()
            refreshStatusTitle()
        }
    }

    private func adjust(increase: Bool) {
        let device = Volume.defaultOutput()
        guard let current = Volume.get(device) else { return }

        if Volume.isMuted(device), increase { Volume.setMuted(device, false) }
        let next = max(0, min(1, current + (increase ? 1 : -1) * prefs.step))
        Volume.set(device, next)

        let actual = Volume.get(device) ?? next
        hud.show(volume: actual, muted: Volume.isMuted(device))
        refreshStatusTitle()
    }

    private func openSettingsOnFirstRunIfNeeded() {
        let key = "hasShownSettings"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.openSettings()
            }
        }
    }
}

// MARK: - 入口

let cliArgs = Array(CommandLine.arguments.dropFirst())
if cliArgs.contains("--version") || cliArgs.contains("-v") {
    print("\(APP_NAME) \(APP_VERSION) (arm64-apple-macos13.0)")
    exit(0)
}
if cliArgs.contains("--help") || cliArgs.contains("-h") {
    print("""
    \(APP_NAME) \(APP_VERSION) — Option/Fn + 滚轮调音量（仅 Apple Silicon）

    用法:
      WheelVolume [--version|-v] [--help|-h]

    设置: 菜单栏图标 → 设置…（调节精细度、触发键、方向、开机启动）
    权限: 系统设置 → 隐私与安全性 → 辅助功能 → 勾选 WheelVolume
    """)
    exit(0)
}

#if !arch(arm64)
fputs("\(APP_NAME) 仅支持 Apple Silicon (arm64) 芯片的 Mac。\n", stderr)
exit(2)
#endif

// 单实例：避免开机项与手动启动叠加出两个菜单栏图标
let running = NSRunningApplication.runningApplications(withBundleIdentifier: BUNDLE_ID)
if running.count > 1 {
    exit(0)
}

// 清理 v1.x 遗留的 LaunchAgent（旧版本用脚本安装）
let legacyAgent = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/LaunchAgents/com.dushanlin.WheelVolume.plist")
if FileManager.default.fileExists(atPath: legacyAgent.path) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = ["bootout", "gui/\(getuid())/com.dushanlin.WheelVolume"]
    try? p.run()
    p.waitUntilExit()
    try? FileManager.default.removeItem(at: legacyAgent)
}

/// 标准的 AppKit 启动路径：必须由 NSApplication 接管事件循环，
/// 否则 LaunchServices 收不到启动回执，Finder 会报"应用程序没有响应"。
let app = NSApplication.shared

// 离屏渲染设置界面，供开发/CI 校验排版：WheelVolume --render-settings out.png
if let i = cliArgs.firstIndex(of: "--render-settings"), i + 1 < cliArgs.count {
    let out = cliArgs[i + 1]
    let previewState = AppState.shared
    if ProcessInfo.processInfo.environment["WV_PREVIEW_TRUSTED"] == "1" {
        previewState.trusted = true
    }
    let host = NSHostingView(rootView: SettingsView(s: previewState))
    host.frame = NSRect(x: 0, y: 0, width: 460, height: 730)
    host.layoutSubtreeIfNeeded()
    if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: out))
    }
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
