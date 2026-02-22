import CoreGraphics
import Foundation

struct RGB {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

class ColorReader {

    let zonesLeftRightCount: Int
    let zonesTopBottomCount: Int
    let stripThicknessCount: Int

    var totalZones: Int { (zonesLeftRightCount * 2) + (zonesTopBottomCount * 2) }

    private var leftBuf:   [UInt8] = []
    private var rightBuf:  [UInt8] = []
    private var topBuf:    [UInt8] = []
    private var bottomBuf: [UInt8] = []

    init(zonesLeftRight: Int, zonesTopBottom: Int, stripThickness: Int) {
        self.zonesLeftRightCount = zonesLeftRight
        self.zonesTopBottomCount = zonesTopBottom
        self.stripThicknessCount = stripThickness
    }

    func readColors(displayID: CGDirectDisplayID) -> [RGB] {
        let screenWidth  = CGDisplayPixelsWide(displayID)
        let screenHeight = CGDisplayPixelsHigh(displayID)
        let t = stripThicknessCount

        guard
        let leftImg   = CGDisplayCreateImage(displayID, rect: CGRect(x: 0, y: 0, width: t, height: screenHeight)),
        let rightImg  = CGDisplayCreateImage(displayID, rect: CGRect(x: screenWidth - t, y: 0, width: t, height: screenHeight)),
        let topImg    = CGDisplayCreateImage(displayID, rect: CGRect(x: 0, y: 0, width: screenWidth, height: t)),
        let bottomImg = CGDisplayCreateImage(displayID, rect: CGRect(x: 0, y: screenHeight - t, width: screenWidth, height: t))
        else { return [] }

        guard
        fillPixels(from: leftImg,   into: &leftBuf),
        fillPixels(from: rightImg,  into: &rightBuf),
        fillPixels(from: topImg,    into: &topBuf),
        fillPixels(from: bottomImg, into: &bottomBuf)
        else { return [] }

        var results = [RGB]()
        results.reserveCapacity(totalZones)

        // LEFT: знизу вгору
        for i in 0..<zonesLeftRightCount {
            let flipped = zonesLeftRightCount - 1 - i
            let zoneH = screenHeight / zonesLeftRightCount
            results.append(averageColor(in: CGRect(x: 0, y: flipped * zoneH, width: t, height: zoneH),
                pixels: leftBuf, imageWidth: t))
        }

        // TOP: зліва направо
        for i in 0..<zonesTopBottomCount {
            let zoneW = screenWidth / zonesTopBottomCount
            results.append(averageColor(in: CGRect(x: i * zoneW, y: 0, width: zoneW, height: t),
                pixels: topBuf, imageWidth: screenWidth))
        }

        // RIGHT: зверху вниз
        for i in 0..<zonesLeftRightCount {
            let zoneH = screenHeight / zonesLeftRightCount
            results.append(averageColor(in: CGRect(x: 0, y: i * zoneH, width: t, height: zoneH),
                pixels: rightBuf, imageWidth: t))
        }

        // BOTTOM: справа наліво
        for i in 0..<zonesTopBottomCount {
            let flipped = zonesTopBottomCount - 1 - i
            let zoneW = screenWidth / zonesTopBottomCount
            results.append(averageColor(in: CGRect(x: flipped * zoneW, y: 0, width: zoneW, height: t),
                pixels: bottomBuf, imageWidth: screenWidth))
        }

        return results
    }

    private func fillPixels(from image: CGImage, into buffer: inout [UInt8]) -> Bool {
        let w = image.width
        let h = image.height
        let needed = w * h * 4

        if buffer.count != needed {
            buffer = [UInt8](repeating: 0, count: needed)
        }

        guard let context = CGContext(
            data: &buffer,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return false }

        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }

    private func averageColor(in rect: CGRect, pixels: [UInt8], imageWidth: Int) -> RGB {
        var totalR = 0, totalG = 0, totalB = 0, count = 0
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                let offset = (y * imageWidth + x) * 4
                totalR += Int(pixels[offset])
                totalG += Int(pixels[offset + 1])
                totalB += Int(pixels[offset + 2])
                count += 1
            }
        }
        guard count > 0 else { return RGB(r: 0, g: 0, b: 0) }
        return RGB(r: UInt8(totalR / count), g: UInt8(totalG / count), b: UInt8(totalB / count))
    }
}