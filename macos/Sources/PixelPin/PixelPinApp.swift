import AppKit
import CoreGraphics
import Sparkle
import SwiftUI

@main
struct PixelPinMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = PickerModel()

    var body: some Scene {
        WindowGroup("Pixel Pin") {
            PickerView(
                model: model,
                updatesEnabled: delegate.canCheckForUpdates,
                onCheckForUpdates: delegate.checkForUpdates
            )
                .preferredColorScheme(model.theme.colorScheme)
                .onAppear { delegate.keepWindowsFloating() }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) {
                Button(model.language.text("설정…", "Settings…", "设置…")) {
                    model.settingsOpen = true
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(after: .appInfo) {
                Button(model.language.text("업데이트 확인…", "Check for Updates…", "检查更新…")) {
                    delegate.checkForUpdates()
                }
                .disabled(!delegate.canCheckForUpdates)
            }
            CommandMenu("Pixel Pin") {
                Button(model.language.text(model.miniMode ? "기본 모드로 전환" : "미니 모드로 전환", model.miniMode ? "Return to Standard Mode" : "Switch to Mini Mode", model.miniMode ? "返回标准模式" : "切换为迷你模式")) { model.toggleMiniMode() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button(model.language.text("색상 복사", "Copy color", "复制颜色")) { model.copy(model.color) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button(model.language.text("색상 고정 / 재개", "Pin / resume", "固定 / 继续取色")) { model.toggleFreeze() }
                    .keyboardShortcut(.space, modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let updaterController: SPUStandardUpdaterController?

    override init() {
        if Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String != nil,
           Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String != nil {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: false,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
        super.init()
    }

    var canCheckForUpdates: Bool { updaterController != nil && AppInstallation.isInstalled() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if AppInstallation.isInstalled() { updaterController?.startUpdater() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.keepWindowsFloating() }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func keepWindowsFloating() {
        NSApp.windows.forEach { window in
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isMovableByWindowBackground = false
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = false
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "한국어", english = "English", chinese = "简体中文"
    var id: String { rawValue }
    func text(_ ko: String, _ en: String, _ zh: String) -> String {
        switch self { case .korean: return ko; case .english: return en; case .chinese: return zh }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? { self == .system ? nil : (self == .light ? .light : .dark) }
    func text(_ language: AppLanguage) -> String {
        switch self {
        case .system: return language.text("기기 설정", "System", "跟随系统")
        case .light: return language.text("라이트", "Light", "浅色")
        case .dark: return language.text("다크", "Dark", "深色")
        }
    }
}

enum ColorFormat: String, CaseIterable, Identifiable {
    case hex = "HEX", rgb = "RGB", hsl = "HSL", hsv = "HSV", cmyk = "CMYK"
    var id: String { rawValue }
}

struct PixelColor: Equatable {
    var red: Int = 84
    var green: Int = 124
    var blue: Int = 240
    var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }

    var swiftUIColor: Color { Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: 1) }
    var foreground: Color { (red * 299 + green * 587 + blue * 114) >= 150_000 ? .black : .white }

    func formatted(_ format: ColorFormat) -> String {
        let r = Double(red) / 255, g = Double(green) / 255, b = Double(blue) / 255
        switch format {
        case .hex: return hex
        case .rgb: return "rgb(\(red), \(green), \(blue))"
        case .hsl:
            let (h, s, l) = hsl(r, g, b)
            return "hsl(\(Int((h * 360).rounded()))°, \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
        case .hsv:
            let (h, s, v) = hsv(r, g, b)
            return "hsv(\(Int((h * 360).rounded()))°, \(Int((s * 100).rounded()))%, \(Int((v * 100).rounded()))%)"
        case .cmyk:
            let k = 1 - max(r, g, b)
            let c = k == 1 ? 0 : (1 - r - k) / (1 - k)
            let m = k == 1 ? 0 : (1 - g - k) / (1 - k)
            let y = k == 1 ? 0 : (1 - b - k) / (1 - k)
            return "cmyk(\(Int((c * 100).rounded()))%, \(Int((m * 100).rounded()))%, \(Int((y * 100).rounded()))%, \(Int((k * 100).rounded()))%)"
        }
    }

    private func hsv(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let high = max(r, g, b), low = min(r, g, b), delta = high - low
        var hue = 0.0
        if delta != 0 {
            if high == r { hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if high == g { hue = (b - r) / delta + 2 }
            else { hue = (r - g) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, high == 0 ? 0 : delta / high, high)
    }

    private func hsl(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let (h, s, v) = hsv(r, g, b), lightness = v * (1 - s / 2)
        let saturation = lightness == 0 || lightness == 1 ? 0 : (v - lightness) / min(lightness, 1 - lightness)
        return (h, saturation, lightness)
    }
}

struct CaptureFrame {
    let image: CGImage
    let color: PixelColor
    let pixelOffset: CGPoint
    let screenPoint: CGPoint
}

@MainActor
final class PickerModel: ObservableObject {
    @Published var color = PixelColor()
    @Published var loupe: CGImage?
    @Published var frozen = false
    @Published var message = "Ready"
    @Published var settingsOpen = false
    @Published var miniMode: Bool {
        didSet { defaults.set(miniMode, forKey: "miniMode") }
    }
    @Published var captureErrorDetail = ""
    @Published var closeBehavior: WindowCloseBehavior {
        didSet { defaults.set(closeBehavior.rawValue, forKey: "closeBehavior") }
    }
    @Published var automaticCapture: Bool {
        didSet {
            defaults.set(automaticCapture, forKey: "automaticCapture")
            startCapture()
        }
    }
    @Published var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: "theme") }
    }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }
    @Published var format: ColorFormat {
        didSet { defaults.set(format.rawValue, forKey: "format") }
    }
    @Published var history: [String]

    private let defaults: UserDefaults
    private let captureEnabled: Bool
    private var timer: Timer?
    private var clickMonitor: Any?
    private var lastButtonDown = false
    private let capture = ScreenCaptureEngine()
    private var latestRaster: PixelRaster?
    private var captureFrame = CGRect.zero
    private var isSelectingScreen = false
    private var awaitingCaptureSettings = false
    @Published var markerOffset = CGSize.zero

    init(defaults: UserDefaults = .standard, startCapture: Bool = true) {
        self.defaults = defaults
        self.captureEnabled = startCapture
        miniMode = defaults.bool(forKey: "miniMode")
        closeBehavior = WindowCloseBehavior(rawValue: defaults.string(forKey: "closeBehavior") ?? "minimize") ?? .minimize
        automaticCapture = defaults.object(forKey: "automaticCapture") as? Bool ?? true
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "system") ?? .system
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "한국어") ?? .korean
        format = ColorFormat(rawValue: defaults.string(forKey: "format") ?? "HEX") ?? .hex
        history = defaults.stringArray(forKey: "recentColors") ?? []
        guard startCapture else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if self.settingsOpen { self.settingsOpen = false }
                else if event.type == .leftMouseDown { self.toggleFreeze() }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer?.tolerance = 0.015
        capture.onFrame = { [weak self] raster, frame in
            self?.latestRaster = raster
            self?.captureFrame = frame
            self?.sample()
        }
        capture.onState = { [weak self] state in
            self?.isSelectingScreen = state == "selectScreen" || state == "connecting"
            if state == "captureError" || state == "permission" || state == "connecting" { self?.latestRaster = nil }
            if state == "captureError" || state == "permission" { self?.loupe = nil }
            if state == "live" { self?.captureErrorDetail = "" }
            self?.message = state
        }
        capture.onError = { [weak self] in self?.captureErrorDetail = $0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.startCapture() }
    }

    deinit {
        timer?.invalidate()
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    }

    func toggleFreeze() {
        guard !isSelectingScreen, !settingsOpen else { return }
        // Clicking a system permission dialog must not overwrite the recovery state.
        guard loupe != nil, latestRaster != nil else { return }
        frozen.toggle()
        message = frozen ? "pinned" : "live"
        if !frozen { sample() }
    }

    func toggleMiniMode() {
        settingsOpen = false
        miniMode.toggle()
    }

    func selectScreen() {
        frozen = false
        isSelectingScreen = true
        message = "selectScreen"
        latestRaster = nil
        capture.selectScreen()
    }

    func startCapture(requestPermission: Bool = false) {
        guard captureEnabled else { return }
        frozen = false
        isSelectingScreen = true
        latestRaster = nil
        if automaticCapture { capture.startAutomatically(requestPermission: requestPermission) }
        else { selectScreen() }
    }

    func openCaptureSettings() {
        awaitingCaptureSettings = true
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func resumeAfterSettings() {
        if awaitingCaptureSettings {
            awaitingCaptureSettings = false
            startCapture()
        } else if automaticCapture && message == "permission" && CGPreflightScreenCaptureAccess() {
            startCapture()
        }
    }

    func sample() {
        if !frozen { capture.followPointer() }
        guard !frozen, !isSelectingScreen, let raster = latestRaster else { return }
        let cursor = NSEvent.mouseLocation
        guard captureFrame.contains(cursor) else { message = "otherScreen"; return }
        guard !NSApp.windows.contains(where: { $0.isVisible && $0.frame.contains(cursor) }) else { return }
        let image = raster.image
        let x = min(max(Int((cursor.x - captureFrame.minX) / captureFrame.width * CGFloat(image.width)), 0), image.width - 1)
        let y = min(max(Int((captureFrame.maxY - cursor.y) / captureFrame.height * CGFloat(image.height)), 0), image.height - 1)
        guard let sampled = raster.color(x: x, y: y) else { return }
        color = sampled
        let left = max(0, min(x - 8, image.width - min(17, image.width)))
        let top = max(0, min(y - 8, image.height - min(17, image.height)))
        let width = min(17, image.width), height = min(17, image.height)
        loupe = image.cropping(to: CGRect(x: left, y: top, width: width, height: height))
        markerOffset = CGSize(width: (CGFloat(x - left) + 0.5) / CGFloat(width) * 132 - 66,
                              height: (CGFloat(y - top) + 0.5) / CGFloat(height) * 132 - 66)
        message = "live"
    }

    func copy(_ value: PixelColor) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value.formatted(format), forType: .string)
        history.removeAll { $0 == value.hex }
        history.insert(value.hex, at: 0)
        history = Array(history.prefix(8))
        defaults.set(history, forKey: "recentColors")
        message = "copied"
    }

    func clearHistory() {
        history = []
        defaults.removeObject(forKey: "recentColors")
    }

    var paletteColors: Palette { Palette(theme: theme) }
}

struct Palette {
    let theme: AppTheme
    var systemDark = false
    private var dark: Bool { theme == .dark || (theme == .system && systemDark) }
    var background: Color { dark ? Color(red: 0.12, green: 0.15, blue: 0.20) : Color(red: 0.975, green: 0.98, blue: 0.99) }
    var surface: Color { dark ? Color(red: 0.17, green: 0.20, blue: 0.27) : .white }
    var ink: Color { dark ? Color(red: 0.92, green: 0.94, blue: 0.97) : Color(red: 0.12, green: 0.17, blue: 0.25) }
    var muted: Color { dark ? Color(red: 0.66, green: 0.71, blue: 0.79) : Color(red: 0.40, green: 0.46, blue: 0.55) }
    var tint: Color { dark ? Color(red: 0.21, green: 0.28, blue: 0.42) : Color(red: 0.92, green: 0.94, blue: 0.99) }
}

struct PickerView: View {
    @ObservedObject var model: PickerModel
    let updatesEnabled: Bool
    let onCheckForUpdates: () -> Void
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var copied = false
    private var p: Palette { Palette(theme: model.theme, systemDark: systemColorScheme == .dark) }
    private var language: AppLanguage { model.language }
    private var windowLayout: PickerWindowLayout {
        PickerWindowLayout(miniMode: model.miniMode, settingsOpen: model.settingsOpen,
                           workArea: NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900))
    }
    private var modeAction: String {
        model.miniMode ? language.text("기본 모드로 전환", "Return to standard mode", "返回标准模式") : language.text("미니 모드로 전환", "Switch to mini mode", "切换为迷你模式")
    }

    var body: some View {
        VStack(spacing: 0) {
            if windowLayout.isMini {
                miniContent
            } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if !AppInstallation.isInstalled() {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language.text("자동 업데이트를 사용하려면 Pixel Pin을 응용 프로그램 폴더에 설치해 주세요.", "Move Pixel Pin to Applications to enable updates.", "请将 Pixel Pin 移到“应用程序”文件夹，以使用自动更新。"))
                            Button(language.text("응용 프로그램 폴더 열기", "Open Applications", "打开应用程序文件夹")) {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                            }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
                        }.font(.system(size: 11)).foregroundStyle(p.ink).padding(12)
                            .background(p.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text(language.text("마음에 든 색, 그대로.", "Pick it. Pin it.", "看中的颜色，一键固定。"))
                        .font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(p.ink)
                    Text(language.text("커서를 움직여 화면의 픽셀을 찾으세요.", "Move your pointer to pick a pixel.", "移动光标，选取屏幕上的像素颜色。"))
                        .font(.system(size: 12)).foregroundStyle(p.muted)

                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 14).fill(model.color.swiftUIColor)
                            .overlay(alignment: .bottomLeading) {
                                Text(model.color.hex).font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(model.color.foreground).padding(12)
                            }
                            .frame(height: 132)
                        if let loupe = model.loupe {
                            Image(decorative: loupe, scale: 1).interpolation(.none).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 132, height: 132).clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay { Rectangle().stroke(p.ink.opacity(0.75), lineWidth: 1).frame(width: 9, height: 9).offset(model.markerOffset) }
                        } else {
                            RoundedRectangle(cornerRadius: 14).fill(p.tint).frame(width: 132, height: 132)
                                .overlay(Image(systemName: "viewfinder").font(.system(size: 26)).foregroundStyle(p.muted))
                        }
                    }
                    HStack(spacing: 0) {
                        rgb("R", model.color.red); rgb("G", model.color.green); rgb("B", model.color.blue)
                    }.padding(.vertical, 4)

                    HStack(spacing: 12) {
                        Text(model.color.formatted(model.format)).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(2).minimumScaleFactor(0.7).foregroundStyle(p.ink)
                        Spacer(minLength: 4)
                        Button {
                            model.copy(model.color); copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                        } label: {
                            Text(copied ? language.text("복사됨", "Copied", "已复制") : language.text("\(model.format.rawValue) 복사", "Copy \(model.format.rawValue)", "复制 \(model.format.rawValue)"))
                                .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 10)
                                .foregroundStyle(model.color.foreground).background(model.color.swiftUIColor, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }.padding(12).background(p.surface, in: RoundedRectangle(cornerRadius: 12))

                    Button { model.toggleFreeze() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: model.frozen ? "play.fill" : "pause.fill").font(.system(size: 13, weight: .bold))
                            Text(model.frozen ? language.text("실시간 측정 재개", "Resume live sampling", "继续实时取色") : language.text("색상 고정", "Pin this color", "固定当前颜色"))
                                .font(.system(size: 13, weight: .semibold))
                        }.frame(maxWidth: .infinity).padding(.vertical, 13).foregroundStyle(p.ink).background(p.tint, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)

                    HStack {
                        Label(statusText, systemImage: model.frozen ? "pause.circle.fill" : "circle.fill")
                        Spacer()
                        Text(language.text("화면 RGB · 1픽셀", "Screen RGB · 1 pixel", "屏幕 RGB · 单个像素"))
                    }.font(.system(size: 10)).foregroundStyle(p.muted)
                    Button(language.text("측정할 화면 선택", "Choose a screen", "选择取色屏幕")) { model.selectScreen() }
                        .font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(Color.accentColor)
                    if model.message == "permission" {
                        Text(language.text("시스템 설정에서 화면 기록 접근을 허용한 뒤 다시 시도해 주세요. macOS에서 앱 재시작을 요구할 수 있습니다.", "Allow Screen Recording in System Settings, then try again. macOS may require you to reopen the app.", "请在系统设置中允许屏幕录制，然后重试。macOS 可能需要重新打开应用。"))
                            .font(.system(size: 10)).foregroundStyle(p.muted)
                        HStack {
                            Button(language.text("시스템 설정 열기", "Open System Settings", "打开系统设置")) { model.openCaptureSettings() }
                            Button(language.text("다시 시도", "Try again", "重试")) { model.startCapture(requestPermission: true) }
                        }.font(.system(size: 11))
                    } else if model.message == "captureError" {
                        Text(language.text("화면 연결에 실패했습니다. 다시 연결하거나 시스템 화면 선택으로 시작해 주세요.", "Couldn’t connect to the display. Try reconnecting or use the screen picker.", "无法连接屏幕。请重试，或使用系统屏幕选择器。"))
                            .font(.system(size: 10)).foregroundStyle(p.muted)
                        HStack {
                            Button(language.text("다시 연결", "Reconnect", "重新连接")) { model.startCapture(requestPermission: true) }
                            Button(language.text("권한 설정", "Permission settings", "权限设置")) { model.openCaptureSettings() }
                        }.font(.system(size: 11))
                    } else if model.message == "selectScreen" {
                        Text(language.text(
                            "macOS 화면 선택 창에서 측정할 디스플레이를 선택해 주세요. 선택을 취소했다면 위 버튼으로 다시 열 수 있습니다.",
                            "Choose the display to sample in the macOS screen picker. Use the button above to reopen it if you cancelled.",
                            "请在 macOS 屏幕选择器中选择要取色的显示器。若已取消，可点击上方按钮重新选择。"
                        )).font(.system(size: 10)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
                        if #unavailable(macOS 14.0) {
                            Link(language.text("화면 기록 설정 열기", "Open Screen Recording settings", "打开屏幕录制设置"),
                                 destination: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                    }
                    if !model.captureErrorDetail.isEmpty {
                        DisclosureGroup(language.text("진단 정보", "Diagnostic details", "诊断信息")) {
                            Text(model.captureErrorDetail).font(.system(size: 10)).textSelection(.enabled)
                        }.font(.system(size: 10)).foregroundStyle(p.muted)
                    }

                    HStack {
                        Text(language.text("최근 복사한 색상", "Recently copied", "最近复制的颜色"))
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(p.ink)
                        Spacer()
                        Text(language.text("눌러서 다시 복사", "Click to copy again", "点击再次复制"))
                            .font(.system(size: 10)).foregroundStyle(p.muted)
                    }.padding(.top, 4)
                    HStack(spacing: 8) {
                        ForEach(model.history, id: \.self) { hex in
                            Button { if let recent = Self.parse(hex) { model.copy(recent) } } label: {
                                RoundedRectangle(cornerRadius: 9).fill(Self.parse(hex)?.swiftUIColor ?? .gray)
                                    .frame(width: 36, height: 36).overlay(RoundedRectangle(cornerRadius: 9).stroke(p.ink.opacity(0.12)))
                            }.buttonStyle(.plain).help(hex)
                        }
                    }
                    Spacer(minLength: 12)
                }.padding(20)
            }
            footer
            }
        }
        .frame(width: windowLayout.contentSize.width, height: windowLayout.contentSize.height)
        .background(p.background)
        .background(PickerWindowLayoutConfigurator(layout: windowLayout))
        .background(WindowChromeConfigurator(color: p.background))
        .background(WindowCloseBehaviorHandler(behavior: model.closeBehavior))
        .toolbarBackground(p.background, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.toggleMiniMode() } label: {
                    Image(systemName: model.miniMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                }
                .disabled(model.settingsOpen)
                .help(modeAction + " · ⇧⌘M")
                .accessibilityLabel(modeAction)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { model.settingsOpen.toggle() } label: {
                    Image(systemName: "gearshape")
                }
                .help(language.text("설정", "Settings", "设置"))
                .accessibilityLabel(language.text("설정", "Settings", "设置"))
            }
        }
        .overlay {
            if model.settingsOpen {
                ZStack {
                    Color.black.opacity(0.25).contentShape(Rectangle()).onTapGesture { model.settingsOpen = false }
                    settingsPanel
                        .background(OutsideClickDismissal { model.settingsOpen = false })
                        .onTapGesture { }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in model.settingsOpen = false }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.resumeAfterSettings() }
    }

    private var footer: some View {
        Link("Made by TeamHJD", destination: URL(string: "https://teamhjd.com/")!)
            .font(.system(size: 10)).foregroundStyle(p.muted).padding(.vertical, 12)
    }

    private var miniContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(model.color.swiftUIColor).frame(width: 48, height: 48)
                    .accessibilityLabel(language.text("현재 색상", "Current color", "当前颜色") + " " + model.color.hex)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.format.rawValue).font(.system(size: 9, weight: .semibold)).foregroundStyle(p.muted)
                    Text(model.color.formatted(model.format))
                        .font(.system(size: model.format == .hex ? 19 : 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(p.ink).lineLimit(2).minimumScaleFactor(0.8).textSelection(.enabled)
                        .help(model.color.formatted(model.format))
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.copy(model.color)
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 14, weight: .medium))
                        .frame(width: 34, height: 34).foregroundStyle(model.color.foreground)
                        .background(model.color.swiftUIColor, in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain)
                    .help(language.text("\(model.format.rawValue) 복사", "Copy \(model.format.rawValue)", "复制 \(model.format.rawValue)") + " · ⇧⌘C")
                    .accessibilityLabel(language.text("\(model.format.rawValue) 복사", "Copy \(model.format.rawValue)", "复制 \(model.format.rawValue)"))
            }
            HStack(spacing: 8) {
                Label(statusText, systemImage: model.frozen ? "pause.circle.fill" : "circle.fill")
                    .font(.system(size: 10)).foregroundStyle(p.muted).lineLimit(1).truncationMode(.tail).help(statusText)
                Spacer(minLength: 0)
                Button { model.toggleFreeze() } label: {
                    Label(model.frozen ? language.text("재개", "Resume", "继续") : language.text("고정", "Pin", "固定"), systemImage: model.frozen ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
                        .foregroundStyle(p.ink).background(p.tint, in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain)
                    .help(language.text("색상 고정 / 재개", "Pin / resume", "固定 / 继续取色") + " · ⇧⌘Space")
            }
        }.padding(14)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.text("설정", "Settings", "设置")).font(.system(size: 14, weight: .bold)).foregroundStyle(p.ink)
                Spacer()
                Button { model.settingsOpen = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).keyboardShortcut(.cancelAction)
                    .accessibilityLabel(language.text("설정 닫기", "Close settings", "关闭设置"))
            }
            settingRow(language.text("화면 모드", "Appearance", "外观")) {
                Picker("", selection: $model.theme) { ForEach(AppTheme.allCases) { Text($0.text(language)).tag($0) } }.labelsHidden().pickerStyle(.menu)
            }
            settingRow(language.text("언어", "Language", "语言")) {
                Picker("", selection: $model.language) { ForEach(AppLanguage.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.menu)
            }
            settingRow(language.text("색상 포맷", "Color format", "颜色格式")) {
                Picker("", selection: $model.format) { ForEach(ColorFormat.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.menu)
            }
            Toggle(language.text("미니 모드", "Mini mode", "迷你模式"), isOn: $model.miniMode)
                .font(.system(size: 11)).foregroundStyle(p.ink).toggleStyle(.switch)
            if model.miniMode {
                Text(language.text("설정을 닫으면 작은 창으로 돌아갑니다.", "Close settings to return to the mini window.", "关闭设置后将返回迷你窗口。"))
                    .font(.system(size: 9)).foregroundStyle(p.muted)
            }
            settingRow(language.text("닫기 버튼 동작", "Close button", "关闭按钮")) {
                Picker("", selection: $model.closeBehavior) {
                    ForEach(WindowCloseBehavior.allCases) { Text($0.text(language)).tag($0) }
                }.labelsHidden().pickerStyle(.menu)
            }
            Text(language.text("CMYK는 인쇄 프로파일이 없는 참고값입니다.", "CMYK is a reference value without a print profile.", "CMYK 为未套用印刷配置文件的参考值。"))
                .font(.system(size: 9)).foregroundStyle(p.muted)
            Toggle(language.text("시작 시 전체 화면 자동 측정", "Start screen sampling automatically", "自动开始全屏取色"), isOn: $model.automaticCapture)
                .font(.system(size: 11)).foregroundStyle(p.ink).toggleStyle(.switch)
            Text(language.text("선택창 없이 커서가 있는 화면을 측정합니다. macOS가 접근 재승인을 요청할 수 있습니다.", "Samples the display under your pointer without the picker. macOS may ask you to renew access.", "无需选择屏幕，自动跟随光标取色。macOS 可能会要求重新授权。"))
                .font(.system(size: 10)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            settingRow(language.text("업데이트", "Updates", "更新")) {
                Button(language.text("업데이트 확인", "Check now", "立即检查"), action: onCheckForUpdates)
                    .disabled(!updatesEnabled)
            }
            if !updatesEnabled {
                Text(language.text(
                    AppInstallation.isInstalled() ? "이 빌드에서는 업데이트 확인을 사용할 수 없습니다. 공식 릴리즈를 설치해 주세요." : "업데이트하려면 응용 프로그램 폴더에 설치한 앱을 다시 열어 주세요.",
                    AppInstallation.isInstalled() ? "Update checks are unavailable in this build. Install an official release." : "Reopen Pixel Pin from Applications to enable updates.",
                    AppInstallation.isInstalled() ? "此版本无法检查更新，请安装官方发行版。" : "请从“应用程序”文件夹重新打开 Pixel Pin 以启用更新。"
                )).font(.system(size: 9)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button(language.text("최근 색상 지우기", "Clear recent colors", "清除最近颜色")) {
                    model.clearHistory()
                }.buttonStyle(.plain)
                Spacer(minLength: 0)
                Button(language.text("기본값 복원", "Restore defaults", "恢复默认设置")) {
                    model.theme = .system; model.language = .korean; model.format = .hex; model.miniMode = false; model.closeBehavior = .minimize; model.automaticCapture = true
                }.buttonStyle(.plain)
            }.font(.system(size: 9, weight: .medium)).foregroundStyle(Color.accentColor)
        }.padding(14).frame(width: 300, alignment: .leading).background(p.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.ink.opacity(0.1))).shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private func settingRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack { Text(title).font(.system(size: 11)).foregroundStyle(p.muted); Spacer(); control().font(.system(size: 11)).tint(p.ink) }
    }

    private func rgb(_ title: String, _ value: Int) -> some View {
        HStack { Text(title).foregroundStyle(p.muted); Spacer(); Text(String(value)).foregroundStyle(p.ink) }
            .font(.system(size: 11, weight: .medium, design: .monospaced)).padding(.horizontal, 10).frame(maxWidth: .infinity)
    }

    private var statusText: String {
        switch model.message {
        case "connecting": return language.text("화면 측정 연결 중", "Connecting to display", "正在连接屏幕")
        case "selectScreen": return language.text("측정할 화면을 선택해 주세요", "Choose a screen to sample", "请选择取色屏幕")
        case "captureError": return language.text("화면 측정에 연결하지 못했습니다", "Couldn’t connect to the display", "无法连接屏幕取色")
        case "otherScreen": return language.text("선택한 화면으로 커서를 이동하세요", "Move the pointer to the selected display", "请将光标移至所选屏幕")
        case "permission": return language.text("화면 기록 권한을 허용해 주세요", "Allow Screen Recording access", "请允许屏幕录制权限")
        case "pinned": return language.text("색상 고정됨", "Color pinned", "颜色已固定")
        case "copied": return language.text("클립보드에 복사됨", "Copied to clipboard", "已复制到剪贴板")
        case "pickFirst": return language.text("먼저 화면에서 색을 선택하세요", "Pick a color first", "请先选取屏幕颜色")
        default: return model.frozen ? language.text("색상 고정됨", "Color pinned", "颜色已固定") : language.text("실시간 측정 중", "Live sampling", "正在实时取色")
        }
    }

    private static func parse(_ hex: String) -> PixelColor? {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        return PixelColor(red: Int((rgb >> 16) & 255), green: Int((rgb >> 8) & 255), blue: Int(rgb & 255))
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    let color: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        apply(to: view)
    }

    private func apply(to view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.backgroundColor = NSColor(color)
            window.titlebarAppearsTransparent = false
        }
    }
}

