import CoreGraphics
import Foundation

// MARK: - Protocol (дублюємо щоб файл був самодостатній)

protocol ScreenCaptureProtocol {
    var onFrame: ((CGImage) -> Void)? { get set }
    func startCapture() async throws
    func stopCapture() async throws
}

enum CaptureError: Error {
    case noDisplayFound
}
// MARK: - LegacyImpl

class ScreenCapture: ScreenCaptureProtocol {

    var onFrame: ((CGImage) -> Void)?
    private var timer: Timer?

    func startCapture() async throws {
        await MainActor.run {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
                self?.captureFrame()
            }
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
        autoreleasepool {
            let displayID = CGMainDisplayID()
            // CGDisplayCreateImage доступний на Big Sur (macOS 11)
            guard let image = CGDisplayCreateImage(displayID) else { return }
            onFrame?(image)
        }
    }
}