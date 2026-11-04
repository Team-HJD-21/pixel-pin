import AppKit

// Draw the installer artwork directly; no Finder automation or screen access.
let width: CGFloat = 720, height: CGFloat = 500
func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: height - y - h, width: w, height: h)
}
func artwork(scale: Int) -> NSBitmapImageRep {
    let context = CGContext(data: nil, width: Int(width) * scale, height: Int(height) * scale,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    color(0xF5F7FD).setFill()
    NSBezierPath(rect: rect(0, 0, width, height)).fill()
    func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, ink: Int = 0x263349) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        (value as NSString).draw(in: rect(24, y, width - 48, size * 1.6), withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color(ink), .paragraphStyle: style
        ])
    }
    text("Pixel Pin", y: 27, size: 32, weight: .bold)
    text("Drag Pixel Pin to Applications", y: 81, size: 17, weight: .semibold)
    text("Pixel Pin을 응용 프로그램 폴더로 옮겨 주세요.", y: 111, size: 13, ink: 0x56647A)
    text("将 Pixel Pin 拖到“应用程序”文件夹。", y: 134, size: 13, ink: 0x56647A)
    for x in [CGFloat(115), CGFloat(435)] {
        let tile = NSBezierPath(roundedRect: rect(x, 182, 170, 151), xRadius: 25, yRadius: 25)
        NSColor.white.setFill(); tile.fill()
        color(0xE0E6F2).setStroke(); tile.lineWidth = 1; tile.stroke()
    }
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 330, y: height - 240))
    arrow.line(to: NSPoint(x: 390, y: height - 240))
    arrow.move(to: NSPoint(x: 377, y: height - 227))
    arrow.line(to: NSPoint(x: 390, y: height - 240))
    arrow.line(to: NSPoint(x: 377, y: height - 253))
    color(0x547CF0).setStroke(); arrow.lineWidth = 4; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
    text("Then open Pixel Pin from Applications.", y: 363, size: 15, weight: .medium)
    text("복사가 끝나면 이 디스크를 추출하고, 응용 프로그램에서 앱을 실행하세요.", y: 391, size: 12, ink: 0x56647A)
    text("复制完成后，推出此磁盘，再从“应用程序”打开 Pixel Pin。", y: 415, size: 12, ink: 0x56647A)
    text("Allow Screen Recording on first launch to start picking colors.", y: 457, size: 11, ink: 0x56647A)
    text("처음 실행할 때 화면 기록 권한을 허용해 주세요. · 首次打开时请允许屏幕录制。", y: 477, size: 10, ink: 0x56647A)
    let result = NSBitmapImageRep(cgImage: context.makeImage()!)
    result.size = NSSize(width: width, height: height)
    NSGraphicsContext.restoreGraphicsState()
    return result
}
let standard = artwork(scale: 1)
let image = NSImage(size: NSSize(width: width, height: height))
image.addRepresentation(standard)
image.addRepresentation(artwork(scale: 2))
try image.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
try standard.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
