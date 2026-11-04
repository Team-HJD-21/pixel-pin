import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo

// One explicitly tagged sRGB raster supplies both the HEX value and the loupe.
struct PixelRaster {
    let image: CGImage
    let bytes: Data
    let stride: Int

    init?(bytes: Data, width: Int, height: Int, stride: Int) {
        guard width > 0, height > 0, stride >= width * 4, bytes.count >= stride * height,
              let provider = CGDataProvider(data: bytes as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                  bitsPerPixel: 32, bytesPerRow: stride, space: space,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                      .union(.byteOrder32Little), provider: provider, decode: nil,
                  shouldInterpolate: false, intent: .relativeColorimetric) else { return nil }
        self.image = image
        self.bytes = bytes
        self.stride = stride
    }

    func color(x: Int, y: Int) -> PixelColor? {
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return nil }
        let offset = y * stride + x * 4
        // ScreenCaptureKit delivers opaque, premultiplied BGRA screen pixels.
        let alpha = Int(bytes[offset + 3])
        guard alpha > 0 else { return nil }
        func channel(_ index: Int) -> Int { min(255, (Int(bytes[index]) * 255 + alpha / 2) / alpha) }
        return PixelColor(red: channel(offset + 2), green: channel(offset + 1), blue: channel(offset))
    }
}

final class ScreenCaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate {
    var onFrame: ((PixelRaster, CGRect) -> Void)?
    var onState: ((String) -> Void)?
    private var stream: SCStream?
    private var screenFrame = CGRect.zero
    private let queue = DispatchQueue(label: "com.teamhjd.pixelpin.capture")

    @MainActor func selectScreen() {
        if #available(macOS 14.0, *) {
            let picker = SCContentSharingPicker.shared
            picker.add(self)
            var configuration = SCContentSharingPickerConfiguration()
            configuration.allowedPickerModes = [.singleDisplay]
            picker.defaultConfiguration = configuration
            picker.isActive = true
            picker.present()
            onState?("selectScreen")
        } else {
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    let cursor = NSEvent.mouseLocation
                    let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main
                    let id = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                    guard let display = content.displays.first(where: { $0.displayID == id }), let screen else { return }
                    await start(filter: SCContentFilter(display: display, excludingWindows: []),
                        frame: screen.frame, width: display.width, height: display.height)
                } catch { onState?("captureError") }
            }
        }
    }

    @MainActor private func start(filter: SCContentFilter, frame: CGRect, width: Int, height: Int) async {
        do {
            if let stream { try? await stream.stopCapture() }
            self.stream = nil
            screenFrame = frame
            let config = SCStreamConfiguration()
            config.width = width
            config.height = height
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.colorSpaceName = CGColorSpace.sRGB
            config.showsCursor = false
            config.capturesAudio = false
            config.minimumFrameInterval = CMTime(value: 1, timescale: 20)
            config.queueDepth = 3
            let next = SCStream(filter: filter, configuration: config, delegate: self)
            try next.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            self.stream = next
            try await next.startCapture()
            onState?("live")
        } catch { onState?("captureError") }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue,
              let buffer = sampleBuffer.imageBuffer else { return }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let data = Data(bytes: base, count: stride * height)
        guard let raster = PixelRaster(bytes: data, width: CVPixelBufferGetWidth(buffer), height: height, stride: stride) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stream else { return }
            self.onFrame?(raster, self.screenFrame)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stream else { return }
            self.stream = nil
            self.onState?("captureError")
        }
    }
}

@available(macOS 14.0, *)
extension ScreenCaptureEngine: SCContentSharingPickerObserver {
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            let rect = filter.contentRect
            // The pointer is on the display selected through the system picker.
            let candidates = NSScreen.screens.filter { abs($0.frame.width - rect.width) < 1 && abs($0.frame.height - rect.height) < 1 }
            let screen = candidates.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? candidates.first ?? NSScreen.main
            guard let screen else { return }
            await start(filter: filter, frame: screen.frame,
                width: Int((rect.width * CGFloat(filter.pointPixelScale)).rounded()),
                height: Int((rect.height * CGFloat(filter.pointPixelScale)).rounded()))
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        DispatchQueue.main.async { [weak self] in self?.onState?(self?.stream == nil ? "selectScreen" : "live") }
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onState?("captureError") }
    }
}
