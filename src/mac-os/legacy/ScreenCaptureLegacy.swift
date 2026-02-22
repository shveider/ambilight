import CoreGraphics
import Foundation
import IOSurface
import QuartzCore

class ScreenCapture {

    var onFrame: ((CGDirectDisplayID) -> Void)?

    private var displayStream: CGDisplayStream?
    private let processQueue = DispatchQueue(label: "capture.stream", qos: .userInitiated)
    private let semaphore = DispatchSemaphore(value: 1)

    private var lastFrameTime: CFTimeInterval = 0
    private let maxFPS: Double = 20.0

    func startCapture() async throws {

        let displayID = CGMainDisplayID()
        let width = 160   // одразу downscale
        let height = 90

        displayStream = CGDisplayStream(
            dispatchQueueDisplay: displayID,
            outputWidth: width,
            outputHeight: height,
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: nil,
            queue: processQueue
        ) { [weak self] status, _, surface, _ in

            guard let self else { return }
            guard status == .frameComplete else { return }

            // FPS limit
            let now = CACurrentMediaTime()
            guard now - self.lastFrameTime > (1.0 / self.maxFPS) else { return }
            self.lastFrameTime = now

            // не обробляємо якщо ще зайняті
            guard self.semaphore.wait(timeout: .now()) == .success else { return }

            autoreleasepool {
                self.onFrame?(displayID)
            }

            self.semaphore.signal()
        }

        displayStream?.start()

        print("✅ CGDisplayStream запущено — стабільні 20 FPS")
    }

    func stopCapture() async throws {
        displayStream?.stop()
        displayStream = nil
    }
}