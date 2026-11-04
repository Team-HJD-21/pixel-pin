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
                .frame(width: 410, height: 720)
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
                .keyboardShortcut(",", modifiers: [.control])
            }
            CommandGroup(after: .appInfo) {
                Button(model.language.text("업데이트 확인…", "Check for Updates…", "检查更新…")) {
                    delegate.checkForUpdates()
                }
                .disabled(!delegate.canCheckForUpdates)
            }
            CommandMenu("Pixel Pin") {
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

    var canCheckForUpdates: Bool { updaterController != nil }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        updaterController?.startUpdater()
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
    @Published var theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "system") ?? .system {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    @Published var language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "한국어") ?? .korean {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    @Published var format = ColorFormat(rawValue: UserDefaults.standard.string(forKey: "format") ?? "HEX") ?? .hex {
        didSet { UserDefaults.standard.set(format.rawValue, forKey: "format") }
    }
    @Published var history = UserDefaults.standard.stringArray(forKey: "recentColors") ?? []

    private var timer: Timer?
    private var clickMonitor: Any?
    private var lastButtonDown = false
    private let screenCaptureRequestKey = "didRequestScreenCaptureAccess"

    init() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in self?.toggleFreeze() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer?.tolerance = 0.015
        if !CGPreflightScreenCaptureAccess() {
            message = "permission"
            requestScreenCaptureAccessOnFirstLaunch()
        }
    }

    deinit {
        timer?.invalidate()
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    }

    func toggleFreeze() {
        guard loupe != nil else { message = "pickFirst"; return }
        frozen.toggle()
        message = frozen ? "pinned" : "live"
        if !frozen { sample() }
    }

    private func requestScreenCaptureAccessOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: screenCaptureRequestKey) else { return }
        UserDefaults.standard.set(true, forKey: screenCaptureRequestKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, !CGPreflightScreenCaptureAccess() else { return }
            if CGRequestScreenCaptureAccess() {
                self.message = "live"
                self.sample()
            }
        }
    }

    func sample() {
        guard !frozen else { return }
        guard CGPreflightScreenCaptureAccess() else {
            message = "permission"
            return
        }
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        guard !NSApp.windows.contains(where: { $0.isVisible && $0.frame.contains(cursor) }) else { return }

        let display = CGDirectDisplayID(number.uint32Value)
        guard let displayImage = CGDisplayCreateImage(display) else { return }
        guard screen.frame.width > 0, screen.frame.height > 0 else { return }
        // Map AppKit's logical screen coordinates to the actual captured pixel
        // dimensions. This also handles Retina and mixed-scale displays.
        let normalizedX = (cursor.x - screen.frame.minX) / screen.frame.width
        let normalizedY = (screen.frame.maxY - cursor.y) / screen.frame.height
        let px = min(max(Int((normalizedX * CGFloat(displayImage.width)).rounded(.down)), 0), displayImage.width - 1)
        let py = min(max(Int((normalizedY * CGFloat(displayImage.height)).rounded(.down)), 0), displayImage.height - 1)
        let bitmap = NSBitmapImageRep(cgImage: displayImage)
        guard let nsColor = bitmap.colorAt(x: px, y: py)?.usingColorSpace(NSColorSpace.sRGB) else { return }
        color = PixelColor(
            red: Self.byte(nsColor.redComponent),
            green: Self.byte(nsColor.greenComponent),
            blue: Self.byte(nsColor.blueComponent)
        )
        let left = min(max(px - 8, 0), max(0, displayImage.width - 17))
        let top = min(max(py - 8, 0), max(0, displayImage.height - 17))
        let cropRect = CGRect(x: left, y: top, width: min(17, displayImage.width), height: min(17, displayImage.height))
        loupe = displayImage.cropping(to: cropRect)
        message = "live"
    }

    private static func byte(_ component: CGFloat) -> Int {
        Int((min(max(component, 0), 1) * 255).rounded())
    }

    func copy(_ value: PixelColor) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value.formatted(format), forType: .string)
        history.removeAll { $0 == value.hex }
        history.insert(value.hex, at: 0)
        history = Array(history.prefix(8))
        UserDefaults.standard.set(history, forKey: "recentColors")
        message = "copied"
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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
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
                                .overlay { Rectangle().stroke(p.ink.opacity(0.75), lineWidth: 1).frame(width: 9, height: 9) }
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
                    if model.message == "permission" {
                        Text(language.text(
                            "화면 색을 읽으려면 화면 기록 권한이 필요합니다. 허용 후에도 측정되지 않으면 앱을 다시 열어 주세요.",
                            "Pixel Pin needs Screen Recording access to read screen colors. Reopen the app if sampling does not start after granting access.",
                            "Pixel Pin 需要屏幕录制权限才能读取颜色。授权后若仍无法取色，请重新打开应用。"
                        )).font(.system(size: 10)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
                        Button(language.text("화면 기록 설정 열기", "Open Screen Recording settings", "打开屏幕录制设置")) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
                        }.font(.system(size: 10, weight: .medium)).buttonStyle(.plain).foregroundStyle(Color.accentColor)
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
        .background(p.background)
        .background(WindowChromeConfigurator(color: p.background))
        .toolbarBackground(p.background, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { model.settingsOpen.toggle() } label: {
                    Image(systemName: "gearshape")
                }
                .help(language.text("설정", "Settings", "设置"))
                .accessibilityLabel(language.text("설정", "Settings", "设置"))
            }
        }
        .overlay(alignment: .topTrailing) {
            if model.settingsOpen { settingsPanel.padding(.top, 12).padding(.trailing, 10).zIndex(2) }
        }
    }

    private var footer: some View {
        Link("Made by TeamHJD", destination: URL(string: "https://teamhjd.com/")!)
            .font(.system(size: 10)).foregroundStyle(p.muted).padding(.vertical, 12)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("설정", "Settings", "设置")).font(.system(size: 13, weight: .bold)).foregroundStyle(p.ink)
            settingRow(language.text("화면 모드", "Appearance", "外观")) {
                Picker("", selection: $model.theme) { ForEach(AppTheme.allCases) { Text($0.text(language)).tag($0) } }.labelsHidden().pickerStyle(.menu)
            }
            settingRow(language.text("언어", "Language", "语言")) {
                Picker("", selection: $model.language) { ForEach(AppLanguage.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.menu)
            }
            settingRow(language.text("색상 포맷", "Color format", "颜色格式")) {
                Picker("", selection: $model.format) { ForEach(ColorFormat.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.menu)
            }
            Text(language.text("CMYK는 인쇄 프로파일이 없는 참고값입니다.", "CMYK is a reference value without a print profile.", "CMYK 为未套用印刷配置文件的参考值。"))
                .font(.system(size: 9)).foregroundStyle(p.muted)
            settingRow(language.text("업데이트", "Updates", "更新")) {
                Button(language.text("업데이트 확인", "Check now", "立即检查"), action: onCheckForUpdates)
                    .disabled(!updatesEnabled)
            }
            if !updatesEnabled {
                Text(language.text(
                    "자동 업데이트는 서명 키를 등록한 다음 안정 버전부터 사용할 수 있습니다.",
                    "Update checks will be enabled for stable releases after the signing key is configured.",
                    "配置签名密钥后，稳定版即可启用自动更新。"
                )).font(.system(size: 9)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button(language.text("최근 색상 지우기", "Clear recent colors", "清除最近颜色")) {
                    model.history = []
                    UserDefaults.standard.removeObject(forKey: "recentColors")
                }.buttonStyle(.plain)
                Spacer(minLength: 0)
                Button(language.text("기본값 복원", "Restore defaults", "恢复默认设置")) {
                    model.theme = .system; model.language = .korean; model.format = .hex
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

