// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PixelPin",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PixelPin", targets: ["PixelPin"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ],
    targets: [
        .executableTarget(
            name: "PixelPin",
            dependencies: [.product(name: "Sparkle", package: "sparkle")],
            path: "Sources/PixelPin",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit")
            ]
        )
    ]
)
