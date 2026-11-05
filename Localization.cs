using System.Globalization;
using System.Windows;
using System.Windows.Markup;

namespace PixelPin;

public static class Localization
{
    // Each entry is Korean, English, Simplified Chinese. Format identifiers remain standard.
    private static readonly Dictionary<string, string[]> Strings = new()
    {
        ["Headline"] = ["화면의 색을, 정확하게.", "Every pixel, captured.", "精准捕捉每一像素。"],
        ["InstructionLive"] = ["화면 클릭으로 색상 고정 · 다시 클릭하면 측정 재개", "Click to pin a color. Click again to resume.", "点击屏幕固定颜色，再次点击继续取色。"],
        ["InstructionFrozen"] = ["화면을 다시 클릭하면 실시간 측정이 재개됩니다.", "Click the screen again to resume picking.", "再次点击屏幕，继续实时取色。"],
        ["CurrentColor"] = ["현재 색상", "CURRENT COLOR", "当前颜色"],
        ["ScreenRgb"] = ["화면 RGB · 1 픽셀", "Screen RGB · 1 pixel", "屏幕 RGB · 单个像素"],
        ["HdrRgb"] = ["HDR/scRGB → sRGB", "HDR/scRGB → sRGB", "HDR/scRGB → sRGB"],
        ["CompatibilityRgb"] = ["호환 캡처 · RGB", "Compatibility · RGB", "兼容采集 · RGB"],
        ["HdrHint"] = ["고정밀 scRGB 캡처와 Windows SDR 밝기 보정 후 sRGB로 환산합니다. HDR의 밝기와 넓은 색역을 HEX로 완전히 표현할 수는 없습니다.", "High-precision scRGB capture, normalized by Windows SDR white level and converted to sRGB. HEX cannot represent full HDR brightness or gamut.", "使用高精度 scRGB 采集，按 Windows SDR 白电平校正后换算为 sRGB。HEX 无法完整表达 HDR 的亮度和广色域。"],
        ["CompatibilityHint"] = ["DirectX 캡처를 사용할 수 없어 호환 방식으로 읽고 있습니다. HDR 색상은 다를 수 있습니다.", "DirectX capture is unavailable; using compatibility capture. HDR colors may differ.", "DirectX 采集不可用，正在使用兼容采集。HDR 颜色可能存在偏差。"],
        ["Live"] = ["실시간 측정", "Live picking", "实时取色"],
        ["Frozen"] = ["색상 고정됨", "Color pinned", "颜色已固定"],
        ["MoveOutside"] = ["화면 위로 커서를 옮겨보세요", "Move the pointer outside this app", "请将光标移到应用窗口外"],
        ["CaptureFailed"] = ["이 화면을 읽을 수 없습니다", "Cannot capture this screen", "无法读取此屏幕"],
        ["Pin"] = ["색상 고정", "Pin color", "固定颜色"],
        ["Resume"] = ["실시간 측정 재개", "Resume picking", "继续实时取色"],
        ["CopyFormat"] = ["{0} 복사", "Copy {0}", "复制 {0}"],
        ["Copied"] = ["복사 완료 ✓", "Copied ✓", "已复制 ✓"],
        ["CopiedNotice"] = ["클립보드에 복사됨", "COPIED TO CLIPBOARD", "已复制到剪贴板"],
        ["CopyFailed"] = ["복사 재시도 필요", "Please try copying again", "复制失败，请重试"],
        ["PickFirst"] = ["먼저 화면의 색을 골라주세요", "Pick a screen color first", "请先选择屏幕上的颜色"],
        ["RecentColors"] = ["최근 복사한 색상", "Recent colors", "最近复制的颜色"],
        ["CopyAgain"] = ["눌러서 다시 복사", "Click to copy again", "点击再次复制"],
        ["HistoryEmpty"] = ["복사한 색상이 여기에 모입니다.", "Your copied colors appear here.", "复制过的颜色将显示在此处。"],
        ["HistoryTooltip"] = ["{0} · 클릭하여 복사", "{0} · click to copy", "{0} · 点击复制"],
        ["HistorySaveFailed"] = ["복사 완료 · 기록 저장 실패", "Copied · history not saved", "已复制，但无法保存历史记录"],
        ["Ready"] = ["색상을 골라보세요", "READY TO PICK", "请选择颜色"],
        ["CopyShortcut"] = ["복사     Ctrl + Shift + C", "Copy    Ctrl + Shift + C", "复制    Ctrl + Shift + C"],
        ["PinShortcut"] = ["고정     Ctrl + Shift + Space", "Pin     Ctrl + Shift + Space", "固定    Ctrl + Shift + Space"],
        ["Settings"] = ["설정", "Settings", "设置"],
        ["WindowMode"] = ["창 모드", "Window mode", "窗口模式"],
        ["StandardMode"] = ["기본 모드", "Standard", "标准模式"],
        ["MiniMode"] = ["미니 모드", "Mini", "迷你模式"],
        ["EnterMiniMode"] = ["미니 모드로 전환", "Switch to mini mode", "切换为迷你模式"],
        ["ExitMiniMode"] = ["기본 모드로 전환", "Return to standard mode", "返回标准模式"],
        ["PinShort"] = ["고정", "Pin", "固定"],
        ["ResumeShort"] = ["재개", "Resume", "继续"],
        ["SettingsIntro"] = ["나에게 맞는 Pixel Pin으로.", "Make Pixel Pin your own.", "让 Pixel Pin 更合你的心意。"],
        ["Theme"] = ["화면 모드", "Appearance", "外观模式"],
        ["System"] = ["기기 설정 따르기", "Use device settings", "跟随系统"],
        ["Light"] = ["라이트 모드", "Light", "浅色模式"],
        ["Dark"] = ["다크 모드", "Dark", "深色模式"],
        ["Language"] = ["언어", "Language", "语言"],
        ["Format"] = ["색상 포맷", "Color format", "颜色格式"],
        ["FormatHint"] = ["표시와 복사에 선택한 포맷을 사용합니다.", "Used for display and copying.", "显示和复制均使用所选格式。"],
        ["HsvHint"] = ["HSV는 CSS 문법이 아닌 색상 수치입니다.", "HSV is a color value format, not CSS syntax.", "HSV 表示颜色数值，并非 CSS 语法。"],
        ["CmykHint"] = ["화면 RGB를 환산한 참고용 값입니다. ICC 인쇄 프로파일을 적용하지 않아 실제 인쇄용 CMYK와 다를 수 있습니다.", "Reference values calculated from screen RGB. No ICC print profile is applied; actual print CMYK may differ.", "此数值仅由屏幕 RGB 换算而来，供参考使用。未应用 ICC 印刷配置文件，可能与实际印刷 CMYK 数值不同。"],
        ["CmykOption"] = ["CMYK · 참고용", "CMYK · reference", "CMYK · 参考值"],
        ["AutoSaved"] = ["변경하면 바로 적용되고 저장됩니다.", "Changes apply and save automatically.", "更改会立即生效并自动保存。"],
        ["SettingsSaveFailed"] = ["설정은 적용됐지만 저장하지 못했습니다.", "Applied, but settings could not be saved.", "设置已生效，但无法保存。"],
        ["LocalData"] = ["이 PC에 저장된 데이터", "Data on this PC", "本机数据"],
        ["LocalDataHint"] = ["최근 색상과 설정은 이 PC에만 저장됩니다. 기록 삭제는 Windows 클립보드 기록을 지우지 않습니다.", "Recent colors and preferences stay on this PC. Clearing colors does not clear Windows clipboard history.", "最近颜色和偏好设置仅保存在本机。清除颜色不会删除 Windows 剪贴板历史记录。"],
        ["ClearHistory"] = ["최근 색상 삭제", "Clear recent colors", "清除最近颜色"],
        ["ClearHistoryConfirm"] = ["이전 버전의 기록을 포함해 최근 색상을 삭제할까요? 이 작업은 되돌릴 수 없습니다. 클립보드 기록은 유지됩니다.", "Clear recent colors, including legacy history? This cannot be undone. Clipboard history will remain.", "清除最近颜色（包括旧版记录）？此操作无法撤销，剪贴板历史记录会保留。"],
        ["HistoryCleared"] = ["최근 색상을 삭제했습니다.", "Recent colors cleared.", "已清除最近颜色。"],
        ["ResetSettings"] = ["설정 기본값으로 복원", "Restore default preferences", "恢复默认设置"],
        ["ResetSettingsConfirm"] = ["화면 모드·언어·색상 포맷·창 모드를 기본값으로 되돌릴까요? 기기 설정 따르기·한국어·HEX·기본 창으로 바뀌며 최근 색상은 유지됩니다.", "Restore appearance, language, format, and window mode to device settings, Korean, HEX, and the standard window? Recent colors will remain.", "将外观、语言、格式和窗口模式恢复为跟随系统、韩语、HEX 和标准窗口？最近颜色会保留。"],
        ["SettingsReset"] = ["기본 설정으로 되돌렸습니다.", "Default preferences restored.", "已恢复默认设置。"],
        ["DataClearFailed"] = ["일부 데이터를 저장하거나 삭제하지 못했습니다. 앱을 종료한 뒤 로컬 파일을 확인해 주세요.", "Some data could not be saved or removed. Close the app and check the local files.", "部分数据未能保存或删除，请关闭应用后检查本地文件。"],
        ["Information"] = ["이용 안내", "About your use", "使用说明"],
        ["Privacy"] = ["개인정보처리방침", "Privacy Policy", "隐私政策"],
        ["Terms"] = ["이용약관", "Terms of Use", "使用条款"],
        ["SupportPolicy"] = ["후원 및 결제 안내", "Support & payments", "支持开发与付款说明"],
        ["Close"] = ["닫기", "Close", "关闭"],
        ["Minimize"] = ["최소화", "Minimize", "最小化"],
        ["OpenTeamHjd"] = ["TeamHJD 사이트 열기", "Visit TeamHJD", "访问 TeamHJD 网站"],
        ["BrowserFailed"] = ["브라우저를 열 수 없습니다", "Could not open the browser", "无法打开浏览器"],
        ["HotkeyConflict"] = ["단축키 충돌 · 버튼 사용", "Shortcut in use · use buttons", "快捷键冲突，请使用按钮"],
        ["HotkeyHint"] = ["다른 프로그램에서 단축키를 사용하고 있습니다. 앱 안의 버튼은 정상 작동합니다.", "Another app uses this shortcut. The buttons still work.", "其他程序正在使用此快捷键。应用内按钮仍可正常使用。"],
        ["ClickUnavailable"] = ["클릭 감지 불가 · 고정 버튼 사용", "Click detection unavailable · use Pin", "无法检测点击，请使用固定按钮"],
    };
    public static string Get(string key, params object[] values)
    {
        string text = Strings.TryGetValue(key, out var translations) ? translations[(int)SettingsStore.Current.Language] : key;
        return values.Length == 0 ? text : string.Format(CultureInfo.InvariantCulture, text, values);
    }
    public static void Apply()
    {
        foreach (string key in Strings.Keys) Application.Current.Resources["L." + key] = Get(key);
    }
    public static XmlLanguage LanguageTag => XmlLanguage.GetLanguage(SettingsStore.Current.Language switch { UiLanguage.English => "en-US", UiLanguage.Chinese => "zh-CN", _ => "ko-KR" });
}
