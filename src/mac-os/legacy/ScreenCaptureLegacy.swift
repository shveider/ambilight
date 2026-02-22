import CoreGraphics
import Foundation

protocol ScreenCaptureProtocol {
    var onFrame: ((CGImage) -> Void)? { get set }
    func startCapture() async throws
    func stopCapture() async throws
}

enum CaptureError: Error {
    case noDisplayFound
}

class ScreenCapture: ScreenCaptureProtocol {

    var onFrame: ((CGImage) -> Void)?
    private var timer: Timer?
    private let processQueue = DispatchQueue(label: "capture.process", qos: .userInteractive)
    private var isProcessing = false

    private var frameCount = 0
    private var fpsLastTime = Date()

    func startCapture() async throws {
        await MainActor.run {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
                self?.captureFrame()
            }
            timer?.tolerance = 0.005
        }
        print("✅ Legacy режим — 20 FPS")
    }

    func stopCapture() async throws {
        await MainActor.run {
            timer?.invalidate()
            timer = nil
        }
        print("⛔ Захоплення зупинено")
    }

    private func captureFrame() {
        // Якщо попередній кадр ще обробляється — пропускаємо
        guard !isProcessing else { return }

        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(fpsLastTime) >= 1.0 {
            print("📷 Capture FPS: \(frameCount)")
            frameCount = 0
            fpsLastTime = now
        }

        // Захоплюємо на головному потоці
        let displayID = CGMainDisplayID()
        guard let image = CGDisplayCreateImage(displayID) else { return }

        // Обробляємо на фоновому
        isProcessing = true
        processQueue.async { [weak self] in
            autoreleasepool {
                self?.onFrame?(image)
            }
            self?.isProcessing = false
        }
    }
}