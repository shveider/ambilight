import CoreGraphics
import Foundation

class ScreenCapture {
    var onFrame: ((CGDirectDisplayID) -> Void)?
    private var timer: Timer?
    private let processQueue = DispatchQueue(label: "capture.process", qos: .userInteractive)
    private var isProcessing = false

    func startCapture() async throws {
        let displayID = CGMainDisplayID()
        await MainActor.run {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
                guard let self, !self.isProcessing else { return }
                self.isProcessing = true
                self.processQueue.async {
                    autoreleasepool {
                        self.onFrame?(displayID)
                    }
                    self.isProcessing = false
                }
            }
        }
        print("✅ Legacy режим — 20 FPS")
    }

    func stopCapture() async throws {
        await MainActor.run { timer?.invalidate(); timer = nil }
    }
}