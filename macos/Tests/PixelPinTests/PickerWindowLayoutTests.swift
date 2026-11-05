import XCTest
@testable import PixelPin

final class PickerWindowLayoutTests: XCTestCase {
    private let workArea = CGRect(x: -1440, y: 40, width: 1440, height: 860)

    func testSettingsExpandMiniWithoutChangingItsPreference() {
        let mini = PickerWindowLayout(miniMode: true, settingsOpen: false, workArea: workArea)
        let settings = PickerWindowLayout(miniMode: true, settingsOpen: true, workArea: workArea)
        XCTAssertTrue(mini.isMini)
        XCTAssertFalse(settings.isMini)
        XCTAssertTrue(settings.miniMode)
        XCTAssertGreaterThan(settings.contentSize.height, mini.contentSize.height)
        XCTAssertEqual(mini.contentSize, PickerWindowLayout(miniMode: settings.miniMode, settingsOpen: false, workArea: workArea).contentSize)
    }

    func testTogglePreservesTopLeftWhenThereIsRoom() {
        let current = CGRect(x: -1200, y: 100, width: 410, height: 760)
        let mini = PickerWindowLayout(miniMode: true, settingsOpen: false, workArea: workArea)
        let compact = mini.windowFrame(from: current, chromeHeight: 40)
        XCTAssertEqual(compact.minX, current.minX)
        XCTAssertEqual(compact.maxY, current.maxY)
        let standard = PickerWindowLayout(miniMode: false, settingsOpen: false, workArea: workArea)
        XCTAssertEqual(standard.windowFrame(from: compact, chromeHeight: 40), current)
    }

    func testExpansionStaysOnTheSameNegativeCoordinateDisplay() {
        let mini = CGRect(x: -330, y: 40, width: 320, height: 172)
        let layout = PickerWindowLayout(miniMode: true, settingsOpen: true, workArea: workArea)
        let expanded = layout.windowFrame(from: mini, chromeHeight: 40)
        XCTAssertTrue(workArea.contains(expanded))
        XCTAssertLessThanOrEqual(expanded.maxX, 0)
    }

    func testFullWindowFitsShorterDisplay() {
        let small = CGRect(x: 0, y: 0, width: 1024, height: 600)
        let layout = PickerWindowLayout(miniMode: false, settingsOpen: false, workArea: small)
        XCTAssertTrue(small.contains(layout.windowFrame(from: CGRect(x: 900, y: 0, width: 320, height: 172), chromeHeight: 40)))
    }
}
