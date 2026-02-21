// ONLY FOR 12.3+

import ScreenCaptureKit
import CoreGraphics
import Foundation

class ScreenCapture: NSObject, SCStreamOutput, SCStreamDelegate {

    private var stream: SCStream?
    private var latestFrame: CGImage?
    private let frameLock = NSLock()

    // FPS лічильник
    private(set) var frameCount = 0
    private var fpsLastTime = Date()

    // CIContext створюється ОДИН РАЗ
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,  // використовуємо GPU
        .cacheIntermediates: false     // не кешуємо проміжні результати
    ])

    var onFrame: ((CVPixelBuffer) -> Void)?

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
        config.minimumFrameInterval = CMTime(value: 1, timescale: 40)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        // Вимикаємо чергу кадрів щоб не накопичувались в памʼяті
        config.queueDepth = 3

        stream = SCStream(filter: filter, configuration: config, delegate: self)

        try stream?.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "capture.queue", qos: .userInteractive)
        )

        try await stream?.startCapture()
        print("✅ Захоплення розпочато — 40 FPS")
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
        print("stream 1")
        guard type == .screen, let imageBuffer = sampleBuffer.imageBuffer else { return }
        print("stream 2")
        // FPS
        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(fpsLastTime) >= 1.0 {
            print("📷 FPS: \(frameCount)")
            frameCount = 0
            fpsLastTime = now
        }
        print("stream 3")
        // Передаємо pixelBuffer напряму — без CGImage конвертації
        onFrame?(imageBuffer)
    }

    // MARK: - Get Latest Frame

    func getLatestFrame() -> CGImage? {
        print("getLatestFrame 1")
        frameLock.lock()
        print("getLatestFrame 2")
        defer { frameLock.unlock() }
        print("getLatestFrame 3")
        return latestFrame
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ Stream зупинився з помилкою: \(error)")
    }

    // MARK: - Errors

    enum CaptureError: Error {
        case noDisplayFound
    }
}