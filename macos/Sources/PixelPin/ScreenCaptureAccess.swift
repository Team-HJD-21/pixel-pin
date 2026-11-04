import CoreGraphics
import Foundation
import ScreenCaptureKit

enum ScreenCaptureAccess {
    // Preflight is useful for prompting, but never substitutes for attempting SCK.
    @MainActor static func fetch<T>(requestPermission: Bool,
                         preflight: () -> Bool = CGPreflightScreenCaptureAccess,
                         request: () -> Bool = CGRequestScreenCaptureAccess,
                         content: () async throws -> T) async rethrows -> T {
        if requestPermission && !preflight() { _ = request() }
        return try await content()
    }

    static func isDenied(_ error: Error) -> Bool {
        let failure = error as NSError
        return failure.domain == SCStreamError.errorDomain && failure.code == SCStreamError.Code.userDeclined.rawValue
    }
}
