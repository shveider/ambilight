import CoreGraphics
import Foundation

class ScreenCapture {

    var onFrame: ((CGDirectDisplayID) -> Void)?
    private var timer: Timer?
    private let processQueue = DispatchQueue(label: "capture.process", qos: .userInitiated)
    private let semaphore = DispatchSemaphore(value: 1)

    func startCapture() async throws {
        let displayID = CGMainDisplayID()

        await MainActor.run {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
                guard let self else { return }

                // якщо ще обробляється кадр — пропускаємо
                guard self.semaphore.wait(timeout: .now()) == .success else { return }

                self.processQueue.async {
                    autoreleasepool {
                        self.onFrame?(displayID)
                    }
                    self.semaphore.signal()
                }
            }
        }

        print("✅ Optimized Legacy Capture — 20 FPS stable")
    }

    func stopCapture() async throws {
        await MainActor.run {
            timer?.invalidate()
            timer = nil
        }
    }
}