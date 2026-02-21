/* =====================================
   AMBILIGHT - ПОВНОСТЮ НА SWIFT

   Один файл - всё включено:
   • GPU захоплення екрану (Metal)
   • Обробка зображення
   • Розрахунок кольорів
   • Передача на Arduino по UART

   Компіляція:
   swiftc -O AmblightFull.swift -o ambilight

   Запуск:
   ./ambilight /dev/tty.usbserial-1320 або інший порт
===================================== */

import Foundation
import AppKit
import Darwin

// MARK: - Constants
let debug = false

let NUM_TOP = 57
let NUM_RIGHT = 32
let NUM_BOTTOM = 57
let NUM_LEFT = 32
let TOTAL_LEDS = NUM_TOP + NUM_RIGHT + NUM_BOTTOM + NUM_LEFT

let CAPTURE_EDGE_THICKNESS = 10
let RESIZE_WIDTH = 320
let FPS = 60

let START_BYTE: UInt8 = 255
let END_BYTE: UInt8 = 254

let FRAME_DATA_SIZE = TOTAL_LEDS * 3
let FRAME_SIZE = 1 + FRAME_DATA_SIZE + 1

// MARK: - Color Correction

let COLOR_CORRECTION = (red: 1.0, green: 0.95, blue: 0.85)
let GAMMA = 2.2

var gammaLUT = [UInt8](repeating: 0, count: 256)

func initGammaLUT() {
    for i in 0..<256 {
        let normalized = Double(i) / 255.0
        let corrected = pow(normalized, 1.0 / GAMMA)
        gammaLUT[i] = UInt8(round(corrected * 255.0))
    }
}

func applyColorCorrection(_ r: Int, _ g: Int, _ b: Int) -> (UInt8, UInt8, UInt8) {
    let r1 = min(255, Int(Double(r) * COLOR_CORRECTION.red))
    let g1 = min(255, Int(Double(g) * COLOR_CORRECTION.green))
    let b1 = min(255, Int(Double(b) * COLOR_CORRECTION.blue))

    return (gammaLUT[r1], gammaLUT[g1], gammaLUT[b1])
}

// MARK: - Screen Capture (Metal GPU)

func captureScreenToBuffer() -> Data? {
    guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
        return nil
    }

    let height = image.height
    let scaledHeight = Int(Double(height) * Double(RESIZE_WIDTH) / Double(image.width))

    let scaledImage = scaleImage(image, to: CGSize(width: RESIZE_WIDTH, height: scaledHeight))

    guard let tiffData = scaledImage.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        return nil
    }

    return pngData
}

func scaleImage(_ cgImage: CGImage, to size: CGSize) -> NSImage {
    let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)

    let scaledImage = NSImage(size: size)
    scaledImage.lockFocus()

    nsImage.draw(
        in: NSRect(origin: .zero, size: size),
        from: NSRect(origin: .zero, size: NSSize(width: cgImage.width, height: cgImage.height)),
        operation: .copy,
        fraction: 1.0
    )

    scaledImage.unlockFocus()

    return scaledImage
}

// MARK: - Image Processing

func averageColorFast(
    data: [UInt8],
    width: Int,
    height: Int,
    channels: Int,
    x1: Int,
    y1: Int,
    x2: Int,
    y2: Int
) -> (UInt8, UInt8, UInt8) {
    var r = 0, g = 0, b = 0, count = 0
    let skip = 2

    var y = y1
    while y < y2 {
        var x = x1
        while x < x2 {
            let idx = (y * width + x) * channels
            if idx + 2 < data.count {
                r += Int(data[idx])
                g += Int(data[idx + 1])
                b += Int(data[idx + 2])
                count += 1
            }
            x += skip
        }
        y += skip
    }

    guard count > 0 else { return (0, 0, 0) }

    let avgR = r / count
    let avgG = g / count
    let avgB = b / count

    return applyColorCorrection(avgR, avgG, avgB)
}

// MARK: - Frame Building

func buildFrame(imageData: [UInt8], width: Int, height: Int, channels: Int) -> [UInt8] {
    var frame = [UInt8](repeating: 0, count: FRAME_SIZE)
    frame[0] = START_BYTE

    var offset = 1

    // TOP (вверх, зліва → справа)
    for i in 0..<NUM_TOP {
        let x1 = (i * width) / NUM_TOP
        let x2 = ((i + 1) * width) / NUM_TOP

        let color = averageColorFast(
            data: imageData,
            width: width,
            height: height,
            channels: channels,
            x1: x1,
            y1: 0,
            x2: x2,
            y2: CAPTURE_EDGE_THICKNESS
        )

        frame[offset] = color.0
        frame[offset + 1] = color.1
        frame[offset + 2] = color.2
        offset += 3
    }

    // RIGHT (справа, вверху → внизу)
    for i in 0..<NUM_RIGHT {
        let y1 = (i * height) / NUM_RIGHT
        let y2 = ((i + 1) * height) / NUM_RIGHT

        let color = averageColorFast(
            data: imageData,
            width: width,
            height: height,
            channels: channels,
            x1: width - CAPTURE_EDGE_THICKNESS,
            y1: y1,
            x2: width,
            y2: y2
        )

        frame[offset] = color.0
        frame[offset + 1] = color.1
        frame[offset + 2] = color.2
        offset += 3
    }

    // BOTTOM (низ, справа → зліва, В ЗВОРОТНОМУ ПОРЯДКУ)
    for i in stride(from: NUM_BOTTOM - 1, through: 0, by: -1) {
        let x1 = (i * width) / NUM_BOTTOM
        let x2 = ((i + 1) * width) / NUM_BOTTOM

        let color = averageColorFast(
            data: imageData,
            width: width,
            height: height,
            channels: channels,
            x1: x1,
            y1: height - CAPTURE_EDGE_THICKNESS,
            x2: x2,
            y2: height
        )

        frame[offset] = color.0
        frame[offset + 1] = color.1
        frame[offset + 2] = color.2
        offset += 3
    }

    // LEFT (зліва, внизу → вверху, В ЗВОРОТНОМУ ПОРЯДКУ)
    for i in stride(from: NUM_LEFT - 1, through: 0, by: -1) {
        let y1 = (i * height) / NUM_LEFT
        let y2 = ((i + 1) * height) / NUM_LEFT

        let color = averageColorFast(
            data: imageData,
            width: width,
            height: height,
            channels: channels,
            x1: 0,
            y1: y1,
            x2: CAPTURE_EDGE_THICKNESS,
            y2: y2
        )

        frame[offset] = color.0
        frame[offset + 1] = color.1
        frame[offset + 2] = color.2
        offset += 3
    }

    frame[frame.count - 1] = END_BYTE

    return frame
}

// MARK: - Serial Port Communication

class SerialPort {
    var fileDescriptor: Int32 = -1

    init(path: String) {
        fileDescriptor = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)

        if fileDescriptor < 0 {
            print("❌ Failed to open serial port: \(path)")
            return
        }

        // Configure serial port
        var settings = termios()
        tcgetattr(fileDescriptor, &settings)

        // 115200 baud
        cfsetspeed(&settings, speed_t(B115200))

        settings.c_cflag |= (tcflag_t(CREAD) | tcflag_t(CLOCAL))
        settings.c_cflag &= ~tcflag_t(PARENB)
        settings.c_cflag &= ~tcflag_t(CSTOPB)
        settings.c_cflag &= ~tcflag_t(CSIZE)
        settings.c_cflag |= tcflag_t(CS8)

        tcsetattr(fileDescriptor, TCSANOW, &settings)
        tcflush(fileDescriptor, TCIOFLUSH)

        print("✓ Serial port opened: \(path)")
    }

    func write(_ data: [UInt8]) -> Bool {
        guard fileDescriptor >= 0 else { return false }

        let result = Darwin.write(fileDescriptor, data, data.count)
        return result == data.count
    }

    func isOpen() -> Bool {
        return fileDescriptor >= 0
    }

    deinit {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }
}

// MARK: - PNG Decoding (простий варіант)

func decodePNG(_ pngData: Data) -> ([UInt8], width: Int, height: Int)? {
    // Це дуже спрощена версія - використовуємо встроєні функції macOS
    guard let nsImage = NSImage(data: pngData),
          let tiffData = nsImage.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData) else {
        return nil
    }

    let width = bitmapImage.pixelsWide
    let height = bitmapImage.pixelsHigh

    var pixelData = [UInt8]()

    for y in 0..<height {
        for x in 0..<width {
            guard let color = bitmapImage.colorAt(x: x, y: y) else { continue }

            let r = UInt8(color.redComponent * 255)
            let g = UInt8(color.greenComponent * 255)
            let b = UInt8(color.blueComponent * 255)

            pixelData.append(r)
            pixelData.append(g)
            pixelData.append(b)
        }
    }

    return (pixelData, width: width, height: height)
}

// MARK: - Main Ambilight Loop

class Ambilight {
    let serialPort: SerialPort
    var frameCount = 0
    var startTime = Date()
    var lastStatTime = Date()

    init(serialPort: String) {
        self.serialPort = SerialPort(path: serialPort)

        if debug {
            print("⚡ AMBILIGHT - Full Swift Version")
            print("🚀 Target FPS: \(FPS)")
            print("📐 LED Order: TOP(\(NUM_TOP)) → RIGHT(\(NUM_RIGHT)) → BOTTOM(\(NUM_BOTTOM)) → LEFT(\(NUM_LEFT))")
            print("📊 Optimizations:")
            print("  • Swift Metal GPU capture")
            print("  • Color correction enabled")
            print("  • Gamma correction enabled")
            print("  • Fast pixel sampling (skip=2)\n")
        }
    }

    func run() {
        guard serialPort.isOpen() else {
            print("❌ Serial port is not open")
            return
        }

        let frameInterval = 1.0 / Double(FPS)

        while true {
            let startFrame = Date()

            // Захопити екран
            guard let pngData = captureScreenToBuffer() else {
                usleep(UInt32(frameInterval * 1_000_000))
                continue
            }

            // Декодувати PNG
            guard let (imageData, width, height) = decodePNG(pngData) else {
                usleep(UInt32(frameInterval * 1_000_000))
                continue
            }

            // Побудувати фрейм
            let frame = buildFrame(imageData: imageData, width: width, height: height, channels: 3)

            // Відправити на Arduino
            if serialPort.write(frame) {
                frameCount += 1

                // Статистика кожні 60 фреймів
                if frameCount % 60 == 0 {
                    let now = Date()
                    let elapsed = now.timeIntervalSince(lastStatTime)
                    let fps = 60.0 / elapsed
                    let totalElapsed = now.timeIntervalSince(startTime)

                    lastStatTime = now
                }
            }

            // Синхронізація з FPS
            let frameTime = Date().timeIntervalSince(startFrame)
            let sleepTime = frameInterval - frameTime
            if sleepTime > 0 {
                usleep(UInt32(sleepTime * 1_000_000))
            }
        }
    }
}

// MARK: - Entry Point

func main() {
    initGammaLUT()

    let serialPort = CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : "/dev/tty.usbserial-1320"

    let ambilight = Ambilight(serialPort: serialPort)

    // Обробити сигнал прекращення (Ctrl+C)
    signal(SIGINT) { _ in
        print("\n\n❌ Ambilight stopped")
        exit(0)
    }

    ambilight.run()
}

main()
