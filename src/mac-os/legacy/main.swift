import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    let capture = ScreenCapture()

    let colorReader: ColorReader

    let arduinoFinder = ArduinoPathFinder()
    lazy var arduino  = arduinoFinder.findPort().map { ArduinoSender(portPath: $0) }

    override init() {

        // читаємо аргументи
        let args = CommandLine.arguments

        var padding = 0

        if args.count > 1, let value = Int(args[1]) {
            padding = value
        }

        print("🎬 TopBottomPadding = \(padding)")

        self.colorReader = ColorReader(
            zonesLeftRight: 32,
            zonesTopBottom: 57,
            stripThickness: 8,
            topBottomPadding: padding
        )

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        capture.onFrame = { [weak self] displayID in
            guard let self else { return }
            let colors = self.colorReader.readColors(displayID: displayID)
            self.arduino?.sendColors(colors)
        }

        Task {
            try? self.arduino?.connect()
        }

        Task {
            try? await self.capture.startCapture()
        }
    }
}