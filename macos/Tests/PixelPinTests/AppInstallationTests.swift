import XCTest
@testable import PixelPin

final class AppInstallationTests: XCTestCase {
    func testApplicationsDirectoriesAllowInstalledApps() {
        let home = URL(fileURLWithPath: "/Users/tester")
        for path in ["/Applications/Pixel Pin.app", "/Applications/Utilities/Pixel Pin.app", "/Users/tester/Applications/Pixel Pin.app"] {
            XCTAssertTrue(AppInstallation.isInstalled(URL(fileURLWithPath: path), home: home))
        }
    }

    func testDownloadsVolumesAndSimilarPrefixesAreNotInstalled() {
        let home = URL(fileURLWithPath: "/Users/tester")
        for path in ["/Users/tester/Downloads/Pixel Pin.app", "/Volumes/Pixel Pin/Pixel Pin.app", "/Applications-Backup/Pixel Pin.app", "/Users/tester/Applications-copy/Pixel Pin.app"] {
            XCTAssertFalse(AppInstallation.isInstalled(URL(fileURLWithPath: path), home: home))
        }
    }
}
