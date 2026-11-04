// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PixelPin",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PixelPin", targets: ["PixelPin"])],
    targets: [
        .executableTarget(
            name: "PixelPin",
            path: "Sources/PixelPin",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit")
            ]
        )
    ]
)
