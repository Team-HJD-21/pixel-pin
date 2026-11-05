import XCTest
@testable import PixelPin

@MainActor final class MiniModeTests: XCTestCase {
    func testModePersistsWithoutResettingPinnedColorOrPreferences() {
        let domain = "com.teamhjd.pixelpin.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let model = PickerModel(defaults: defaults, startCapture: false)
        XCTAssertFalse(model.miniMode, "Existing preferences should keep the full window")
        model.color = PixelColor(red: 12, green: 123, blue: 234)
        model.frozen = true
        model.format = .cmyk
        model.language = .chinese
        model.theme = .dark
        model.history = [model.color.hex]
        model.settingsOpen = true
        model.toggleMiniMode()
        XCTAssertTrue(model.miniMode)
        XCTAssertFalse(model.settingsOpen)
        XCTAssertTrue(model.frozen)
        XCTAssertEqual(model.color, PixelColor(red: 12, green: 123, blue: 234))
        XCTAssertEqual(model.history, ["#0C7BEA"])
        XCTAssertEqual(model.format, .cmyk)
        XCTAssertEqual(model.language, .chinese)
        let relaunched = PickerModel(defaults: defaults, startCapture: false)
        XCTAssertTrue(relaunched.miniMode)
        XCTAssertEqual(relaunched.format, .cmyk)
        XCTAssertEqual(relaunched.language, .chinese)
        XCTAssertEqual(relaunched.theme, .dark)
        model.settingsOpen = true
        model.settingsOpen = false
        XCTAssertTrue(model.miniMode, "Dismissing settings must return to mini mode")
        model.toggleMiniMode()
        XCTAssertFalse(model.miniMode)
        XCTAssertTrue(model.frozen)
        XCTAssertFalse(PickerModel(defaults: defaults, startCapture: false).miniMode)
    }
}
