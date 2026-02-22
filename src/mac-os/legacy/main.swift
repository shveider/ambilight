import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let capture       = ScreenCapture()
    let colorReader   = ColorReader(zonesLeftRight: 32, zonesTopBottom: 57, stripThickness: 8)
    let arduinoFinder = ArduinoPathFinder()
    lazy var arduino  = arduinoFinder.findPort().map { ArduinoSender(portPath: $0) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        capture.onFrame = { [weak self] displayID in
            guard let self else { return }
            let colors = self.colorReader.readColors(displayID: displayID)
            self.arduino?.sendColors(colors)
        }

        Task {
            do {
                try self.arduino?.connect()
            } catch {
                print("⚠️ Arduino: \(error)")
            }
        }

        Task {
            do {
                print("🔄 Починаємо захоплення...")
                try await self.capture.startCapture()
            } catch {
                print("❌ Помилка: \(error)")
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()