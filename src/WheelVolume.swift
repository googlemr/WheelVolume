// WheelVolume — 屏幕顶部边缘热区滚轮：不按 Ctrl 调音量，按住 Ctrl 调亮度
// 仅支持 Apple Silicon (arm64)
// SPDX-License-Identifier: MIT

import Foundation
import AppKit
import SwiftUI
import CoreAudio
import CoreGraphics
import ApplicationServices

// MARK: - 元信息

let APP_VERSION = "2.1.0"
let APP_NAME = "WheelVolume"
let BUNDLE_ID = "com.shanlin.WheelVolume"
let AX_PANE_URL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

// MARK: - 偏好设置

struct Prefs {
    var hotZoneHeight: Double = 8      // 屏幕顶部热区高度（点）
    var minInterval: Double = 0        // 两次调节的最小间隔（秒），0 = 每次滚动都响应
    var showPercentInMenuBar = false   // 菜单栏显示音量百分比
    var launchAtLogin = false          // 开机自动启动
}

var prefs = Prefs()

enum PrefKey {
    static let hotZoneHeight = "hotZoneHeight"
    static let minInterval = "minInterval"
    static let showPercentInMenuBar = "showPercentInMenuBar"
    static let launchAtLogin = "launchAtLogin"
}

func loadPrefs() -> Prefs {
    let d = UserDefaults.standard
    var p = Prefs()
    guard d.object(forKey: PrefKey.hotZoneHeight) != nil else { return p }
    p.hotZoneHeight = d.double(forKey: PrefKey.hotZoneHeight)
    p.minInterval = d.double(forKey: PrefKey.minInterval)
    p.showPercentInMenuBar = d.bool(forKey: PrefKey.showPercentInMenuBar)
    p.launchAtLogin = d.bool(forKey: PrefKey.launchAtLogin)
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

    static func set(_ on: Bool) { on ? write() : remove() }

    private static func write() {
        let fm = FileManager.default
        try? fm.createDirectory(at: plistURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
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

// MARK: - 应用状态

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var hotZoneHeight: Double { didSet { persist() } }
    @Published var minInterval: Double { didSet { persist() } }
    @Published var showPercentInMenuBar: Bool { didSet { persist() } }
    @Published var launchAtLogin: Bool { didSet { persist(); LoginItem.set(launchAtLogin) } }
    @Published var trusted: Bool = false
    @Published var brightnessSupported: Bool = ScreenBrightness.canChange()

    private var loading = false

    private init() {
        let p = loadPrefs()
        loading = true
        hotZoneHeight = p.hotZoneHeight
        minInterval = p.minInterval
        showPercentInMenuBar = p.showPercentInMenuBar
        launchAtLogin = LoginItem.isEnabled
        loading = false
        push()
    }

    private func persist() {
        guard !loading else { return }
        let d = UserDefaults.standard
        d.set(hotZoneHeight, forKey: PrefKey.hotZoneHeight)
        d.set(minInterval, forKey: PrefKey.minInterval)
        d.set(showPercentInMenuBar, forKey: PrefKey.showPercentInMenuBar)
        d.set(launchAtLogin, forKey: PrefKey.launchAtLogin)
        push()
        NotificationCenter.default.post(name: .wheelVolumePrefsChanged, object: nil)
    }

    func push() {
        prefs.hotZoneHeight = hotZoneHeight
        prefs.minInterval = minInterval
        prefs.showPercentInMenuBar = showPercentInMenuBar
        prefs.launchAtLogin = launchAtLogin
    }

    func reset() {
        loading = true
        let p = Prefs()
        hotZoneHeight = p.hotZoneHeight
        minInterval = p.minInterval
        showPercentInMenuBar = false
        loading = false
        persist()
    }
}

extension Notification.Name {
    static let wheelVolumePrefsChanged = Notification.Name("WheelVolumePrefsChanged")
}

// MARK: - 顶部边缘热区

enum HotZone {
    /// 使用 CoreGraphics 全局坐标：原点在主显示器左上角，y 向下增大。
    /// 多显示器时按鼠标所在显示器的上边缘计算，兼容位于主屏上方的显示器。
    static func contains(_ point: CGPoint) -> Bool {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetDisplaysWithPoint(point, 16, &ids, &count) == CGError.success, count > 0 else {
            return false
        }
        let frame = CGDisplayBounds(ids[0])
        return point.y >= frame.origin.y &&
               point.y <= frame.origin.y + CGFloat(max(0, prefs.hotZoneHeight))
    }

    static func display(for point: CGPoint) -> CGDirectDisplayID {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        if CGGetDisplaysWithPoint(point, 16, &ids, &count) == CGError.success, count > 0 {
            return ids[0]
        }
        return CGMainDisplayID()
    }
}

// MARK: - 系统音量（CoreAudio）

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

// MARK: - 系统亮度（DisplayServices 私有框架，Apple 内置显示器）

enum ScreenBrightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias BoolFn = @convention(c) (CGDirectDisplayID) -> Bool

    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn: GetFn? = {
        guard let p = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(p, to: GetFn.self)
    }()
    private static let setFn: SetFn? = {
        guard let p = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(p, to: SetFn.self)
    }()
    private static let canFn: BoolFn? = {
        guard let p = dlsym(handle, "DisplayServicesCanChangeBrightness") else { return nil }
        return unsafeBitCast(p, to: BoolFn.self)
    }()

    static func canChange(_ display: CGDirectDisplayID = CGMainDisplayID()) -> Bool {
        guard let canFn else { return false }
        return canFn(display)
    }

    static func get(_ display: CGDirectDisplayID = CGMainDisplayID()) -> Int? {
        guard let getFn else { return nil }
        var value: Float = 0
        guard getFn(display, &value) == 0 else { return nil }
        return min(100, max(0, Int((value * 100).rounded())))
    }

    @discardableResult
    static func set(_ percent: Int, display: CGDirectDisplayID = CGMainDisplayID()) -> Bool {
        guard let setFn else { return false }
        let clamped = min(100, max(0, percent))
        return setFn(display, Float(clamped) / 100) == 0
    }
}

// MARK: - 系统自带 OSD 反馈（不绘制任何自定义界面）

@objc private protocol OSDUIHelperProtocol {
    func showImage(_ image: Int64, onDisplayID: UInt32, priority: UInt32,
                   msecUntilFade: UInt32, filledChiclets: UInt32,
                   totalChiclets: UInt32, locked: Bool)
}

enum NativeFeedback {
    enum Kind {
        case volume       // showosd: image 3
        case brightness   // showosd: image 1

        var imageID: Int64 { self == .volume ? 3 : 1 }
    }

    private static let connection: NSXPCConnection = {
        let c = NSXPCConnection(serviceName: "com.apple.OSDUIHelper")
        c.remoteObjectInterface = NSXPCInterface(with: OSDUIHelperProtocol.self)
        c.resume()
        return c
    }()

    /// 调用系统 OSDUIHelper 显示原生音量/亮度反馈。
    /// macOS 26 起系统不再为程序化变更弹出该浮层；此处不会绘制任何替代界面。
    static func show(_ kind: Kind, percent: Int, display: CGDirectDisplayID) {
        guard let proxy = connection.remoteObjectProxy as? OSDUIHelperProtocol else { return }
        proxy.showImage(kind.imageID,
                        onDisplayID: display,
                        priority: 0x1F4,
                        msecUntilFade: 1200,
                        filledChiclets: UInt32(min(100, max(0, percent))),
                        totalChiclets: 100,
                        locked: false)
    }
}

// MARK: - 滚轮监听（仅屏幕顶部边缘热区生效）

enum ScrollMode: Equatable {
    case volume       // 未按 Ctrl
    case brightness   // 按住 Ctrl
}

/// 纯逻辑，便于无权限环境下自检
enum WheelLogic {
    /// 向上滚动增加 1%，向下减少 1%，严格夹在 0–100
    static func nextPercent(_ current: Int, increase: Bool) -> Int {
        increase ? min(100, max(0, current) + 1) : max(0, min(100, current) - 1)
    }

    /// Ctrl 唯一决定模式，两种模式互斥
    static func mode(controlDown: Bool) -> ScrollMode {
        controlDown ? .brightness : .volume
    }
}

final class ScrollTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var lastAdjust: CFAbsoluteTime = 0
    var onScroll: ((Bool, ScrollMode, CGDirectDisplayID) -> Void)?

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
        }, userInfo: refcon) else { return false }

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

    /// 回调必须极快返回，否则系统会自动禁用事件监听
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

        // 严格热区限制：鼠标不在顶部边缘时原样放行，绝不改动音量或亮度
        let point = event.location
        guard HotZone.contains(point) else { return Unmanaged.passUnretained(event) }

        let delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        guard delta != 0 else { return Unmanaged.passUnretained(event) }

        let now = CFAbsoluteTimeGetCurrent()
        if prefs.minInterval > 0, now - lastAdjust < prefs.minInterval {
            return nil
        }
        lastAdjust = now

        // CGEvent 的 deltaAxis1 正值代表向上滚动
        let increase = delta > 0

        // 两种模式互斥：Ctrl 只走亮度，绝不落到音量分支
        let mode = WheelLogic.mode(controlDown: event.flags.contains(.maskControl))
        onScroll?(increase, mode, HotZone.display(for: point))

        return nil   // 吞掉事件，页面不跟随滚动
    }
}

// MARK: - 设置界面

private struct HotZonePreset: Identifiable {
    let title: String
    let value: Double
    var id: Double { value }

    static let all: [HotZonePreset] = [
        HotZonePreset(title: "窄 4pt", value: 4),
        HotZonePreset(title: "标准 8pt", value: 8),
        HotZonePreset(title: "宽 16pt", value: 16),
        HotZonePreset(title: "很宽 32pt", value: 32)
    ]
}

struct SettingsView: View {
    @ObservedObject var s: AppState

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
                             ? "鼠标移到屏幕顶部边缘后滚动滚轮：不按 Ctrl 调音量，按住 Ctrl 调亮度。"
                             : "在系统设置中勾选 WheelVolume 后才能监听滚轮。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(s.brightnessSupported
                             ? "当前显示器支持系统亮度控制。"
                             : "当前显示器不支持系统亮度控制（Mac mini 外接显示器常见）。")
                            .font(.caption)
                            .foregroundStyle(s.brightnessSupported ? Color.secondary : Color.orange)
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

            Section("顶部边缘热区") {
                HStack(spacing: 10) {
                    Text("高度")
                    Slider(value: $s.hotZoneHeight, in: 2...48)
                        .frame(minWidth: 170)
                    Text("\(Int(s.hotZoneHeight)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                HStack(spacing: 8) {
                    ForEach(HotZonePreset.all) { preset in
                        Button(preset.title) { s.hotZoneHeight = preset.value }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Spacer()
                }
                Text("只有鼠标进入该区域，滚轮才会被接管；离开后滚轮恢复正常滚动。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("调节方式") {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle").foregroundStyle(.blue)
                    Text("上滑 +1%")
                    Image(systemName: "arrow.down.circle").foregroundStyle(.blue)
                    Text("下滑 −1%")
                    Spacer()
                }
                Text("音量与亮度都在 0%–100% 边界处停止，不会越界。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("手感与外观") {
                Picker("调节间隔", selection: $s.minInterval) {
                    Text("每一次滚动都响应").tag(0.0)
                    Text("25 毫秒").tag(0.025)
                    Text("60 毫秒").tag(0.06)
                    Text("120 毫秒").tag(0.12)
                }
                .pickerStyle(.menu)
                Toggle("在菜单栏显示音量百分比", isOn: $s.showPercentInMenuBar)
                Text("反馈使用系统自带的音量 / 亮度提示，本软件不绘制浮层。")
                    .font(.caption).foregroundStyle(.secondary)
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
        .frame(width: 460, height: 760)
    }
}

// MARK: - 全局动作

enum Actions {
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
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private let state = AppState.shared
    private var menuVolumeItem: NSMenuItem!
    private var menuBrightnessItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusItem()

        tap.onScroll = { [weak self] increase, mode, display in
            self?.adjust(increase: increase, mode: mode, display: display)
        }
        refreshPermission(prompt: true)

        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermission(prompt: false)
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer

        NotificationCenter.default.addObserver(forName: .wheelVolumePrefsChanged,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.refreshStatusTitle()
        }

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

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2",
                                   accessibilityDescription: "WheelVolume")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.toolTip = "WheelVolume — 顶部边缘滚轮调音量/亮度"
        }

        let menu = NSMenu()
        menu.delegate = self

        menuVolumeItem = NSMenuItem(title: "音量 —", action: nil, keyEquivalent: "")
        menuVolumeItem.isEnabled = false
        menu.addItem(menuVolumeItem)

        menuBrightnessItem = NSMenuItem(title: "亮度 —", action: nil, keyEquivalent: "")
        menuBrightnessItem.isEnabled = false
        menu.addItem(menuBrightnessItem)
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
        let device = Volume.defaultOutput()
        if let v = Volume.get(device) {
            menuVolumeItem.title = Volume.isMuted(device)
                ? "音量 \(Int((v * 100).rounded()))%（静音）"
                : "音量 \(Int((v * 100).rounded()))%"
        } else {
            menuVolumeItem.title = "当前输出设备不支持音量控制"
        }
        if let b = ScreenBrightness.get() {
            menuBrightnessItem.title = "亮度 \(b)%"
        } else {
            menuBrightnessItem.title = "当前显示器不支持系统亮度控制"
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

    @objc private func openAX() { Actions.openAccessibilitySettings() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: APP_NAME,
            .applicationVersion: APP_VERSION,
            .credits: NSAttributedString(
                string: "屏幕顶部边缘：滚轮调音量，Ctrl+滚轮调亮度\n仅支持 Apple Silicon · MIT License",
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
            w.setContentSize(NSSize(width: 460, height: 760))
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

    private func refreshPermission(prompt: Bool) {
        var trusted = AXIsProcessTrusted()
        if !trusted, prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        }
        if trusted != state.trusted { state.trusted = trusted }
        if trusted, !tap.isRunning {
            _ = tap.start()
            refreshStatusTitle()
        }
    }

    /// 每种模式只写自己的目标，互斥由调用处的单一 mode 枚举保证
    private func adjust(increase: Bool, mode: ScrollMode, display: CGDirectDisplayID) {
        switch mode {
        case .volume:
            let device = Volume.defaultOutput()
            guard let current = Volume.get(device) else { return }
            var percent = Int((current * 100).rounded())
            percent = WheelLogic.nextPercent(percent, increase: increase)
            if increase, Volume.isMuted(device) { Volume.setMuted(device, false) }
            guard Volume.set(device, Float32(percent) / 100) else { return }
            NativeFeedback.show(.volume, percent: percent, display: display)
            refreshStatusTitle()

        case .brightness:
            guard let current = ScreenBrightness.get(display) else { return }
            let percent = WheelLogic.nextPercent(current, increase: increase)
            guard ScreenBrightness.set(percent, display: display) else { return }
            NativeFeedback.show(.brightness, percent: percent, display: display)
        }
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
    \(APP_NAME) \(APP_VERSION) — 屏幕顶部边缘滚轮调音量 / Ctrl+滚轮调亮度

    用法:
      WheelVolume [--version|-v] [--help|-h]

    规则:
      鼠标位于屏幕顶部边缘热区时滚轮才生效；其他位置完全不干预。
      未按 Ctrl：上滑音量 +1%，下滑 −1%
      按住 Ctrl：上滑亮度 +1%，下滑 −1%
      两种模式互斥，数值限制在 0%–100%

    设置: 菜单栏图标 → 设置…（热区高度、响应间隔、开机启动）
    权限: 系统设置 → 隐私与安全性 → 辅助功能 → 勾选 WheelVolume
    """)
    exit(0)
}

#if !arch(arm64)
fputs("\(APP_NAME) 仅支持 Apple Silicon (arm64) 芯片的 Mac。\n", stderr)
exit(2)
#endif

let running = NSRunningApplication.runningApplications(withBundleIdentifier: BUNDLE_ID)
if running.count > 1 { exit(0) }

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

/// 必须由 NSApplication 接管事件循环，否则 LaunchServices 判为"没有响应"。
let app = NSApplication.shared

// 自检：不需要辅助功能权限，验证热区判定、方向、边界与模式互斥
if cliArgs.contains("--selftest") {
    var failures: [String] = []
    func check(_ ok: Bool, _ label: String) {
        print("\(ok ? "PASS" : "FAIL")  \(label)")
        if !ok { failures.append(label) }
    }

    check(WheelLogic.nextPercent(50, increase: true) == 51, "上滑 50% → 51%")
    check(WheelLogic.nextPercent(50, increase: false) == 49, "下滑 50% → 49%")
    check(WheelLogic.nextPercent(100, increase: true) == 100, "上边界 100% 不越界")
    check(WheelLogic.nextPercent(0, increase: false) == 0, "下边界 0% 不越界")
    check(WheelLogic.nextPercent(0, increase: true) == 1, "0% 上滑 → 1%")
    check(WheelLogic.nextPercent(100, increase: false) == 99, "100% 下滑 → 99%")
    check(WheelLogic.mode(controlDown: false) == .volume, "未按 Ctrl → 音量模式")
    check(WheelLogic.mode(controlDown: true) == .brightness, "按住 Ctrl → 亮度模式（互斥）")

    let oldHeight = prefs.hotZoneHeight
    prefs.hotZoneHeight = 8
    let f = CGDisplayBounds(CGMainDisplayID())
    let midX = f.origin.x + f.width / 2
    check(HotZone.contains(CGPoint(x: midX, y: f.origin.y + 2)), "顶部 2pt 属于热区")
    check(!HotZone.contains(CGPoint(x: midX, y: f.origin.y + 100)), "顶部 100pt 不属于热区")
    check(!HotZone.contains(CGPoint(x: midX, y: f.maxY - 2)), "屏幕底部不属于热区")
    prefs.hotZoneHeight = oldHeight

    print(failures.isEmpty ? "SELFTEST OK" : "SELFTEST FAILED: \(failures.count)")
    exit(failures.isEmpty ? 0 : 1)
}

// 离屏渲染设置界面，供开发/CI 校验排版
if let i = cliArgs.firstIndex(of: "--render-settings"), i + 1 < cliArgs.count {
    let out = cliArgs[i + 1]
    let previewState = AppState.shared
    if ProcessInfo.processInfo.environment["WV_PREVIEW_TRUSTED"] == "1" {
        previewState.trusted = true
    }
    let host = NSHostingView(rootView: SettingsView(s: previewState))
    host.frame = NSRect(x: 0, y: 0, width: 460, height: 760)
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
