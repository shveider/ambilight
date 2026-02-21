import Foundation
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

// Window is needed for debug
//let ambilightWindow = AmbilightWindow(width: 900, height: 560)
//ambilightWindow.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

let capture       = ScreenCapture()
let colorReader   = ColorReader(zonesLeftRight: 32, zonesTopBottom: 57, stripThickness: 8)
let arduinoFinder = ArduinoPathFinder()
let arduino       = arduinoFinder.findPort().map { ArduinoSender(portPath: $0) }
let startTime     = Date()

// 1. Спочатку підписуємось на кадри
capture.onFrame = { pixelBuffer in
    let colors = colorReader.readColors(from: pixelBuffer)
//    ambilightWindow.updateColors(colors)
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
        print("🔄 Починаємо захоплення...")

        // Чекаємо секунду і перевіряємо чи є кадри
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let kitCapture = capture as? ScreenCapture
        print("⏱ Кадрів отримано за 1 секунду: \(kitCapture?.frameCount ?? 0)")
    } catch {
        print("❌ Помилка захоплення екрану: \(error)")
    }
}

app.run()