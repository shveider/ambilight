import Foundation
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let ambilightWindow = AmbilightWindow(width: 900, height: 560)
ambilightWindow.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

let capture       = ScreenCapture()
let colorReader   = ColorReader(zonesLeftRight: 32, zonesTopBottom: 57, stripThickness: 10)
let arduinoFinder = ArduinoPathFinder()
let arduino       = arduinoFinder.findPort().map { ArduinoSender(portPath: $0) }
var frameCount    = 0
let startTime     = Date()

// 1. Спочатку підписуємось на кадри
capture.onFrame = { cgImage in
    frameCount += 1
    let elapsed = Date().timeIntervalSince(startTime)
    print("Кадр #\(frameCount) | \(String(format: "%.3f", elapsed))s")

    let colors = colorReader.readColors(from: cgImage)
    ambilightWindow.updateColors(colors)
    arduino?.sendColors(colors)
}

// 2. Потім стартуємо все
Task {
    do {
        try arduino?.connect()
    } catch {
        print("⚠️ Помилка підключення до Arduino: \(error)")
    }
}

Task {
    do {
        try await capture.startCapture()
    } catch {
        print("❌ Помилка захоплення екрану: \(error)")
    }
}

app.run()