import AppKit
import XCTest
@testable import PixelPin

final class PixelRasterTests: XCTestCase {
    func testKnownColorsAndPaddedRowsMatchLoupeImage() throws {
        let raster = try XCTUnwrap(PixelRaster(bytes: Data([
            67, 118, 234, 255, 245, 173, 137, 255, 0, 0, 0, 0,
            78, 144, 126, 255, 0, 0, 0, 255, 0, 0, 0, 0
        ]), width: 2, height: 2, stride: 12))
        XCTAssertEqual(raster.color(x: 0, y: 0)?.hex, "#EA7643")
        XCTAssertEqual(raster.color(x: 1, y: 0)?.hex, "#89ADF5")
        XCTAssertEqual(raster.color(x: 0, y: 1)?.hex, "#7E904E")
        XCTAssertEqual(raster.image.colorSpace?.name, CGColorSpace.sRGB)
        let bitmap = NSBitmapImageRep(cgImage: raster.image)
        for y in 0..<2 {
            for x in 0..<2 {
                let pixel = try XCTUnwrap(raster.color(x: x, y: y))
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                XCTAssertEqual(Int((color.redComponent * 255).rounded()), pixel.red)
                XCTAssertEqual(Int((color.greenComponent * 255).rounded()), pixel.green)
                XCTAssertEqual(Int((color.blueComponent * 255).rounded()), pixel.blue)
            }
        }
    }

    func testInvalidBuffersAndCoordinatesAreRejected() {
        XCTAssertNil(PixelRaster(bytes: Data([0, 0, 0, 255]), width: 2, height: 1, stride: 4))
        let raster = PixelRaster(bytes: Data([0, 0, 0, 255]), width: 1, height: 1, stride: 4)
        XCTAssertNil(raster?.color(x: -1, y: 0))
        XCTAssertNil(raster?.color(x: 1, y: 0))
        XCTAssertNil(raster?.color(x: 0, y: 1))
    }
}
