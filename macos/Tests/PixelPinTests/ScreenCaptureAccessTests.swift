import XCTest
import ScreenCaptureKit
@testable import PixelPin

@MainActor final class ScreenCaptureAccessTests: XCTestCase {
    func testAutomaticCaptureTriesScreenCaptureKitWithoutAnotherPermissionRequest() async {
        let result = await ScreenCaptureAccess.fetch(requestPermission: false,
            preflight: { XCTFail("Automatic start must not gate on preflight"); return false },
            request: { XCTFail("Automatic start must not force a second permission prompt"); return false },
            content: { "authorized frame source" })
        XCTAssertEqual(result, "authorized frame source")
    }

    func testExplicitRetryStillTriesCaptureWhenPermissionResultIsStale() async {
        var requested = false
        let result = await ScreenCaptureAccess.fetch(requestPermission: true,
            preflight: { false }, request: { requested = true; return false }, content: { 1 })
        XCTAssertTrue(requested)
        XCTAssertEqual(result, 1)
    }

    func testPermissionErrorsRemainDistinguishableFromCaptureFailures() async {
        let denied = NSError(domain: SCStreamError.errorDomain, code: SCStreamError.Code.userDeclined.rawValue)
        do {
            _ = try await ScreenCaptureAccess.fetch(requestPermission: false, content: { throw denied })
            XCTFail("Denied capture must propagate the failure")
        } catch { XCTAssertTrue(ScreenCaptureAccess.isDenied(error)) }
        XCTAssertFalse(ScreenCaptureAccess.isDenied(NSError(domain: "other", code: denied.code)))
    }
}
