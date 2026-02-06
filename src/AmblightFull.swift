import Foundation
import AppKit
import Darwin

// MARK: CONFIG

let NUM_TOP = 57
let NUM_RIGHT = 32
let NUM_BOTTOM = 57
let NUM_LEFT = 32
let TOTAL_LEDS = NUM_TOP + NUM_RIGHT + NUM_BOTTOM + NUM_LEFT

let CAPTURE_EDGE_THICKNESS = 10
let RESIZE_WIDTH = 320
let FPS = 40

let START_BYTE: UInt8 = 255
let END_BYTE: UInt8 = 254

let FRAME_SIZE = 1 + TOTAL_LEDS * 3 + 1

// MARK: Gamma

let GAMMA = 2.2
var gammaLUT = [UInt8](repeating: 0, count: 256)

func initGamma() {
    for i in 0..<256 {
        let normalized = Double(i) / 255.0
        gammaLUT[i] = UInt8(pow(normalized, 1.0 / GAMMA) * 255.0)
    }
}

// MARK: Serial

class SerialPort {
    var fd: Int32 = -1

    init(path: String) {

        fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)

        if fd < 0 {
            perror("❌ open failed")
            return
        }

        var options = termios()

        if tcgetattr(fd, &options) != 0 {
            perror("❌ tcgetattr failed")
            return
        }

        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))

        options.c_cflag |= (tcflag_t(CLOCAL) | tcflag_t(CREAD))
        options.c_cflag &= ~tcflag_t(PARENB)
        options.c_cflag &= ~tcflag_t(CSTOPB)
        options.c_cflag &= ~tcflag_t(CSIZE)
        options.c_cflag |= tcflag_t(CS8)

        if tcsetattr(fd, TCSANOW, &options) != 0 {
            perror("❌ tcsetattr failed")
            return
        }

        tcflush(fd, TCIOFLUSH)

        print("✓ Serial B115200 opened")
    }

    func write(_ buffer: [UInt8]) {
        _ = Darwin.write(fd, buffer, buffer.count)
    }
}

// MARK: Capture (NO PNG)

var reusableBuffer: [UInt8] = []
var reusableHeight: Int = 0

func capture() -> (data: [UInt8], width: Int, height: Int)? {

    let screenRect = CGDisplayBounds(CGMainDisplayID())

    guard let image = CGWindowListCreateImage(
        screenRect,
        .optionOnScreenOnly,
        kCGNullWindowID,
        [.bestResolution]
    ) else { return nil }

    let originalW = image.width
    let originalH = image.height
    let scaledH = Int(Double(originalH) * Double(RESIZE_WIDTH) / Double(originalW))

    let bytesPerRow = RESIZE_WIDTH * 4

    if reusableHeight != scaledH {
        reusableHeight = scaledH
        reusableBuffer = [UInt8](repeating: 0, count: scaledH * bytesPerRow)
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let context = CGContext(
        data: &reusableBuffer,
        width: RESIZE_WIDTH,
        height: scaledH,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.draw(image, in: CGRect(x: 0, y: 0, width: RESIZE_WIDTH, height: scaledH))

    return (reusableBuffer, RESIZE_WIDTH, scaledH)
}

// MARK: Average

func avg(
    data: [UInt8],
    width: Int,
    x1: Int, y1: Int,
    x2: Int, y2: Int
) -> (UInt8, UInt8, UInt8) {

    var r = 0, g = 0, b = 0, count = 0
    let skip = 2

    var y = y1
    while y < y2 {
        var x = x1
        while x < x2 {
            let i = (y * width + x) * 4
            r += Int(data[i])
            g += Int(data[i+1])
            b += Int(data[i+2])
            count += 1
            x += skip
        }
        y += skip
    }

    if count == 0 { return (0,0,0) }

    return (
        gammaLUT[r/count],
        gammaLUT[g/count],
        gammaLUT[b/count]
    )
}

// MARK: Build Frame

func buildFrame(data: [UInt8], width: Int, height: Int) -> [UInt8] {

    var frame = [UInt8](repeating: 0, count: FRAME_SIZE)
    frame[0] = START_BYTE

    var o = 1

    // TOP
    for i in 0..<NUM_TOP {
        let x1 = i * width / NUM_TOP
        let x2 = (i+1) * width / NUM_TOP
        let c = avg(data: data, width: width,
                    x1: x1, y1: 0,
                    x2: x2, y2: CAPTURE_EDGE_THICKNESS)
        frame[o] = c.0; frame[o+1] = c.1; frame[o+2] = c.2
        o += 3
    }

    // RIGHT
    for i in 0..<NUM_RIGHT {
        let y1 = i * height / NUM_RIGHT
        let y2 = (i+1) * height / NUM_RIGHT
        let c = avg(data: data, width: width,
                    x1: width - CAPTURE_EDGE_THICKNESS, y1: y1,
                    x2: width, y2: y2)
        frame[o] = c.0; frame[o+1] = c.1; frame[o+2] = c.2
        o += 3
    }

    // BOTTOM (reverse)
    for i in stride(from: NUM_BOTTOM-1, through: 0, by: -1) {
        let x1 = i * width / NUM_BOTTOM
        let x2 = (i+1) * width / NUM_BOTTOM
        let c = avg(data: data, width: width,
                    x1: x1, y1: height - CAPTURE_EDGE_THICKNESS,
                    x2: x2, y2: height)
        frame[o] = c.0; frame[o+1] = c.1; frame[o+2] = c.2
        o += 3
    }

    // LEFT (reverse)
    for i in stride(from: NUM_LEFT-1, through: 0, by: -1) {
        let y1 = i * height / NUM_LEFT
        let y2 = (i+1) * height / NUM_LEFT
        let c = avg(data: data, width: width,
                    x1: 0, y1: y1,
                    x2: CAPTURE_EDGE_THICKNESS, y2: y2)
        frame[o] = c.0; frame[o+1] = c.1; frame[o+2] = c.2
        o += 3
    }

    frame[FRAME_SIZE-1] = END_BYTE
    return frame
}

// MARK: Main

initGamma()

let portPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/dev/tty.usbserial-1320"

let serial = SerialPort(path: portPath)

let interval = 1.0 / Double(FPS)

while true {
    autoreleasepool {

        let start = Date()

        guard let (data, w, h) = capture() else { return }

        let frame = buildFrame(data: data, width: w, height: h)
        serial.write(frame)

        let elapsed = Date().timeIntervalSince(start)
        let sleep = interval - elapsed
        if sleep > 0 {
            usleep(UInt32(sleep * 1_000_000))
        }
    }
}
