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
        for y in 0..<2 {
            for x in 0..<2 {
                let pixel = try XCTUnwrap(raster.color(x: x, y: y))
                let crop = try XCTUnwrap(raster.image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
                var rendered = [UInt8](repeating: 0, count: 4)
                try rendered.withUnsafeMutableBytes { buffer in
                    let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1,
                        bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                    context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
                // Validate rendered loupe pixels, without NSBitmapImageRep's
                // device-dependent NSColor conversion (the original bug).
                XCTAssertEqual(Int(rendered[0]), pixel.red)
                XCTAssertEqual(Int(rendered[1]), pixel.green)
                XCTAssertEqual(Int(rendered[2]), pixel.blue)
                XCTAssertEqual(rendered[3], 255)
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
