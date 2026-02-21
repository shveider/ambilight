import Foundation
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let capture       = ScreenCapture()
let colorReader   = ColorReader(zonesLeftRight: 32, zonesTopBottom: 57, stripThickness: 8)
let arduinoFinder = ArduinoPathFinder()
let arduino       = arduinoFinder.findPort().map { ArduinoSender(portPath: $0) }

// Window is needed for debug
//let ambilightWindow = AmbilightWindow(width: 900, height: 560)
//ambilightWindow.makeKeyAndOrderFront(nil)

// 1. Підписуємось на кадри
capture.onFrame = { pixelBuffer in
    let colors = colorReader.readColors(from: pixelBuffer)
    // ambilightWindow.updateColors(colors)
    arduino?.sendColors(colors)
}

// 2. Підключаємо Arduino
Task {
    do {
        try arduino?.connect()
    } catch {
        print("⚠️ Помилка підключення до Arduino: \(error)")
    }
}

// 3. Стартуємо захоплення
Task {
    do {
        print("🔄 Починаємо захоплення...")
        try await capture.startCapture()
    } catch {
        print("❌ Помилка захоплення екрану: \(error)")
    }
}

app.run()