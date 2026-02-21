// ONLY FOR 12.3+

import ScreenCaptureKit
import CoreGraphics
import Foundation

class ScreenCapture: NSObject, SCStreamOutput {

    private var stream: SCStream?
    private var latestFrame: CGImage?
    private let frameLock = NSLock()

    // CIContext створюється ОДИН РАЗ
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,  // використовуємо GPU
        .cacheIntermediates: false     // не кешуємо проміжні результати
    ])

    var onFrame: ((CGImage) -> Void)?

    // MARK: - Start Capture

    func startCapture() async throws {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = availableContent.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        // Вимикаємо чергу кадрів щоб не накопичувались в памʼяті
        config.queueDepth = 3

        stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream?.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "capture.queue", qos: .userInteractive)
        )

        try await stream?.startCapture()
        print("✅ Захоплення розпочато — 60 FPS")
    }

    // MARK: - Stop Capture

    func stopCapture() async throws {
        try await stream?.stopCapture()
        stream = nil

        // Використовуємо withLock замість lock/unlock
        frameLock.withLock {
            latestFrame = nil
        }

        print("⛔ Захоплення зупинено")
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
        let imageBuffer = sampleBuffer.imageBuffer else { return }

        // Використовуємо autoreleasepool щоб CIImage звільнявся одразу після кадру
        autoreleasepool {
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)

            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

            frameLock.lock()
            latestFrame = cgImage
            frameLock.unlock()

            onFrame?(cgImage)
        }
    }

    // MARK: - Get Latest Frame

    func getLatestFrame() -> CGImage? {
        frameLock.lock()
        defer { frameLock.unlock() }
        return latestFrame
    }

    // MARK: - Errors

    enum CaptureError: Error {
        case noDisplayFound
    }
}